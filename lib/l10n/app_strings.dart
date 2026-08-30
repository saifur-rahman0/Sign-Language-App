/// Bilingual string map for English ↔ বাংলা UI.
///
/// Toggle [isBangla] to switch all UI labels globally.
/// All getters return the appropriate string based on the current language.
class AppStrings {
  AppStrings._();

  static bool isBangla = false;

  // ── App bar / general ─────────────────────────────────────────────────────
  static String get appTitle => 'BdSL';
  static String get subtitle =>
      isBangla
          ? 'বাংলা ইশারা ভাষা · শব্দ স্তর'
          : 'BANGLA SIGN LANGUAGE · WORD LEVEL';

  // ── Empty state ───────────────────────────────────────────────────────────
  static String get readyForAnalysis =>
      isBangla ? 'বিশ্লেষণের জন্য প্রস্তুত' : 'Ready for Analysis';
  static String get selectVideo =>
      isBangla
          ? 'ইশারা ভাষা শনাক্ত করতে একটি ভিডিও নির্বাচন করুন'
          : 'Select a video to begin sign recognition';

  // ── Section headers ───────────────────────────────────────────────────────
  static String get analysisEngine =>
      isBangla ? 'বিশ্লেষণ ইঞ্জিন' : 'Analysis Engine';
  static String get modelSelection =>
      isBangla ? 'মডেল নির্বাচন' : 'MODEL SELECTION';
  static String get active => isBangla ? 'সক্রিয়' : 'ACTIVE';

  // ── Action buttons ────────────────────────────────────────────────────────
  static String get runRecognition =>
      isBangla ? 'শনাক্তকরণ চালান' : 'RUN RECOGNITION';
  static String get analyzing => isBangla ? 'বিশ্লেষণ হচ্ছে…' : 'ANALYZING…';
  static String get gallery => isBangla ? 'গ্যালারি' : 'GALLERY';
  static String get camera => isBangla ? 'ক্যামেরা' : 'CAMERA';

  // ── Result card ───────────────────────────────────────────────────────────
  static String get predictedGesture =>
      isBangla ? 'শনাক্তকৃত ইশারা' : 'PREDICTED GESTURE';
  static String get confidence => isBangla ? 'আত্মবিশ্বাস' : 'CONFIDENCE';
  static String get topPredictions =>
      isBangla ? 'শীর্ষ ভবিষ্যদ্বাণী' : 'TOP PREDICTIONS';
  static String get speak => isBangla ? 'শুনুন' : 'Speak';
  static String get copy => isBangla ? 'কপি' : 'Copy';
  static String get share => isBangla ? 'শেয়ার' : 'Share';

  // ── Sentence builder ──────────────────────────────────────────────────────
  static String get sentenceBuilder =>
      isBangla ? 'বাক্য তৈরি' : 'SENTENCE BUILDER';
  static String get sentenceEmpty =>
      isBangla
          ? 'ইশারা করে বাক্য তৈরি শুরু করুন'
          : 'Start signing to build a sentence';
  static String get clearAll => isBangla ? 'সব মুছুন' : 'Clear All';
  static String get speakAll => isBangla ? 'সব শুনুন' : 'Speak All';

  // ── History ───────────────────────────────────────────────────────────────
  static String get recognitionHistory =>
      isBangla ? 'শনাক্তকরণ ইতিহাস' : 'Recognition History';
  static String get noHistoryYet =>
      isBangla ? 'এখনো কোনো ইতিহাস নেই' : 'No history yet';
  static String get runToSeeResults =>
      isBangla
          ? 'ফলাফল দেখতে শনাক্তকরণ চালান'
          : 'Run a recognition to see results here';
  static String get all => isBangla ? 'সব' : 'All';
  static String get favorites => isBangla ? 'পছন্দের' : 'Favorites';

  // ── Articulator ───────────────────────────────────────────────────────────
  static String get articulatorBreakdown =>
      isBangla ? 'অঙ্গ গুরুত্ব' : 'ARTICULATOR IMPORTANCE';
  static String get face => isBangla ? 'মুখ' : 'Face';
  static String get leftHand => isBangla ? 'বাম হাত' : 'L. Hand';
  static String get rightHand => isBangla ? 'ডান হাত' : 'R. Hand';
  static String get pose => isBangla ? 'ভঙ্গি' : 'Pose';

  // ── About ─────────────────────────────────────────────────────────────────
  static String get aboutTitle =>
      isBangla ? 'বিডিএসএল রিকগনাইজার সম্পর্কে' : 'About BdSL Recognizer';
  static String get dataset => isBangla ? 'ডেটাসেট' : 'Dataset';
  static String get task => isBangla ? 'কাজ' : 'Task';
  static String get approach => isBangla ? 'পদ্ধতি' : 'Approach';
  static String get backend => isBangla ? 'ব্যাকএন্ড' : 'Backend';
  static String get researcher => isBangla ? 'গবেষক' : 'Researcher';
  static String get endpoint => isBangla ? 'এন্ডপয়েন্ট' : 'Endpoint';

  // ── Grad-CAM ──────────────────────────────────────────────────────────────
  static String get gradCamAttention =>
      isBangla ? 'গ্র্যাড-ক্যাম মনোযোগ মানচিত্র' : 'GRAD-CAM ATTENTION MAP';

  // ── Server status ─────────────────────────────────────────────────────────
  static String get serverOnline =>
      isBangla ? 'সার্ভার অনলাইন' : 'Server online';
  static String get serverOffline =>
      isBangla ? 'সার্ভার অফলাইন' : 'Server offline';
  static String get checkingServer =>
      isBangla ? 'সার্ভার পরীক্ষা হচ্ছে…' : 'Checking server…';

  // ── Online / Offline Modes ────────────────────────────────────────────────
  static String get onlineMode =>
      isBangla ? 'অনলাইন ক্লাউড' : 'Online Cloud';
  static String get offlineMode =>
      isBangla ? 'অফলাইন ডিভাইস' : 'Offline On-Device';
  static String get mode => isBangla ? 'মোড' : 'Mode';
  static String get executionEngine =>
      isBangla ? 'এক্সিকিউশন ইঞ্জিন' : 'EXECUTION ENGINE';
  static String get offlineEngineActive =>
      isBangla ? 'অন-ডিভাইস এআই সক্রিয় (ইন্টারনেট ছাড়া)' : 'On-Device AI Active (No Internet)';
  static String get cloudApiActive =>
      isBangla ? 'ক্লাউড সার্ভার সক্রিয়' : 'HuggingFace Cloud API Active';

  // ── Navigation / Sidebar ──────────────────────────────────────────────────
  static String get menu => isBangla ? 'মেনু' : 'Menu';
  static String get navigation => isBangla ? 'নেভিগেশন' : 'Navigation';
  static String get hubTitle => isBangla ? 'বিডিএসএল কন্ট্রোল হাব' : 'BdSL Control Hub';
  static String get quickSettings => isBangla ? 'কুইক সেটিংস' : 'QUICK SETTINGS';
  static String get features => isBangla ? 'ফিচারসমূহ' : 'FEATURES';
  static String get language => isBangla ? 'ভাষা' : 'Language';
  static String get theme => isBangla ? 'থিম' : 'Theme';
  static String get darkMode => isBangla ? 'ডার্ক মোড' : 'Dark Mode';
  static String get lightMode => isBangla ? 'লাইট মোড' : 'Light Mode';
  static String get aboutApp => isBangla ? 'অ্যাপ সম্পর্কিত' : 'About App';
  static String get close => isBangla ? 'বন্ধ করুন' : 'Close';

  // ── Misc ──────────────────────────────────────────────────────────────────
  static String get copied => isBangla ? 'কপি করা হয়েছে!' : 'Copied!';
  static String get shared => isBangla ? 'শেয়ার করা হয়েছে' : 'Shared';
  static String get transformer => 'Transformer';
  static String get cnnBiLSTM => 'CNN-BiLSTM';
}
