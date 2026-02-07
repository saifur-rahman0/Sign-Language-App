import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

const String baseUrl = 'https://saifur2025-bdslw.hf.space';
// NEW endpoint:
const String apiPath = '/predict-landmarks-focus';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BdSL Recognizer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurpleAccent),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      home: const SignLanguageApp(),
    );
  }
}

class SignLanguageApp extends StatefulWidget {
  const SignLanguageApp({super.key});
  @override
  State<SignLanguageApp> createState() => _SignLanguageAppState();
}

class _SignLanguageAppState extends State<SignLanguageApp> {
  XFile? _videoFile;
  VideoPlayerController? _controller;

  Map<String, dynamic>? _prediction;
  List<dynamic>? _landmarkData;      // (T, F)
  List<dynamic>? _focusPoints;       // (T, num_points)
  List<dynamic>? _cam;              // (T,)

  bool _isProcessing = false;
  String? _errorMessage;

  Future<void> _handleVideo(ImageSource source) async {
    final video = await ImagePicker().pickVideo(source: source);
    if (video != null) {
      _controller?.dispose();
      _controller = VideoPlayerController.file(File(video.path))
        ..initialize().then((_) => setState(() {}));

      setState(() {
        _videoFile = video;
        _prediction = null;
        _landmarkData = null;
        _focusPoints = null;
        _cam = null;
        _errorMessage = null;
      });
    }
  }

  Future<void> _sendToServer() async {
    if (_videoFile == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _prediction = null;
      _landmarkData = null;
      _focusPoints = null;
      _cam = null;
    });

    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$apiPath'));
      request.files.add(await http.MultipartFile.fromPath('file', _videoFile!.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final decoded = jsonDecode(responseData);

        if (decoded is Map && decoded['error'] != null) {
          throw Exception(decoded['error']);
        }

        setState(() {
          _prediction = decoded['prediction'];
          _landmarkData = decoded['landmarks'];
          _focusPoints = decoded['focus_points'];
          _cam = decoded['cam'];
        });

        _controller?.play();
        _controller?.setLooping(true);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("BdSL Recognizer"), centerTitle: true, elevation: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionLabel("Original Video"),
            _buildVideoCard(showOverlay: false),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 20),

            _buildSectionLabel("Landmarks + Focus (Grad-CAM + Saliency)"),
            _buildVideoCard(showOverlay: true),

            const SizedBox(height: 24),
            _buildControls(),
            const SizedBox(height: 24),
            _buildResultArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildVideoCard({required bool showOverlay}) {
    final isInitialized = _controller?.value.isInitialized ?? false;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: isInitialized ? _controller!.value.aspectRatio : 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isInitialized)
              VideoPlayer(_controller!)
            else
              Container(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                child: const Icon(Icons.videocam_off_outlined, size: 50),
              ),

            if (showOverlay &&
                _landmarkData != null &&
                _focusPoints != null &&
                _cam != null &&
                isInitialized)
              Positioned.fill(
                child: ClipRect(
                  child: ValueListenableBuilder(
                    valueListenable: _controller!,
                    builder: (context, value, child) {
                      final totalFrames = _landmarkData!.length;
                      final durationMs = value.duration.inMilliseconds.toDouble();
                      final progress = durationMs > 0
                          ? value.position.inMilliseconds / durationMs
                          : 0.0;
                      final frameIdx =
                      (progress * (totalFrames - 1)).toInt().clamp(0, totalFrames - 1);

                      final frameLandmarks = _landmarkData![frameIdx];
                      final frameFocus = _focusPoints![frameIdx];
                      final camVal = (_cam![frameIdx] as num).toDouble();

                      return CustomPaint(
                        painter: LandmarkPainter(frameLandmarks,
                            frameFocus: frameFocus, cam: camVal),
                      );
                    },
                  ),
                ),
              ),

            if (isInitialized)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(_controller!, allowScrubbing: true),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleVideo(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text("Gallery"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleVideo(ImageSource.camera),
                icon: const Icon(Icons.videocam_outlined),
                label: const Text("Camera"),
              ),
            ),
          ],
        ),
        if (_videoFile != null) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isProcessing ? null : _sendToServer,
            icon: _isProcessing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
                : const Icon(Icons.auto_awesome),
            label: Text(_isProcessing ? "Processing..." : "Process & Predict"),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
        ],
      ],
    );
  }

  Widget _buildResultArea() {
    if (_errorMessage != null) {
      return Text(_errorMessage!, style: const TextStyle(color: Colors.red));
    }
    if (_prediction == null) return const SizedBox.shrink();

    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(_prediction!['bangla'],
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            Text(_prediction!['english'],
                style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            Text("Confidence: ${_prediction!['confidence']}",
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class LandmarkPainter extends CustomPainter {
  final List<dynamic> framePoints;    // [x,y,z,...]
  final List<dynamic>? frameFocus;    // [score per point]
  final double cam;                  // 0..1

  LandmarkPainter(this.framePoints, {this.frameFocus, this.cam = 0.0});

  Color heatColor(double v) {
    v = v.clamp(0.0, 1.0);
    final r = (255 * v).toInt();
    final b = (255 * (1.0 - v)).toInt();
    return Color.fromARGB(255, r, 60, b); // red -> blue
  }

  // Compute bounding rect from a list of landmark indices (point indices, not feature indices)
  Rect? _bboxForPoints(Size size, List<int> pointIdxs) {
    double? minX, minY, maxX, maxY;
    bool found = false;

    for (final p in pointIdxs) {
      final i = p * 3;
      if (i + 1 >= framePoints.length) continue;

      final x = (framePoints[i] as num).toDouble() * size.width;
      final y = (framePoints[i + 1] as num).toDouble() * size.height;

      // skip invalid / padded points
      if (x <= 0 || y <= 0 || x.isNaN || y.isNaN) continue;

      found = true;
      minX = (minX == null) ? x : (x < minX! ? x : minX);
      minY = (minY == null) ? y : (y < minY! ? y : minY);
      maxX = (maxX == null) ? x : (x > maxX! ? x : maxX);
      maxY = (maxY == null) ? y : (y > maxY! ? y : maxY);
    }

    if (!found || minX == null || minY == null || maxX == null || maxY == null) return null;

    // Add padding
    const pad = 12.0;
    final left = (minX - pad).clamp(0.0, size.width);
    final top = (minY - pad).clamp(0.0, size.height);
    final right = (maxX + pad).clamp(0.0, size.width);
    final bottom = (maxY + pad).clamp(0.0, size.height);

    if (right <= left || bottom <= top) return null;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  double _meanFocus(List<int> pointIdxs) {
    if (frameFocus == null) return 0.0;
    double sum = 0.0;
    int cnt = 0;
    for (final p in pointIdxs) {
      if (p < frameFocus!.length) {
        sum += (frameFocus![p] as num).toDouble().clamp(0.0, 1.0);
        cnt++;
      }
    }
    return cnt == 0 ? 0.0 : (sum / cnt);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Temporal CAM border around video
    final borderPaint = Paint()
      ..color = heatColor(cam).withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6 + 10 * cam;
    canvas.drawRect(Offset.zero & size, borderPaint);

    // --- IMPORTANT: point index mapping based on your backend order ---
    // Order in backend landmark vector:
    // face (len(IMPORTANT_FACE_IDX) points) + left hand(21) + right hand(21) + pose(33)
    //
    // Each "point" here means one (x,y,z) triplet.
    const int facePoints = 52; // IMPORTANT_FACE_IDX length in your backend (should be 52)
    const int leftHandStart = facePoints;           // point index
    const int rightHandStart = facePoints + 21;     // point index
    const int poseStart = facePoints + 21 + 21;     // point index

    final leftHandIdxs = List<int>.generate(21, (k) => leftHandStart + k);
    final rightHandIdxs = List<int>.generate(21, (k) => rightHandStart + k);

    // 2) Draw landmarks as circles (heat + size)
    for (int i = 0, p = 0; i < framePoints.length; i += 3, p++) {
      final x = (framePoints[i] as num).toDouble() * size.width;
      final y = (framePoints[i + 1] as num).toDouble() * size.height;

      if (x <= 0 || y <= 0 || x.isNaN || y.isNaN) continue;

      double s = 0.0;
      if (frameFocus != null && p < frameFocus!.length) {
        s = (frameFocus![p] as num).toDouble().clamp(0.0, 1.0);
      }

      final paint = Paint()
        ..color = heatColor(s).withOpacity(0.85)
        ..style = PaintingStyle.fill;

      final radius = 2.0 + 7.0 * s;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }

    // 3) Draw hand bounding boxes (focus-colored)
    final leftBox = _bboxForPoints(size, leftHandIdxs);
    final rightBox = _bboxForPoints(size, rightHandIdxs);

    if (leftBox != null) {
      final m = _meanFocus(leftHandIdxs);
      final p = Paint()
        ..color = heatColor(m).withOpacity(0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + 4 * m;
      canvas.drawRect(leftBox, p);
    }

    if (rightBox != null) {
      final m = _meanFocus(rightHandIdxs);
      final p = Paint()
        ..color = heatColor(m).withOpacity(0.95)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 + 4 * m;
      canvas.drawRect(rightBox, p);
    }
  }

  @override
  bool shouldRepaint(LandmarkPainter oldDelegate) => true;
}