import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'l10n/app_strings.dart';
import 'landmark_painter.dart';
import 'services/offline_inference_service.dart';
import 'services/on_device_landmark_service.dart';
import 'theme/neu_theme.dart';
import 'widgets/app_drawer.dart';
import 'widgets/heatmap_legend.dart';
import 'widgets/history_panel.dart';
import 'widgets/neu_button.dart';
import 'widgets/result_card.dart';
import 'widgets/sentence_builder.dart';

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
  // ── Scaffold key ─────────────────────────────────────────────────────────
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // ── Offline Mode (Default: True - Offline First) ──────────────────────────
  bool _isOfflineMode = true;

  // ── Landmark Overlay Toggle (Show/Hide) ──────────────────────────────────
  bool _showLandmarks = true;

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
  Set<int> _favoriteIndices = {};

  // ── Sentence builder ────────────────────────────────────────────────────
  final List<String> _sentenceBuffer = [];

  // ── TTS ─────────────────────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();

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
    _initTts();
    OfflineInferenceService.initialize();
    _checkServerHealth();
    _fetchModels();
    _loadHistory();
    _loadFavorites();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _pulseCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  // ── TTS setup ───────────────────────────────────────────────────────────────
  Future<void> _initTts() async {
    await _tts.setLanguage('bn-BD');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> _speakBangla(String text) async {
    if (text.isEmpty) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  // ── Sentence builder ────────────────────────────────────────────────────────
  void _addToSentence(String word) {
    if (word.isEmpty) return;
    setState(() => _sentenceBuffer.add(word));
  }

  void _shareText(String text) {
    if (text.isEmpty) return;
    Share.share(text);
  }

  // ── Favorites persistence ───────────────────────────────────────────────────
  Future<void> _loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('bdslw_favorites') ?? [];
    setState(() {
      _favoriteIndices = raw.map((e) => int.tryParse(e) ?? -1).where((e) => e >= 0).toSet();
    });
  }

  Future<void> _persistFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'bdslw_favorites', _favoriteIndices.map((e) => e.toString()).toList());
  }

  void _toggleFavorite(int index) {
    setState(() {
      if (_favoriteIndices.contains(index)) {
        _favoriteIndices.remove(index);
      } else {
        _favoriteIndices.add(index);
      }
    });
    _persistFavorites();
  }

  // ── Language / theme toggles ─────────────────────────────────────────────────
  void _toggleLanguage() {
    HapticFeedback.mediumImpact();
    setState(() => AppStrings.isBangla = !AppStrings.isBangla);
  }

  void _toggleHighContrast() {
    HapticFeedback.mediumImpact();
    setState(() => NeuColors.highContrast = !NeuColors.highContrast);
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

  // ── Request tracking & auto-pause ──────────────────────────────────────────
  int _activeRequestId = 0;
  final bool _autoPauseAtEnd = true;

  void _onVideoTick() {
    if (!mounted || _controller == null) return;
    
    // Auto-pause video at end
    if (_autoPauseAtEnd &&
        _controller!.value.isInitialized &&
        _controller!.value.position >= _controller!.value.duration &&
        _controller!.value.isPlaying) {
      _controller!.pause();
      _controller!.seekTo(Duration.zero);
      setState(() {});
      return;
    }

    if (_landmarkData != null) {
      setState(() {});
    }
  }

  // ── Video picking (with 3-second limit and request cancellation) ─────────────
  Future<void> _handleVideo(ImageSource source) async {
    // Invalidate any ongoing in-flight request immediately
    _activeRequestId++;

    final video = await ImagePicker().pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 3), // Auto-stop after 3 seconds
    );
    if (video == null) return;

    // Reset video state safely
    _controller?.removeListener(_onVideoTick);
    _controller?.dispose();
    _controller = VideoPlayerController.file(File(video.path));
    await _controller!.initialize();
    _controller!.addListener(_onVideoTick);

    setState(() {
      _videoFile = video;
      _isProcessing = false;
      _prediction = null;
      _landmarkData = null;
      _focusPoints = null;
      _cam = null;
      _topPredictions = null;
      _errorMessage = null;
    });
  }

  // ── Run Recognition (Offline First & Online Cloud) ──────────────────────
  Future<void> _sendToServer() async {
    if (_videoFile == null) return;
    HapticFeedback.mediumImpact();

    final currentRequestId = ++_activeRequestId;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _prediction = null;
    });

    try {
      final sw = Stopwatch()..start();
      Map<String, dynamic> decoded;

      if (_isOfflineMode) {
        // ── ON-DEVICE OFFLINE NEURAL NETWORK INFERENCE ─────────────
        // Runs ONNX Runtime (CPU/GPU/NPU) + RQE-SF normalization on device
        List<List<double>>? mlkitLandmarks;
        try {
          final videoDurationMs = _controller?.value.duration.inMilliseconds;
          final realLandmarks = await OnDeviceLandmarkService.extractLandmarks(
            _videoFile!.path,
            frameCount: 30,
            videoDurationMs: videoDurationMs,
          );
          if (realLandmarks['landmarks'] != null &&
              (realLandmarks['landmarks'] as List).isNotEmpty) {
            mlkitLandmarks = (realLandmarks['landmarks'] as List)
                .map((f) => (f as List).map((v) => (v as num).toDouble()).toList())
                .toList();
          }
        } catch (e) {
          debugPrint('On-device landmark extraction note: $e');
        }

        decoded = await OfflineInferenceService.predictVideo(
          File(_videoFile!.path),
          modelType: _selectedModel,
          extractedLandmarks: mlkitLandmarks,
        );
        sw.stop();
      } else {
        // ── ONLINE CLOUD API ──────────────────────────────────────
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
          decoded = jsonDecode(body) as Map<String, dynamic>;
          if (decoded['error'] != null) {
            throw Exception(decoded['error']);
          }
          _serverStatus = ServerStatus.online;
        } else {
          throw Exception('Server error ${response.statusCode}');
        }
      }

      // If user retook/picked a new video while this request was running, discard it!
      if (currentRequestId != _activeRequestId || !mounted) return;

      final rawBangla = decoded['bangla']?.toString() ?? '';
      final banglaWord = cleanBangla(rawBangla);
      final pred = {
        'bangla':     banglaWord,
        'english':    decoded['english'],
        'confidence': decoded['confidence'],
        'model_used': decoded['model_used'] ?? _selectedModel,
      };
      await _addToHistory(pred);

      setState(() {
        _prediction     = pred;
        _landmarkData   = decoded['landmarks'];
        _focusPoints    = decoded['focus_points'];
        _cam            = decoded['cam'];
        _topPredictions = decoded['top_predictions'];
        _lastLatencyMs  = sw.elapsedMilliseconds;
        _showLandmarks  = true;
      });

      _controller?.seekTo(Duration.zero);
      _controller?.play();
      _controller?.setLooping(false); // Let it play once and auto-pause cleanly!
      _controller?.setPlaybackSpeed(_playbackSpeed);

      // Auto-speak the recognized Bangla word (single word, no slashes)
      _speakBangla(banglaWord);

      // Auto-add to sentence builder (single word, no slashes)
      _addToSentence(banglaWord);
    } catch (e) {
      if (currentRequestId != _activeRequestId || !mounted) return;
      final msg = e.toString();
      setState(() {
        _errorMessage = msg;
        if (msg.contains('SocketException') ||
            msg.contains('TimeoutException')) {
          _serverStatus = ServerStatus.offline;
        }
      });
    } finally {
      if (currentRequestId == _activeRequestId && mounted) {
        setState(() => _isProcessing = false);
      }
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
        favoriteIndices: _favoriteIndices,
        onToggleFavorite: _toggleFavorite,
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
      key: _scaffoldKey,
      drawer: AppDrawer(
        isOfflineMode: _isOfflineMode,
        onToggleOfflineMode: (val) => setState(() => _isOfflineMode = val),
        selectedModel: _selectedModel,
        availableModels: _availableModels,
        onSelectModel: (m) => setState(() => _selectedModel = m),
        onOpenHistory: _openHistory,
        onOpenAbout: _openAbout,
        onShowGradCam: _showGradCamDialog,
        onToggleLanguage: _toggleLanguage,
        onToggleTheme: _toggleHighContrast,
        historyCount: _history.length,
        favoritesCount: _favoriteIndices.length,
        serverStatus: _serverStatus,
        latencyMs: _lastLatencyMs,
      ),
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
                      AppStrings.analysisEngine,
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
                        allFramesFocus: _focusPoints,
                        onSpeak: () => _speakBangla(
                            _prediction!['bangla']?.toString() ?? ''),
                        onShare: () {
                          final b = _prediction!['bangla'] ?? '';
                          final e = _prediction!['english'] ?? '';
                          final c = _prediction!['confidence'] ?? '';
                          _shareText('$b — $e ($c)');
                        },
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                  // Sentence builder
                  if (_sentenceBuffer.isNotEmpty || _prediction != null) ...[
                    SentenceBuilder(
                      words: _sentenceBuffer,
                      onClear: () => setState(() => _sentenceBuffer.clear()),
                      onSpeakAll: () =>
                          _speakBangla(_sentenceBuffer.join(' ')),
                      onShare: () =>
                          _shareText(_sentenceBuffer.join(' ')),
                      onRemoveWord: (i) => setState(
                          () => _sentenceBuffer.removeAt(i)),
                    ),
                    const SizedBox(height: 24),
                  ],
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
      leading: _buildAppBarIcon(
        Icons.menu_rounded,
        () => _scaffoldKey.currentState?.openDrawer(),
        tooltip: AppStrings.menu,
      ),
      title: Column(
        children: [
          Text(
            AppStrings.appTitle,
            style: GoogleFonts.nunito(
              fontWeight: FontWeight.w900,
              fontSize: 17,
              letterSpacing: 1.2,
              color: NeuColors.text,
            ),
          ),
          Text(
            AppStrings.subtitle,
            style: GoogleFonts.nunito(
              fontSize: 8.5,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w700,
              color: NeuColors.textMuted,
            ),
          ),
        ],
      ),
      actions: [
        _buildModeToggleChip(),
        if (!_isOfflineMode) _buildServerDot(),
        _buildAppBarIcon(Icons.history_rounded, _openHistory, tooltip: AppStrings.recognitionHistory),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildModeToggleChip() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        setState(() => _isOfflineMode = !_isOfflineMode);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: _isOfflineMode ? NeuColors.success : NeuColors.accent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: neuRaisedShadows(depth: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isOfflineMode ? Icons.phone_android_rounded : Icons.cloud_done_rounded,
              size: 13,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              _isOfflineMode
                  ? (AppStrings.isBangla ? 'অফলাইন' : 'Offline')
                  : (AppStrings.isBangla ? 'অনলাইন' : 'Online'),
              style: GoogleFonts.nunito(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
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

  Widget _buildAppBarIcon(IconData icon, VoidCallback onTap, {String? tooltip}) {
    final child = GestureDetector(
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
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: child);
    }
    return child;
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
                    AppStrings.active,
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
          // Logo in inset circle
          Container(
            width: 104,
            height: 104,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: NeuColors.background,
              shape: BoxShape.circle,
              boxShadow: neuInsetShadows(),
            ),
            child: Image.asset(
              'assets/images/BdSL_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.sign_language_rounded,
                size: 48,
                color: NeuColors.accent.withValues(alpha: 0.65),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            AppStrings.readyForAnalysis,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: NeuColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.selectVideo,
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

  // ── Landmark Interpolators for 100% video-sync precision ────────────────
  List<dynamic> _interpolateLandmarkFrame(double progress) {
    if (_landmarkData == null || _landmarkData!.isEmpty) return [];
    final total = _landmarkData!.length;
    if (total == 1) return _landmarkData!.first as List<dynamic>;

    final exact = progress * (total - 1);
    final f0 = exact.floor().clamp(0, total - 1);
    final f1 = exact.ceil().clamp(0, total - 1);
    final alpha = exact - f0;

    final frame0 = _landmarkData![f0] as List<dynamic>;
    if (f0 == f1 || alpha <= 0.001) return frame0;
    final frame1 = _landmarkData![f1] as List<dynamic>;

    final len = min(frame0.length, frame1.length);
    final out = List<double>.filled(len, 0.0);
    for (int i = 0; i < len; i++) {
      final p0 = (frame0[i] as num).toDouble();
      final p1 = (frame1[i] as num).toDouble();
      out[i] = p0 + (p1 - p0) * alpha;
    }
    return out;
  }

  List<dynamic>? _interpolateFocusFrame(double progress) {
    if (_focusPoints == null || _focusPoints!.isEmpty) return null;
    final total = _focusPoints!.length;
    if (total == 1) return _focusPoints!.first as List<dynamic>;

    final exact = progress * (total - 1);
    final f0 = exact.floor().clamp(0, total - 1);
    final f1 = exact.ceil().clamp(0, total - 1);
    final alpha = exact - f0;

    final frame0 = _focusPoints![f0] as List<dynamic>;
    if (f0 == f1 || alpha <= 0.001) return frame0;
    final frame1 = _focusPoints![f1] as List<dynamic>;

    final len = min(frame0.length, frame1.length);
    final out = List<double>.filled(len, 0.0);
    for (int i = 0; i < len; i++) {
      final p0 = (frame0[i] as num).toDouble();
      final p1 = (frame1[i] as num).toDouble();
      out[i] = p0 + (p1 - p0) * alpha;
    }
    return out;
  }

  double _interpolateCamValue(double progress) {
    if (_cam == null || _cam!.isEmpty) return 0.0;
    final total = _cam!.length;
    if (total == 1) return (_cam!.first as num).toDouble();

    final exact = progress * (total - 1);
    final f0 = exact.floor().clamp(0, total - 1);
    final f1 = exact.ceil().clamp(0, total - 1);
    final alpha = exact - f0;

    final c0 = (_cam![f0] as num).toDouble();
    if (f0 == f1 || alpha <= 0.001) return c0;
    final c1 = (_cam![f1] as num).toDouble();
    return c0 + (c1 - c0) * alpha;
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
              if (_showLandmarks)
                Positioned.fill(
                  child: Builder(
                    builder: (ctx) {
                      final dur = _controller!.value.duration.inMilliseconds;
                      final pos = _controller!.value.position.inMilliseconds;
                      final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;

                      final pts = _interpolateLandmarkFrame(progress);
                      final focus = _interpolateFocusFrame(progress);
                      final cam = _interpolateCamValue(progress);

                      return CustomPaint(
                        painter: LandmarkPainter(
                          pts,
                          frameFocus: focus,
                          cam: cam,
                        ),
                      );
                    },
                  ),
                ),
              Positioned(
                top: 10,
                right: 10,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Landmark Show/Hide Toggle ──
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        setState(() => _showLandmarks = !_showLandmarks);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: _showLandmarks
                              ? NeuColors.accent
                              : NeuColors.background.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: neuRaisedShadows(depth: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showLandmarks
                                  ? Icons.visibility_rounded
                                  : Icons.visibility_off_rounded,
                              size: 13,
                              color: _showLandmarks ? Colors.white : NeuColors.textMuted,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showLandmarks
                                  ? (_isOfflineMode ? 'ML Kit' : 'Landmarks')
                                  : 'Hidden',
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _showLandmarks ? Colors.white : NeuColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // ── Grad-CAM Info ──
                    GestureDetector(
                      onTap: _showGradCamDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: NeuColors.background.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: neuRaisedShadows(depth: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline_rounded, size: 13, color: NeuColors.accent),
                            const SizedBox(width: 4),
                            Text(
                              'Info',
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
                  ],
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

  // ── Model selector (Dropdown) ──────────────────────────────────────────
  Widget _buildModelSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: neuRaisedShadows(depth: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: NeuColors.background,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: neuRaisedShadows(depth: 0.5),
                ),
                child: Icon(Icons.tune_rounded, size: 17, color: NeuColors.accent),
              ),
              const SizedBox(width: 10),
              Text(
                AppStrings.modelSelection.toUpperCase(),
                style: GoogleFonts.nunito(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: NeuColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: NeuColors.background,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: neuInsetShadows(),
                ),
                child: Text(
                  _selectedModel.startsWith('transformer')
                      ? AppStrings.transformer
                      : AppStrings.cnnBiLSTM,
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: NeuColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              color: NeuColors.background,
              borderRadius: BorderRadius.circular(16),
              boxShadow: neuInsetShadows(),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _availableModels.contains(_selectedModel)
                    ? _selectedModel
                    : _availableModels.first,
                isExpanded: true,
                dropdownColor: NeuColors.background,
                borderRadius: BorderRadius.circular(18),
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: NeuColors.accent),
                items: _availableModels.map((m) {
                  final isTransformer = m.startsWith('transformer');
                  final label = kModelLabels[m] ?? m;
                  final arch = isTransformer ? 'Transformer' : 'CNN-BiLSTM';
                  return DropdownMenuItem<String>(
                    value: m,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isTransformer ? NeuColors.accent : NeuColors.warning)
                                .withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isTransformer ? 'TR' : 'CNN',
                            style: GoogleFonts.nunito(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: isTransformer ? NeuColors.accent : NeuColors.warning,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$arch · $label',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: NeuColors.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newModel) {
                  if (newModel != null) {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedModel = newModel);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Action panel ──────────────────────────────────────────────────────────
  Widget _buildActionPanel() {
    return Column(
      children: [
        // 3-Step Rhythm guidance card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: NeuColors.background,
            borderRadius: BorderRadius.circular(16),
            boxShadow: neuInsetShadows(),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: NeuColors.background,
                  shape: BoxShape.circle,
                  boxShadow: neuRaisedShadows(depth: 0.4),
                ),
                child: Icon(Icons.timer_outlined, size: 15, color: NeuColors.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '3-Step Sign Rhythm (3s Max):\nReady (0.5s) → Sign (1.5s) → Rest (0.5s)',
                  style: GoogleFonts.nunito(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: NeuColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
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
                        AppStrings.analyzing,
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
                        AppStrings.runRecognition,
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
                      AppStrings.gallery,
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
                      AppStrings.camera,
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
              AppStrings.aboutTitle,
              style: GoogleFonts.nunito(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: NeuColors.text,
              ),
            ),
            const SizedBox(height: 20),
            _aboutRow(Icons.dataset_outlined, AppStrings.dataset,
                'BdSLW401 – Bangladesh Sign Language Word Dataset'),
            _aboutRow(Icons.category_outlined, AppStrings.task,
                'Word-Level Sign Recognition (Video Input)'),
            _aboutRow(Icons.model_training_outlined, AppStrings.approach,
                'Body/Hand Pose Landmarks + Grad-CAM XAI'),
            _aboutRow(Icons.cloud_outlined, AppStrings.backend,
                'Hugging Face Spaces · FastAPI'),
            _aboutRow(Icons.person_outlined, AppStrings.researcher, 'Saifur Rahman and Toufika Tasnim'),
            _aboutRow(Icons.link_rounded, AppStrings.endpoint, baseUrl),
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
