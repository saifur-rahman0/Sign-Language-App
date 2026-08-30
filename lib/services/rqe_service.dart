import 'dart:math';

/// Relative Quantization Encoding (RQE) & Shoulder Fixing (RQE-SF) in Pure Dart.
///
/// Implements feature normalization for the BdSLW401 sign language recognition pipeline:
/// - 54 Face points anchored to Nose tip & normalized by inter-ocular distance.
/// - 21 Left Hand points anchored to Left Wrist & normalized by wrist-to-MCP distance.
/// - 21 Right Hand points anchored to Right Wrist & normalized by wrist-to-MCP distance.
/// - 33 Pose points anchored to Frame-0 Mid-Shoulder & normalized by bi-acromial distance (RQE-SF).
/// - Trajectory quantization step (0.05).
class RqeService {
  RqeService._();

  static const int totalLandmarks = 129; // 54 face + 21 LH + 21 RH + 33 pose
  static const int featuresPerFrame = totalLandmarks * 3; // 387

  static const int faceCount = 54;
  static const int handCount = 21;
  static const int poseCount = 33;

  static const int faceStart = 0;
  static const int leftHandStart = faceStart + faceCount; // 54
  static const int rightHandStart = leftHandStart + handCount; // 75
  static const int poseStart = rightHandStart + handCount; // 96

  /// Apply Relative Quantization Encoding with Shoulder Fixing (RQE-SF)
  ///
  /// [sequence]: list of T frames, each containing 387 flat doubles [x, y, z, ...].
  /// [quantizationStep]: step size for spatial binning (default 0.05).
  /// [shoulderFixing]: anchor upper-body pose to Frame 0 mid-shoulder (default true).
  static List<List<double>> applyRqe(
    List<List<double>> sequence, {
    double? quantizationStep = 0.05,
    bool shoulderFixing = true,
  }) {
    final int tFrames = sequence.length;
    if (tFrames == 0) return [];

    // Helper to get (x, y, z) vector at point index `p` in a frame
    List<double> getPoint(List<double> frame, int p) {
      final idx = p * 3;
      if (idx + 2 < frame.length) {
        return [frame[idx], frame[idx + 1], frame[idx + 2]];
      }
      return [0.0, 0.0, 0.0];
    }

    bool isNonZero(List<double> v) => v[0] != 0.0 || v[1] != 0.0 || v[2] != 0.0;

    double dist(List<double> a, List<double> b) {
      final dx = a[0] - b[0];
      final dy = a[1] - b[1];
      final dz = a[2] - b[2];
      return sqrt(dx * dx + dy * dy + dz * dz);
    }

    // ── 1. Frame 0 Pose Anchor Calculations (RQE-SF) ──────────────────────────
    // Left Shoulder = 96 + 11 = 107, Right Shoulder = 96 + 12 = 108
    final pLeftShoulderIdx = poseStart + 11;
    final pRightShoulderIdx = poseStart + 12;

    final frame0 = sequence[0];
    final lShoulder0 = getPoint(frame0, pLeftShoulderIdx);
    final rShoulder0 = getPoint(frame0, pRightShoulderIdx);

    List<double> midShoulderRef = [0.0, 0.0, 0.0];
    double scalePose = 1.0;

    if (isNonZero(lShoulder0) && isNonZero(rShoulder0)) {
      midShoulderRef = [
        (lShoulder0[0] + rShoulder0[0]) / 2.0,
        (lShoulder0[1] + rShoulder0[1]) / 2.0,
        (lShoulder0[2] + rShoulder0[2]) / 2.0,
      ];
      scalePose = max(dist(lShoulder0, rShoulder0), 1e-6);
    }

    // ── 2. Process Sequence Frame-by-Frame ───────────────────────────────────
    final List<List<double>> rqeSequence = [];

    for (int t = 0; t < tFrames; t++) {
      final rawFrame = sequence[t];
      // Clone frame into working buffer
      final List<List<double>> pts = List.generate(
        totalLandmarks,
        (i) => getPoint(rawFrame, i),
      );

      // --- A. Face Normalization (54 points) ---
      // Nose tip is index 22 in IMPORTANT_FACE_IDX
      final noseIdx = faceStart + 22;
      final nose = pts[noseIdx];
      final faceActive = isNonZero(nose);

      final lEye = pts[faceStart + 4];
      final rEye = pts[faceStart + 10];
      double scaleFace = 1.0;
      if (isNonZero(lEye) && isNonZero(rEye)) {
        scaleFace = max(dist(lEye, rEye), 1e-6);
      }

      for (int i = faceStart; i < leftHandStart; i++) {
        if (faceActive && isNonZero(pts[i])) {
          pts[i] = [
            (pts[i][0] - nose[0]) / scaleFace,
            (pts[i][1] - nose[1]) / scaleFace,
            (pts[i][2] - nose[2]) / scaleFace,
          ];
        } else {
          pts[i] = [0.0, 0.0, 0.0];
        }
      }

      // --- B. Left Hand Normalization (21 points) ---
      final lWrist = pts[leftHandStart];
      final lhActive = isNonZero(lWrist);
      final lMcp = pts[leftHandStart + 9];
      double scaleLh = 1.0;
      if (isNonZero(lMcp) && lhActive) {
        scaleLh = max(dist(lMcp, lWrist), 1e-6);
      }

      for (int i = leftHandStart; i < rightHandStart; i++) {
        if (lhActive && isNonZero(pts[i])) {
          pts[i] = [
            (pts[i][0] - lWrist[0]) / scaleLh,
            (pts[i][1] - lWrist[1]) / scaleLh,
            (pts[i][2] - lWrist[2]) / scaleLh,
          ];
        } else {
          pts[i] = [0.0, 0.0, 0.0];
        }
      }

      // --- C. Right Hand Normalization (21 points) ---
      final rWrist = pts[rightHandStart];
      final rhActive = isNonZero(rWrist);
      final rMcp = pts[rightHandStart + 9];
      double scaleRh = 1.0;
      if (isNonZero(rMcp) && rhActive) {
        scaleRh = max(dist(rMcp, rWrist), 1e-6);
      }

      for (int i = rightHandStart; i < poseStart; i++) {
        if (rhActive && isNonZero(pts[i])) {
          pts[i] = [
            (pts[i][0] - rWrist[0]) / scaleRh,
            (pts[i][1] - rWrist[1]) / scaleRh,
            (pts[i][2] - rWrist[2]) / scaleRh,
          ];
        } else {
          pts[i] = [0.0, 0.0, 0.0];
        }
      }

      // --- D. Pose Normalization (33 points) ---
      List<double> poseAnchor;
      double curScalePose;

      if (shoulderFixing) {
        poseAnchor = midShoulderRef;
        curScalePose = scalePose;
      } else {
        final lShoulder = pts[pLeftShoulderIdx];
        final rShoulder = pts[pRightShoulderIdx];
        if (isNonZero(lShoulder) && isNonZero(rShoulder)) {
          poseAnchor = [
            (lShoulder[0] + rShoulder[0]) / 2.0,
            (lShoulder[1] + rShoulder[1]) / 2.0,
            (lShoulder[2] + rShoulder[2]) / 2.0,
          ];
          curScalePose = max(dist(lShoulder, rShoulder), 1e-6);
        } else {
          poseAnchor = [0.0, 0.0, 0.0];
          curScalePose = 1.0;
        }
      }

      final poseAnchorActive = isNonZero(poseAnchor);

      for (int i = poseStart; i < totalLandmarks; i++) {
        if (poseAnchorActive && isNonZero(pts[i])) {
          pts[i] = [
            (pts[i][0] - poseAnchor[0]) / curScalePose,
            (pts[i][1] - poseAnchor[1]) / curScalePose,
            (pts[i][2] - poseAnchor[2]) / curScalePose,
          ];
        } else {
          pts[i] = [0.0, 0.0, 0.0];
        }
      }

      // --- E. Discretization / Quantization ---
      final List<double> flatFrame = [];
      for (int i = 0; i < totalLandmarks; i++) {
        var x = pts[i][0];
        var y = pts[i][1];
        var z = pts[i][2];

        if (quantizationStep != null && isNonZero(pts[i])) {
          x = (x / quantizationStep).roundToDouble() * quantizationStep;
          y = (y / quantizationStep).roundToDouble() * quantizationStep;
          z = (z / quantizationStep).roundToDouble() * quantizationStep;
        }

        flatFrame.addAll([x, y, z]);
      }

      rqeSequence.add(flatFrame);
    }

    return rqeSequence;
  }
}
