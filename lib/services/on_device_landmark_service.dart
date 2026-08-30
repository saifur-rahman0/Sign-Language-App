import 'dart:typed_data';
import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// On-device MediaPipe Pose Detection landmark extraction service.
///
/// Extracts real body-tracking landmarks from video frames using
/// Google ML Kit Pose Detection running entirely on the phone's NPU/GPU.
/// No internet required.
class OnDeviceLandmarkService {
  OnDeviceLandmarkService._();

  static PoseDetector? _poseDetector;

  /// Initialize the ML Kit Pose Detector (lazy singleton)
  static PoseDetector _getDetector() {
    _poseDetector ??= PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.single,
        model: PoseDetectionModel.base,
      ),
    );
    return _poseDetector!;
  }

  /// Extract real on-device landmarks from a video file.
  ///
  /// 1. Extracts [frameCount] evenly-spaced frames from the video using video_thumbnail
  /// 2. Runs ML Kit Pose Detection on each frame
  /// 3. Converts the 33 PoseLandmarks to the 126-point format expected by LandmarkPainter
  ///    (52 face + 21 left hand + 21 right hand + 32 pose)
  ///
  /// Returns a map with 'landmarks', 'focus_points', and 'cam' lists.
  static Future<Map<String, dynamic>> extractLandmarks(
    String videoPath, {
    int frameCount = 30,
    int? videoDurationMs,
  }) async {
    final detector = _getDetector();

    // Determine video duration if not provided
    int durationMs = videoDurationMs ?? 3000; // fallback 3s

    // Generate evenly-spaced timestamps
    final List<int> timestamps = [];
    for (int i = 0; i < frameCount; i++) {
      timestamps.add((durationMs * i / (frameCount - 1)).round());
    }

    final List<List<double>> allFrameLandmarks = [];
    final List<List<double>> allFrameFocus = [];
    final List<double> allCam = [];

    for (int f = 0; f < timestamps.length; f++) {
      try {
        // Extract frame at this timestamp
        final Uint8List? frameBytes = await VideoThumbnail.thumbnailData(
          video: videoPath,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 480,
          quality: 60,
          timeMs: timestamps[f],
        );

        if (frameBytes == null || frameBytes.isEmpty) {
          // No frame extracted - add empty frame
          _addEmptyFrame(allFrameLandmarks, allFrameFocus, allCam, f, frameCount);
          continue;
        }

        // Save temp file for ML Kit InputImage
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/mlkit_frame_$f.jpg');
        await tempFile.writeAsBytes(frameBytes);

        // Run ML Kit Pose Detection
        final inputImage = InputImage.fromFilePath(tempFile.path);
        final List<Pose> poses = await detector.processImage(inputImage);

        // Clean up temp file
        try { await tempFile.delete(); } catch (_) {}

        if (poses.isEmpty) {
          _addEmptyFrame(allFrameLandmarks, allFrameFocus, allCam, f, frameCount);
          continue;
        }

        // Use the first detected pose
        final pose = poses.first;
        final landmarks = _convertPoseTo126Points(pose);
        final focus = _computeFocusValues(pose, f, frameCount);
        final cam = _computeTemporalCam(f, frameCount);

        allFrameLandmarks.add(landmarks);
        allFrameFocus.add(focus);
        allCam.add(cam);
      } catch (e) {
        _addEmptyFrame(allFrameLandmarks, allFrameFocus, allCam, f, frameCount);
      }
    }

    return {
      'landmarks': allFrameLandmarks,
      'focus_points': allFrameFocus,
      'cam': allCam,
    };
  }

  /// Convert ML Kit's 33 PoseLandmarks to the 126-point format:
  /// [52 face] [21 left hand] [21 right hand] [32 pose]
  /// All coordinates are normalized to 0.0-1.0 range.
  static List<double> _convertPoseTo126Points(Pose pose) {
    final landmarks = pose.landmarks;
    final List<double> pts = [];

    // Helper to get normalized coords from a PoseLandmarkType
    List<double> getNorm(PoseLandmarkType type) {
      final lm = landmarks[type];
      if (lm == null) return [0.0, 0.0, 0.0];
      // ML Kit returns pixel coordinates; normalize by image size
      // Since we use 480px max width, estimate normalization
      // ML Kit coordinates are in image pixel space
      final x = (lm.x / 480.0).clamp(0.0, 1.0);
      final y = (lm.y / 640.0).clamp(0.0, 1.0); // approximate height
      final z = lm.z / 480.0; // depth relative to width
      return [x, y, z];
    }

    // ── 1. FACE (52 points) ──────────────────────────────────────────────────
    // ML Kit provides: nose, left/right eye inner/outer, left/right ear, left/right mouth
    final nose = getNorm(PoseLandmarkType.nose);
    final leftEyeInner = getNorm(PoseLandmarkType.leftEyeInner);
    final leftEye = getNorm(PoseLandmarkType.leftEye);
    final leftEyeOuter = getNorm(PoseLandmarkType.leftEyeOuter);
    final rightEyeInner = getNorm(PoseLandmarkType.rightEyeInner);
    final rightEye = getNorm(PoseLandmarkType.rightEye);
    final rightEyeOuter = getNorm(PoseLandmarkType.rightEyeOuter);
    final leftEar = getNorm(PoseLandmarkType.leftEar);
    final rightEar = getNorm(PoseLandmarkType.rightEar);
    final leftMouth = getNorm(PoseLandmarkType.leftMouth);
    final rightMouth = getNorm(PoseLandmarkType.rightMouth);

    // Place known face points and interpolate the rest
    final faceCenter = [nose[0], nose[1], 0.0];
    final faceWidth = (leftEar[0] - rightEar[0]).abs();
    final faceHeight = faceWidth * 1.3;

    // Generate 52 face points as an oval around the face center
    for (int i = 0; i < 52; i++) {
      if (i == 0) {
        pts.addAll(nose); // nose
      } else if (i == 1) {
        pts.addAll(leftEyeInner);
      } else if (i == 2) {
        pts.addAll(leftEye);
      } else if (i == 3) {
        pts.addAll(leftEyeOuter);
      } else if (i == 4) {
        pts.addAll(rightEyeInner);
      } else if (i == 5) {
        pts.addAll(rightEye);
      } else if (i == 6) {
        pts.addAll(rightEyeOuter);
      } else if (i == 7) {
        pts.addAll(leftEar);
      } else if (i == 8) {
        pts.addAll(rightEar);
      } else if (i == 9) {
        pts.addAll(leftMouth);
      } else if (i == 10) {
        pts.addAll(rightMouth);
      } else {
        // Remaining face points: distribute on oval around nose
        final angle = (i - 11) / 41.0 * 2 * pi;
        final fx = faceCenter[0] + (faceWidth * 0.5) * cos(angle);
        final fy = faceCenter[1] + (faceHeight * 0.5) * sin(angle);
        pts.addAll([fx.clamp(0.0, 1.0), fy.clamp(0.0, 1.0), 0.0]);
      }
    }

    // ── 2. LEFT HAND (21 points) ─────────────────────────────────────────────
    // ML Kit gives: left wrist, left index, left thumb, left pinky
    final leftWrist = getNorm(PoseLandmarkType.leftWrist);
    final leftIndex = getNorm(PoseLandmarkType.leftIndex);
    final leftThumb = getNorm(PoseLandmarkType.leftThumb);
    final leftPinky = getNorm(PoseLandmarkType.leftPinky);

    _generateHandPoints(pts, leftWrist, leftIndex, leftThumb, leftPinky);

    // ── 3. RIGHT HAND (21 points) ────────────────────────────────────────────
    final rightWrist = getNorm(PoseLandmarkType.rightWrist);
    final rightIndex = getNorm(PoseLandmarkType.rightIndex);
    final rightThumb = getNorm(PoseLandmarkType.rightThumb);
    final rightPinky = getNorm(PoseLandmarkType.rightPinky);

    _generateHandPoints(pts, rightWrist, rightIndex, rightThumb, rightPinky);

    // ── 4. POSE BODY (32 points) ─────────────────────────────────────────────
    // Map ML Kit's 33 landmarks to our 32-point subset
    final poseTypes = [
      PoseLandmarkType.nose,           // 0
      PoseLandmarkType.leftEyeInner,   // 1
      PoseLandmarkType.leftEye,        // 2
      PoseLandmarkType.leftEyeOuter,   // 3
      PoseLandmarkType.rightEyeInner,  // 4
      PoseLandmarkType.rightEye,       // 5
      PoseLandmarkType.rightEyeOuter,  // 6
      PoseLandmarkType.leftEar,        // 7
      PoseLandmarkType.rightEar,       // 8
      PoseLandmarkType.leftMouth,      // 9
      PoseLandmarkType.rightMouth,     // 10
      PoseLandmarkType.leftShoulder,   // 11
      PoseLandmarkType.rightShoulder,  // 12
      PoseLandmarkType.leftElbow,      // 13
      PoseLandmarkType.rightElbow,     // 14
      PoseLandmarkType.leftWrist,      // 15
      PoseLandmarkType.rightWrist,     // 16
      PoseLandmarkType.leftPinky,      // 17
      PoseLandmarkType.rightPinky,     // 18
      PoseLandmarkType.leftIndex,      // 19
      PoseLandmarkType.rightIndex,     // 20
      PoseLandmarkType.leftThumb,      // 21
      PoseLandmarkType.rightThumb,     // 22
      PoseLandmarkType.leftHip,        // 23
      PoseLandmarkType.rightHip,       // 24
      PoseLandmarkType.leftKnee,       // 25
      PoseLandmarkType.rightKnee,      // 26
      PoseLandmarkType.leftAnkle,      // 27
      PoseLandmarkType.rightAnkle,     // 28
      PoseLandmarkType.leftHeel,       // 29
      PoseLandmarkType.rightHeel,      // 30
      PoseLandmarkType.leftFootIndex,  // 31
    ];

    for (final type in poseTypes) {
      pts.addAll(getNorm(type));
    }

    return pts;
  }

  /// Generate 21 hand points from the 4 available pose hand landmarks
  /// (wrist, index, thumb, pinky) by interpolating finger joints
  static void _generateHandPoints(
    List<double> pts,
    List<double> wrist,
    List<double> index,
    List<double> thumb,
    List<double> pinky,
  ) {
    // Hand center
    final cx = (wrist[0] + index[0] + thumb[0] + pinky[0]) / 4;
    final cy = (wrist[1] + index[1] + thumb[1] + pinky[1]) / 4;

    // Point 0: Wrist
    pts.addAll(wrist);

    // Points 1-4: Thumb (wrist -> thumb tip)
    for (int i = 1; i <= 4; i++) {
      final t = i / 4.0;
      pts.addAll([
        _lerp(wrist[0], thumb[0], t),
        _lerp(wrist[1], thumb[1], t),
        0.0,
      ]);
    }

    // Points 5-8: Index finger (center -> index tip)
    for (int i = 1; i <= 4; i++) {
      final t = i / 4.0;
      pts.addAll([
        _lerp(cx, index[0], t),
        _lerp(cy, index[1], t),
        0.0,
      ]);
    }

    // Points 9-12: Middle finger (interpolated between index and pinky)
    final midX = (index[0] + pinky[0]) / 2;
    final midY = (index[1] + pinky[1]) / 2;
    for (int i = 1; i <= 4; i++) {
      final t = i / 4.0;
      pts.addAll([
        _lerp(cx, midX, t),
        _lerp(cy, midY, t),
        0.0,
      ]);
    }

    // Points 13-16: Ring finger (closer to pinky)
    final ringX = _lerp(midX, pinky[0], 0.5);
    final ringY = _lerp(midY, pinky[1], 0.5);
    for (int i = 1; i <= 4; i++) {
      final t = i / 4.0;
      pts.addAll([
        _lerp(cx, ringX, t),
        _lerp(cy, ringY, t),
        0.0,
      ]);
    }

    // Points 17-20: Pinky finger (center -> pinky tip)
    for (int i = 1; i <= 4; i++) {
      final t = i / 4.0;
      pts.addAll([
        _lerp(cx, pinky[0], t),
        _lerp(cy, pinky[1], t),
        0.0,
      ]);
    }
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// Compute focus/attention values for each of the 126 points
  static List<double> _computeFocusValues(Pose pose, int frameIdx, int totalFrames) {
    final List<double> focus = [];
    final t = totalFrames > 1 ? frameIdx / (totalFrames - 1) : 0.5;
    final motion = sin(t * pi); // peak at middle of video

    // Face (52 points) - low attention
    for (int i = 0; i < 52; i++) {
      focus.add(0.15 + motion * 0.05);
    }

    // Left Hand (21 points) - high attention for sign language
    final leftWrist = pose.landmarks[PoseLandmarkType.leftWrist];
    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    double leftHandImportance = 0.6;
    if (leftWrist != null && leftShoulder != null) {
      // Higher attention when hand is raised above shoulder
      leftHandImportance = leftWrist.y < leftShoulder.y ? 0.9 : 0.5;
    }
    for (int i = 0; i < 21; i++) {
      focus.add(leftHandImportance + motion * 0.1);
    }

    // Right Hand (21 points) - high attention
    final rightWrist = pose.landmarks[PoseLandmarkType.rightWrist];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    double rightHandImportance = 0.6;
    if (rightWrist != null && rightShoulder != null) {
      rightHandImportance = rightWrist.y < rightShoulder.y ? 0.9 : 0.5;
    }
    for (int i = 0; i < 21; i++) {
      focus.add(rightHandImportance + motion * 0.1);
    }

    // Pose (32 points) - moderate attention on upper body
    for (int i = 0; i < 32; i++) {
      // Wrists (15, 16) and elbows (13, 14) get higher focus
      if (i == 13 || i == 14 || i == 15 || i == 16) {
        focus.add(0.65 + motion * 0.15);
      } else if (i == 11 || i == 12) {
        // Shoulders
        focus.add(0.35 + motion * 0.05);
      } else {
        focus.add(0.15);
      }
    }

    return focus;
  }

  /// Compute temporal CAM value (higher attention during signing peak)
  static double _computeTemporalCam(int frameIdx, int totalFrames) {
    final t = totalFrames > 1 ? frameIdx / (totalFrames - 1) : 0.5;
    return (sin(t * pi) * 0.75 + 0.15).clamp(0.0, 1.0);
  }

  /// Add an empty frame when pose detection fails for a frame
  static void _addEmptyFrame(
    List<List<double>> landmarks,
    List<List<double>> focus,
    List<double> cam,
    int frameIdx,
    int totalFrames,
  ) {
    // Use zeros for all 126 points (will be skipped by painter)
    landmarks.add(List.filled(126 * 3, 0.0));
    focus.add(List.filled(126, 0.1));
    cam.add(_computeTemporalCam(frameIdx, totalFrames));
  }

  /// Dispose the pose detector to free resources
  static Future<void> dispose() async {
    await _poseDetector?.close();
    _poseDetector = null;
  }
}
