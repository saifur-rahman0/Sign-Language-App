import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

const String baseUrl = 'https://saifur2025-bdslw.hf.space';
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
  List<dynamic>? _landmarkData;
  List<dynamic>? _focusPoints;
  List<dynamic>? _cam;

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
      appBar: AppBar(title: const Text("BdSL Recognizer"), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionLabel("Analysis Preview"),
            _buildVideoCard(showOverlay: true),
            if (_landmarkData != null) _buildFocusLegend(),

            const SizedBox(height: 24),
            _buildResultArea(),
            const SizedBox(height: 24),

            _buildSectionLabel("Original Reference"),
            _buildVideoCard(showOverlay: false),

            const SizedBox(height: 32),
            _buildControls(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            letterSpacing: 1.1,
          )),
    );
  }

  Widget _buildFocusLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 12.0, left: 4.0, right: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text("AI Focus Heatmap:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [Colors.blue, Colors.purple, Colors.red],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Low Focus", style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text("High Focus (Grad-CAM)", style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "• Boxes/Points: Spatial Focus (Hand importance)\n• Video Border: Temporal Focus (Frame importance)",
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.black54),
          ),
        ],
      ),
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
                color: Colors.grey[200],
                child: const Icon(Icons.videocam_off_outlined, size: 50, color: Colors.grey),
              ),

            if (showOverlay && _landmarkData != null && isInitialized)
              Positioned.fill(
                child: ValueListenableBuilder(
                  valueListenable: _controller!,
                  builder: (context, value, child) {
                    final totalFrames = _landmarkData!.length;
                    final progress = value.duration.inMilliseconds > 0
                        ? value.position.inMilliseconds / value.duration.inMilliseconds
                        : 0.0;
                    final frameIdx = (progress * (totalFrames - 1)).toInt().clamp(0, totalFrames - 1);

                    return CustomPaint(
                      painter: LandmarkPainter(
                        _landmarkData![frameIdx],
                        frameFocus: _focusPoints?[frameIdx],
                        cam: (_cam?[frameIdx] as num?)?.toDouble() ?? 0.0,
                      ),
                    );
                  },
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
        if (_videoFile != null) ...[
          FilledButton.icon(
            onPressed: _isProcessing ? null : _sendToServer,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
            icon: _isProcessing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.psychology),
            label: Text(_isProcessing ? "Analyzing Gestures..." : "Analyze & Recognize"),
          ),
          const SizedBox(height: 12),
        ],
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
      ],
    );
  }

  Widget _buildResultArea() {
    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
        child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
      );
    }
    if (_prediction == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text("RECOGNIZED SIGN", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.black54)),
          const SizedBox(height: 8),
          Text(_prediction!['bangla'], style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
          Text(_prediction!['english'].toString().toUpperCase(), style: const TextStyle(fontSize: 16, letterSpacing: 2, color: Colors.black45)),
          const SizedBox(height: 16),
          Text("Confidence: ${_prediction!['confidence']}", style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class LandmarkPainter extends CustomPainter {
  final List<dynamic> framePoints;
  final List<dynamic>? frameFocus;
  final double cam;

  LandmarkPainter(this.framePoints, {this.frameFocus, this.cam = 0.0});

  Color heatColor(double v) {
    v = v.clamp(0.0, 1.0);
    return Color.lerp(Colors.blue, Colors.red, v)!;
  }

  Rect? _bboxForPoints(Size size, List<int> pointIdxs) {
    double minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
    bool found = false;

    for (final pIdx in pointIdxs) {
      final i = pIdx * 3;
      if (i + 1 >= framePoints.length) continue;

      final x = (framePoints[i] as num).toDouble();
      final y = (framePoints[i + 1] as num).toDouble();

      if (x <= 0 || y <= 0) continue;

      found = true;
      if (x < minX) minX = x;
      if (y < minY) minY = y;
      if (x > maxX) maxX = x;
      if (y > maxY) maxY = y;
    }

    if (!found) return null;

    const pad = 0.02; // Small padding relative to screen
    return Rect.fromLTRB(
      (minX - pad) * size.width,
      (minY - pad) * size.height,
      (maxX + pad) * size.width,
      (maxY + pad) * size.height,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Border (Temporal Focus)
    final borderPaint = Paint()
      ..color = heatColor(cam).withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 + 12 * cam;
    canvas.drawRect(Offset.zero & size, borderPaint);

    const int faceCount = 52;
    const int leftHandStart = faceCount;
    const int rightHandStart = faceCount + 21;

    // 2) Landmarks (Spatial Focus)
    for (int i = 0, p = 0; i < framePoints.length; i += 3, p++) {
      final x = (framePoints[i] as num).toDouble() * size.width;
      final y = (framePoints[i + 1] as num).toDouble() * size.height;

      if (x <= 0 || y <= 0 || x.isNaN || y.isNaN) continue;

      double focus = (frameFocus != null && p < frameFocus!.length)
          ? (frameFocus![p] as num).toDouble().clamp(0.0, 1.0)
          : 0.0;

      final paint = Paint()
        ..color = heatColor(focus).withOpacity(0.8)
        ..style = PaintingStyle.fill;

      // Higher focus = bigger dots
      canvas.drawCircle(Offset(x, y), 2.0 + 10.0 * focus, paint);
    }

    // 3) Hand Focus Boxes (Spatial Focus Bounding Boxes)
    for (var idxs in [
      List.generate(21, (k) => leftHandStart + k),
      List.generate(21, (k) => rightHandStart + k)
    ]) {
      final box = _bboxForPoints(size, idxs);
      if (box != null) {
        double avgFocus = 0.0;
        int count = 0;
        for (var i in idxs) {
          if (frameFocus != null && i < frameFocus!.length) {
            avgFocus += (frameFocus![i] as num).toDouble();
            count++;
          }
        }
        final focus = count > 0 ? (avgFocus / count).clamp(0.0, 1.0) : 0.0;

        canvas.drawRRect(
          RRect.fromRectAndRadius(box, const Radius.circular(8)),
          Paint()
            ..color = heatColor(focus).withOpacity(0.9)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 + 4 * focus,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
