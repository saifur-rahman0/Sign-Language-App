import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'landmark_painter.dart';
import 'theme/neu_theme.dart';
import 'widgets/heatmap_legend.dart';
import 'widgets/history_panel.dart';
import 'widgets/neu_button.dart';
import 'widgets/result_card.dart';

const String baseUrl = 'https://saifur2025-bdslw.hf.space';
const String apiPath = '/predict-video';

/// Human-readable short labels for each model key.
const Map<String, String> kModelLabels = {
  'transformer_frontview':              'Front View',
  'transformer_interpolated_frontview': 'Front (Interp.)',
  'transformer_multiview':              'Multi View',
  'transformer_interpolated_multiview': 'Multi (Interp.)',
  'cnn_frontview':                      'Front View',
  'cnn_interpolated_frontview':         'Front (Interp.)',
  'cnn_multiview':                      'Multi View',
  'cnn_interpolated_multiview':         'Multi (Interp.)',
};

// ─────────────────────────────────────────────────────────────────────────────
class SignLanguageApp extends StatefulWidget {
  const SignLanguageApp({super.key});
  @override
  State<SignLanguageApp> createState() => _SignLanguageAppState();
}

class _SignLanguageAppState extends State<SignLanguageApp>
    with SingleTickerProviderStateMixin {
  // ── Video ────────────────────────────────────────────────────────────────
  XFile? _videoFile;
  VideoPlayerController? _controller;

  // ── API results ──────────────────────────────────────────────────────────
  Map<String, dynamic>? _prediction;
  List<dynamic>? _landmarkData;
  List<dynamic>? _focusPoints;
  List<dynamic>? _cam;
  List<dynamic>? _topPredictions;

  // ── State ────────────────────────────────────────────────────────────────
  bool _isProcessing = false;
  String? _errorMessage;

  // ── Playback ─────────────────────────────────────────────────────────────
  double _playbackSpeed = 1.0;
  static const List<double> _speeds = [0.25, 0.5, 1.0, 1.5, 2.0];

  // ── Model selection ─────────────────────────────────────────────────────
  String _selectedModel = 'transformer_frontview';
  List<String> _availableModels = [
    'transformer_frontview',
    'transformer_interpolated_frontview',
    'transformer_multiview',
    'transformer_interpolated_multiview',
    'cnn_frontview',
    'cnn_interpolated_frontview',
    'cnn_multiview',
    'cnn_interpolated_multiview',
  ];

  // ── Server / latency ─────────────────────────────────────────────────────
  ServerStatus _serverStatus = ServerStatus.checking;
  int _lastLatencyMs = 0;

  // ── History ──────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _history = [];

  // ── Animation ────────────────────────────────────────────────────────────
  late AnimationController _pulseCtrl;

  // ────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _checkServerHealth();
    _fetchModels();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Server health ────────────────────────────────────────────────────────
  Future<void> _checkServerHealth() async {
    setState(() => _serverStatus = ServerStatus.checking);
    try {
      final sw = Stopwatch()..start();
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 12));
      sw.stop();
      setState(() {
        _serverStatus =
            res.statusCode < 500 ? ServerStatus.online : ServerStatus.offline;
        _lastLatencyMs = sw.elapsedMilliseconds;
      });
    } catch (_) {
      setState(() => _serverStatus = ServerStatus.offline);
    }
  }

  // ── Fetch available models from API ─────────────────────────────────────
  Future<void> _fetchModels() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/models'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final list = (data['available_models'] as List<dynamic>)
            .map((e) => e.toString())
            .toList();
        if (list.isNotEmpty) {
          setState(() {
            _availableModels = list;
            // keep _selectedModel valid
            if (!_availableModels.contains(_selectedModel)) {
              _selectedModel = _availableModels.first;
            }
          });
        }
      }
    } catch (_) {
      // keep the local default list
    }
  }

  // ── History persistence ──────────────────────────────────────────────────
  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bdslw_history') ?? [];
    setState(() {
      _history = raw
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();
    });
  }

  Future<void> _persistHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'bdslw_history', _history.map((e) => jsonEncode(e)).toList());
  }

  Future<void> _addToHistory(Map<String, dynamic> pred) async {
    final entry = {
      ...pred,
      'timestamp': DateTime.now().toIso8601String(),
    };
    setState(() {
      _history.insert(0, entry);
      if (_history.length > 10) _history = _history.take(10).toList();
    });
    await _persistHistory();
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('bdslw_history');
    setState(() => _history = []);
  }

  // ── Video picking ────────────────────────────────────────────────────────
  Future<void> _handleVideo(ImageSource source) async {
    final video = await ImagePicker().pickVideo(source: source);
    if (video == null) return;
    _controller?.dispose();
    _controller = VideoPlayerController.file(File(video.path))
      ..initialize().then((_) => setState(() {}));
    setState(() {
      _videoFile = video;
      _prediction = null;
      _landmarkData = null;
      _focusPoints = null;
      _cam = null;
      _topPredictions = null;
      _errorMessage = null;
    });
  }

  // ── Send to HF Space ─────────────────────────────────────────────────────
  Future<void> _sendToServer() async {
    if (_videoFile == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _prediction = null;
    });

    try {
      final sw = Stopwatch()..start();
      final uri = Uri.parse('$baseUrl$apiPath').replace(
        queryParameters: {'model_type': _selectedModel},
      );
      final request = http.MultipartRequest('POST', uri);
      request.files
          .add(await http.MultipartFile.fromPath('file', _videoFile!.path));
      final response = await request.send();
      sw.stop();

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final decoded = jsonDecode(body) as Map<String, dynamic>;

        if (decoded['error'] != null) {
          throw Exception(decoded['error']);
        }

        // New API returns flat structure (no nested 'prediction' key)
        final pred = {
          'bangla':     decoded['bangla'],
          'english':    decoded['english'],
          'confidence': decoded['confidence'],
          'model_used': decoded['model_used'] ?? _selectedModel,
        };
        await _addToHistory(pred);

        setState(() {
          _prediction    = pred;
          _landmarkData  = decoded['landmarks'];
          _focusPoints   = decoded['focus_points'];
          _cam           = decoded['cam'];
          _topPredictions = decoded['top_predictions'];
          _serverStatus  = ServerStatus.online;
          _lastLatencyMs = sw.elapsedMilliseconds;
        });

        _controller?.play();
        _controller?.setLooping(true);
        _controller?.setPlaybackSpeed(_playbackSpeed);
      } else {
        throw Exception('Server error ${response.statusCode}');
      }
    } catch (e) {
      final msg = e.toString();
      setState(() {
        _errorMessage = msg;
        if (msg.contains('SocketException') ||
            msg.contains('TimeoutException')) {
          _serverStatus = ServerStatus.offline;
        }
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // ── Sheets ───────────────────────────────────────────────────────────────
  void _openHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HistoryPanel(
        history: _history,
        onClear: () {
          _clearHistory();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _openAbout() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AboutSheet(baseUrl: baseUrl),
    );
  }

  // ── Grad-CAM Dialog ───────────────────────────────────────────────────────
  void _showGradCamDialog() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: NeuColors.background,
            borderRadius: BorderRadius.circular(24),
            boxShadow: neuRaisedShadows(depth: 1.2),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.visibility_outlined, size: 18, color: NeuColors.accent),
                  const SizedBox(width: 8),
                  Text(
                    'GRAD-CAM ATTENTION MAP',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: NeuColors.text,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: NeuColors.background,
                        shape: BoxShape.circle,
                        boxShadow: neuRaisedShadows(depth: 0.5),
                      ),
                      child: Icon(Icons.close_rounded, size: 16, color: NeuColors.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const HeatmapLegend(),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NeuColors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 60),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (_videoFile == null)
                    _buildEmptyState()
                  else ...[
                    const SizedBox(height: 8),
                    _buildSectionHeader(
                      'Analysis Engine',
                      isLive: _landmarkData != null,
                      onInfoTap: _showGradCamDialog,
                    ),
                    const SizedBox(height: 12),
                    _buildVideoDisplay(showOverlay: true),
                    if (_controller?.value.isInitialized == true) ...[
                      const SizedBox(height: 10),
                      _buildPlaybackControls(),
                    ],
                    const SizedBox(height: 20),
                    if (_prediction != null) ...[
                      ResultCard(
                        prediction: _prediction!,
                        topPredictions: _topPredictions,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                  const SizedBox(height: 24),
                  _buildModelSelector(),
                  const SizedBox(height: 32),
                  _buildActionPanel(),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorDisplay(),
                  ],
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      snap: true,
      backgroundColor: NeuColors.background,
      elevation: 0,
      centerTitle: true,
      title: Column(
        children: [
          Text(
            'BdSL Recognizer',
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1.5,
              color: NeuColors.text,
            ),
          ),
          Text(
            'BANGLA SIGN LANGUAGE · WORD LEVEL',
            style: GoogleFonts.nunito(
              fontSize: 9,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: NeuColors.textMuted,
            ),
          ),
        ],
      ),
      actions: [
        _buildServerDot(),
        _buildAppBarIcon(Icons.history_rounded, _openHistory),
        _buildAppBarIcon(Icons.info_outline_rounded, _openAbout),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildServerDot() {
    final Color c;
    switch (_serverStatus) {
      case ServerStatus.online:
        c = NeuColors.success;
        break;
      case ServerStatus.offline:
        c = NeuColors.error;
        break;
      case ServerStatus.checking:
        c = NeuColors.warning;
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 14, right: 4),
      child: GestureDetector(
        onTap: _checkServerHealth,
        child: Tooltip(
          message: _serverStatus == ServerStatus.online
              ? 'Server online (${_lastLatencyMs}ms)  – tap to recheck'
              : _serverStatus == ServerStatus.offline
                  ? 'Server offline – tap to recheck'
                  : 'Checking server…',
          child: FadeTransition(
            opacity: _serverStatus == ServerStatus.checking
                ? _pulseCtrl
                : const AlwaysStoppedAnimation(1.0),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c,
                boxShadow: [
                  BoxShadow(color: c.withOpacity(0.5), blurRadius: 6)
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarIcon(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: NeuColors.background,
          borderRadius: BorderRadius.circular(12),
          boxShadow: neuRaisedShadows(depth: 0.6),
        ),
        child: Icon(icon, size: 20, color: NeuColors.textMuted),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, {required bool isLive, VoidCallback? onInfoTap}) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: GoogleFonts.nunito(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: NeuColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        if (onInfoTap != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onInfoTap,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: NeuColors.background,
                shape: BoxShape.circle,
                boxShadow: neuRaisedShadows(depth: 0.5),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: NeuColors.accent,
              ),
            ),
          ),
        ],
        const Spacer(),
        if (isLive)
          FadeTransition(
            opacity: _pulseCtrl,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: NeuColors.background,
                borderRadius: BorderRadius.circular(8),
                boxShadow: neuRaisedShadows(depth: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                      radius: 3, backgroundColor: NeuColors.error),
                  const SizedBox(width: 6),
                  Text(
                    'ACTIVE',
                    style: GoogleFonts.nunito(
                      color: NeuColors.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Container(
      height: 380,
      margin: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(32),
        boxShadow: neuRaisedShadows(depth: 1.2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon in inset circle
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              color: NeuColors.background,
              shape: BoxShape.circle,
              boxShadow: neuInsetShadows(),
            ),
            child: Icon(
              Icons.sign_language_rounded,
              size: 48,
              color: NeuColors.accent.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ready for Analysis',
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: NeuColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a video to begin sign recognition',
            style: GoogleFonts.nunito(
                fontSize: 14, color: NeuColors.textMuted),
          ),
          const SizedBox(height: 32),
          // Feature pills
          Wrap(
            spacing: 10,
            children: [
              _featurePill('BdSLW401', Icons.dataset_outlined),
              _featurePill('Word-Level', Icons.category_outlined),
              _featurePill('Grad-CAM', Icons.visibility_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _featurePill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: neuRaisedShadows(depth: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: NeuColors.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: NeuColors.text,
            ),
          ),
        ],
      ),
    );
  }

  // ── Video display ─────────────────────────────────────────────────────────
  Widget _buildVideoDisplay({required bool showOverlay, bool mini = false}) {
    final isInit = _controller?.value.isInitialized ?? false;
    return Container(
      height: mini ? 150 : null,
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(24),
        boxShadow: neuRaisedShadows(depth: mini ? 0.7 : 1.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: isInit ? _controller!.value.aspectRatio : 16 / 9,
        child: Stack(
          children: [
            if (isInit)
              VideoPlayer(_controller!)
            else
              Container(
                color: NeuColors.background,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(NeuColors.accent),
                    strokeWidth: 2,
                  ),
                ),
              ),
            if (showOverlay && _landmarkData != null && isInit) ...[
              Positioned.fill(
                child: ValueListenableBuilder(
                  valueListenable: _controller!,
                  builder: (ctx, value, _) {
                    final frameIdx = ((value.position.inMilliseconds /
                                (value.duration.inMilliseconds + 1)) *
                            (_landmarkData!.length - 1))
                        .toInt()
                        .clamp(0, _landmarkData!.length - 1);
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
              Positioned(
                top: 10,
                right: 10,
                child: GestureDetector(
                  onTap: _showGradCamDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: NeuColors.background.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: neuRaisedShadows(depth: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 13, color: NeuColors.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Grad-CAM Info',
                          style: GoogleFonts.nunito(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: NeuColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (!mini && isInit)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: NeuColors.accent,
                    bufferedColor: NeuColors.accent.withOpacity(0.3),
                    backgroundColor: Colors.black38,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Playback controls (Minimal Single-Row) ───────────────────────────────
  Widget _buildPlaybackControls() {
    final isPlaying = _controller?.value.isPlaying ?? false;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: neuRaisedShadows(depth: 0.7),
      ),
      child: Row(
        children: [
          // Replay button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _controller?.seekTo(Duration.zero);
              _controller?.play();
              setState(() {});
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: NeuColors.background,
                shape: BoxShape.circle,
                boxShadow: neuRaisedShadows(depth: 0.5),
              ),
              child: Icon(Icons.replay_rounded, size: 16, color: NeuColors.accent),
            ),
          ),
          const SizedBox(width: 8),
          // Play / Pause button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                isPlaying ? _controller?.pause() : _controller?.play();
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isPlaying ? NeuColors.accent : NeuColors.background,
                shape: BoxShape.circle,
                boxShadow: isPlaying ? neuInsetShadows() : neuRaisedShadows(depth: 0.6),
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                size: 18,
                color: isPlaying ? Colors.white : NeuColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Progress bar
          Expanded(
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              colors: VideoProgressColors(
                playedColor: NeuColors.accent,
                bufferedColor: NeuColors.accent.withOpacity(0.3),
                backgroundColor: NeuColors.darkShadow.withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Speed cycle pill
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              final idx = _speeds.indexOf(_playbackSpeed);
              final next = _speeds[(idx + 1) % _speeds.length];
              setState(() {
                _playbackSpeed = next;
                _controller?.setPlaybackSpeed(next);
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: NeuColors.background,
                borderRadius: BorderRadius.circular(10),
                boxShadow: neuRaisedShadows(depth: 0.5),
              ),
              child: Text(
                _playbackSpeed == _playbackSpeed.truncateToDouble()
                    ? '${_playbackSpeed.toInt()}x'
                    : '${_playbackSpeed}x',
                style: GoogleFonts.nunito(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: NeuColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Model selector ────────────────────────────────────────────────────────
  Widget _buildModelSelector() {
    // Split into two architecture groups
    final transformer = _availableModels
        .where((m) => m.startsWith('transformer'))
        .toList();
    final cnn = _availableModels
        .where((m) => m.startsWith('cnn'))
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: neuRaisedShadows(depth: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: NeuColors.background,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: neuRaisedShadows(depth: 0.6),
                ),
                child: Icon(Icons.tune_rounded,
                    size: 18, color: NeuColors.accent),
              ),
              const SizedBox(width: 12),
              Text(
                'MODEL SELECTION',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: NeuColors.text,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              // Currently selected model pill
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: NeuColors.background,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: neuInsetShadows(),
                ),
                child: Text(
                  _selectedModel.startsWith('transformer')
                      ? 'Transformer'
                      : 'CNN-BiLSTM',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: NeuColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // ── Transformer group ─────────────────────────────────────
          if (transformer.isNotEmpty) ...[
            _archLabel('Transformer', Icons.auto_awesome_rounded),
            const SizedBox(height: 10),
            _modelChipRow(transformer),
            const SizedBox(height: 14),
          ],

          // ── CNN-BiLSTM group ──────────────────────────────────────
          if (cnn.isNotEmpty) ...[
            _archLabel('CNN-BiLSTM', Icons.model_training_rounded),
            const SizedBox(height: 10),
            _modelChipRow(cnn),
          ],
        ],
      ),
    );
  }

  Widget _archLabel(String label, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 13, color: NeuColors.textMuted),
        const SizedBox(width: 6),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: NeuColors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _modelChipRow(List<String> models) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: models.map((m) {
        final selected = _selectedModel == m;
        final label = kModelLabels[m] ?? m;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selectedModel = m);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: selected ? NeuColors.accent : NeuColors.background,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected
                  ? neuInsetShadows()
                  : neuRaisedShadows(depth: 0.65),
            ),
            child: Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : NeuColors.textMuted,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Action panel ──────────────────────────────────────────────────────────
  Widget _buildActionPanel() {
    return Column(
      children: [
        if (_videoFile != null) ...[
          NeuButton(
            onTap: _isProcessing ? null : _sendToServer,
            child: _isProcessing
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: NeuColors.accent,
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ANALYZING…',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: NeuColors.textMuted,
                        ),
                      ),
                    ],
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.psychology_rounded, color: NeuColors.accent),
                      const SizedBox(width: 12),
                      Text(
                        'RUN RECOGNITION',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: NeuColors.text,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          children: [
            Expanded(
              child: NeuButton(
                onTap: () => _handleVideo(ImageSource.gallery),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.photo_library_outlined,
                        color: NeuColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'GALLERY',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        color: NeuColors.text,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: NeuButton(
                onTap: () => _handleVideo(ImageSource.camera),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_outlined,
                        color: NeuColors.accent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'CAMERA',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        color: NeuColors.text,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Error ─────────────────────────────────────────────────────────────────
  Widget _buildErrorDisplay() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(16),
        boxShadow: neuInsetShadows(),
        border: Border.all(color: NeuColors.error.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: NeuColors.error, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.nunito(
                color: NeuColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: Icon(Icons.close_rounded,
                color: NeuColors.textMuted, size: 18),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  About bottom sheet (private to this file)
// ─────────────────────────────────────────────────────────────────────────────
class _AboutSheet extends StatelessWidget {
  final String baseUrl;
  const _AboutSheet({required this.baseUrl});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.60,
      minChildSize: 0.30,
      maxChildSize: 0.92,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: NeuColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: NeuColors.darkShadow.withOpacity(0.25),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: NeuColors.darkShadow.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'About BdSL Recognizer',
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: NeuColors.text,
              ),
            ),
            const SizedBox(height: 20),
            _aboutRow(Icons.dataset_outlined, 'Dataset',
                'BdSLW401 – Bangladesh Sign Language Word Dataset'),
            _aboutRow(Icons.category_outlined, 'Task',
                'Word-Level Sign Recognition (Video Input)'),
            _aboutRow(Icons.model_training_outlined, 'Approach',
                'Body/Hand Pose Landmarks + Grad-CAM XAI'),
            _aboutRow(Icons.cloud_outlined, 'Backend',
                'Hugging Face Spaces · FastAPI'),
            _aboutRow(Icons.person_outlined, 'Researcher', 'Saifur Rahman, Toufika Tasnim'),
            _aboutRow(Icons.link_rounded, 'Endpoint', baseUrl),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: NeuColors.background,
                borderRadius: BorderRadius.circular(16),
                boxShadow: neuInsetShadows(),
              ),
              child: Text(
                'This app submits a video of a Bangla sign gesture to a '
                'deep learning model hosted on Hugging Face Spaces. '
                'The model returns the predicted Bangla word together with '
                'MediaPipe landmark overlays and Grad-CAM attention maps '
                'that highlight which body parts and frames drove the '
                'classification decision.',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  color: NeuColors.textMuted,
                  height: 1.65,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _aboutRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: NeuColors.background,
              borderRadius: BorderRadius.circular(10),
              boxShadow: neuRaisedShadows(depth: 0.6),
            ),
            child: Icon(icon, size: 18, color: NeuColors.accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.nunito(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: NeuColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: NeuColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
