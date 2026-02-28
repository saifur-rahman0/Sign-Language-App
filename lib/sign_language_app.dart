import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'landmark_painter.dart';
import 'widgets/heatmap_legend.dart';
import 'widgets/result_card.dart';

const String baseUrl = 'https://saifur2025-bdslw.hf.space';
const String apiPath = '/predict-landmarks-focus';

class SignLanguageApp extends StatefulWidget {
  const SignLanguageApp({super.key});
  @override
  State<SignLanguageApp> createState() => _SignLanguageAppState();
}

class _SignLanguageAppState extends State<SignLanguageApp> with SingleTickerProviderStateMixin {
  XFile? _videoFile;
  VideoPlayerController? _controller;

  Map<String, dynamic>? _prediction;
  List<dynamic>? _landmarkData;
  List<dynamic>? _focusPoints;
  List<dynamic>? _cam;

  bool _isProcessing = false;
  String? _errorMessage;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

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
    });

    try {
      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$apiPath'));
      request.files.add(await http.MultipartFile.fromPath('file', _videoFile!.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final decoded = jsonDecode(responseData);

        if (decoded is Map && decoded['error'] != null) throw Exception(decoded['error']);

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
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (_videoFile == null) _buildEmptyState() else ...[
                      _buildHeader("Analysis Engine", isLive: _landmarkData != null),
                      _buildVideoDisplay(showOverlay: true),
                      if (_landmarkData != null) const HeatmapLegend(),
                      const SizedBox(height: 32),
                      if (_prediction != null) ResultCard(prediction: _prediction!),
                      if (_prediction != null) const SizedBox(height: 32),
                      _buildHeader("Source Reference", isLive: false),
                      _buildVideoDisplay(showOverlay: false, mini: true),
                    ],
                    const SizedBox(height: 40),
                    _buildActionPanel(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      centerTitle: true,
      title: Column(
        children: [
          Text("BdSL Recognizer", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Theme.of(context).colorScheme.primary)),
          Text("SIGN LANGUAGE RECOGNITION", style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.bold, color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, {required bool isLive}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Row(
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.black54, letterSpacing: 1)),
          const Spacer(),
          if (isLive)
            FadeTransition(
              opacity: _pulseController,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: Colors.redAccent),
                    SizedBox(width: 6),
                    Text("Sign predictor ACTIVE", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 350,
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_collection_outlined, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
          const SizedBox(height: 20),
          const Text("Ready for Analysis", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Text("Select a video to begin sign recognition", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildVideoDisplay({required bool showOverlay, bool mini = false}) {
    final isInit = _controller?.value.isInitialized ?? false;
    return Container(
      height: mini ? 150 : null,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: mini ? [] : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: isInit ? _controller!.value.aspectRatio : 16 / 9,
        child: Stack(
          children: [
            if (isInit) VideoPlayer(_controller!) else Container(color: Colors.grey[200], child: const Center(child: CircularProgressIndicator())),
            if (showOverlay && _landmarkData != null && isInit)
              Positioned.fill(
                child: ValueListenableBuilder(
                  valueListenable: _controller!,
                  builder: (context, value, _) {
                    final frameIdx = ((value.position.inMilliseconds / (value.duration.inMilliseconds + 1)) * (_landmarkData!.length - 1)).toInt().clamp(0, _landmarkData!.length - 1);
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
            if (!mini && isInit)
              Positioned(bottom: 0, left: 0, right: 0, child: VideoProgressIndicator(_controller!, allowScrubbing: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionPanel() {
    return Column(
      children: [
        if (_videoFile != null) ...[
          ElevatedButton(
            onPressed: _isProcessing ? null : _sendToServer,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(64),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 4,
            ),
            child: _isProcessing ? const CircularProgressIndicator(color: Colors.white) : const Text("RUN RECOGNITION ENGINE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleVideo(ImageSource.gallery),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text("GALLERY"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _handleVideo(ImageSource.camera),
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                icon: const Icon(Icons.videocam_outlined),
                label: const Text("CAMERA"),
              ),
            ),
          ],
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12), textAlign: TextAlign.center),
        ]
      ],
    );
  }
}
