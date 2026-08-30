import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_strings.dart';
import '../theme/neu_theme.dart';

/// Premium Neumorphic Navigation Sidebar Drawer.
///
/// Houses all app controls, online/offline mode toggle, model selector,
/// history, sentence builder status, themes, language, and system diagnostics.
class AppDrawer extends StatelessWidget {
  final bool isOfflineMode;
  final ValueChanged<bool> onToggleOfflineMode;
  final String selectedModel;
  final List<String> availableModels;
  final ValueChanged<String> onSelectModel;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenAbout;
  final VoidCallback onShowGradCam;
  final VoidCallback onToggleLanguage;
  final VoidCallback onToggleTheme;
  final int historyCount;
  final int favoritesCount;
  final ServerStatus serverStatus;
  final int latencyMs;

  const AppDrawer({
    super.key,
    required this.isOfflineMode,
    required this.onToggleOfflineMode,
    required this.selectedModel,
    required this.availableModels,
    required this.onSelectModel,
    required this.onOpenHistory,
    required this.onOpenAbout,
    required this.onShowGradCam,
    required this.onToggleLanguage,
    required this.onToggleTheme,
    required this.historyCount,
    required this.favoritesCount,
    required this.serverStatus,
    required this.latencyMs,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: NeuColors.background,
      elevation: 16,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            _buildDrawerHeader(context),

            // ── Scrollable content ───────────────────────────────────
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                children: [
                  // ── Mode Switcher Card ─────────────────────────────
                  _buildModeSwitcherCard(),
                  const SizedBox(height: 18),

                  // ── Model Selection in Drawer ───────────────────────
                  _buildModelSection(),
                  const SizedBox(height: 18),

                  // ── Features & Navigation ──────────────────────────
                  _buildSectionTitle(AppStrings.features),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    icon: Icons.history_rounded,
                    title: AppStrings.recognitionHistory,
                    badge: '$historyCount',
                    subBadge: favoritesCount > 0 ? '★ $favoritesCount' : null,
                    onTap: () {
                      Navigator.pop(context);
                      onOpenHistory();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.visibility_outlined,
                    title: 'Grad-CAM XAI',
                    onTap: () {
                      Navigator.pop(context);
                      onShowGradCam();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.info_outline_rounded,
                    title: AppStrings.aboutApp,
                    onTap: () {
                      Navigator.pop(context);
                      onOpenAbout();
                    },
                  ),
                  const SizedBox(height: 18),

                  // ── Quick Settings ─────────────────────────────────
                  _buildSectionTitle(AppStrings.quickSettings),
                  const SizedBox(height: 8),
                  _buildDrawerItem(
                    icon: Icons.translate_rounded,
                    title: AppStrings.language,
                    badge: AppStrings.isBangla ? 'বাংলা' : 'English',
                    onTap: onToggleLanguage,
                  ),
                  _buildDrawerItem(
                    icon: NeuColors.highContrast
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    title: AppStrings.theme,
                    badge: NeuColors.highContrast
                        ? AppStrings.darkMode
                        : AppStrings.lightMode,
                    onTap: onToggleTheme,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // ── Footer Diagnostics ───────────────────────────────────
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Header Widget ──────────────────────────────────────────────────────────
  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: NeuColors.background,
        boxShadow: [
          BoxShadow(
            color: NeuColors.darkShadow.withOpacity(0.3),
            offset: const Offset(0, 4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: NeuColors.background,
              borderRadius: BorderRadius.circular(14),
              boxShadow: neuRaisedShadows(depth: 0.7),
            ),
            child: Image.asset(
              'assets/images/BdSL_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(
                Icons.sign_language_rounded,
                size: 24,
                color: NeuColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.hubTitle,
                  style: GoogleFonts.nunito(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: NeuColors.text,
                  ),
                ),
                Text(
                  'BdSLW401 · v1.0.0',
                  style: GoogleFonts.nunito(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: NeuColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: NeuColors.background,
                shape: BoxShape.circle,
                boxShadow: neuRaisedShadows(depth: 0.5),
              ),
              child: Icon(Icons.close_rounded,
                  size: 16, color: NeuColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode Switcher Card ─────────────────────────────────────────────────────
  Widget _buildModeSwitcherCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: neuRaisedShadows(depth: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOfflineMode ? Icons.bolt_rounded : Icons.cloud_outlined,
                size: 16,
                color: NeuColors.accent,
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.executionEngine,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: NeuColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Sliding Mode Switch Pill
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: NeuColors.background,
              borderRadius: BorderRadius.circular(16),
              boxShadow: neuInsetShadows(),
            ),
            child: Row(
              children: [
                // Offline Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onToggleOfflineMode(true);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: isOfflineMode
                            ? NeuColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: isOfflineMode
                            ? neuRaisedShadows(depth: 0.5)
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.phone_android_rounded,
                            size: 14,
                            color: isOfflineMode
                                ? Colors.white
                                : NeuColors.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            AppStrings.offlineMode,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isOfflineMode
                                  ? Colors.white
                                  : NeuColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Online Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      onToggleOfflineMode(false);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      decoration: BoxDecoration(
                        color: !isOfflineMode
                            ? NeuColors.accent
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: !isOfflineMode
                            ? neuRaisedShadows(depth: 0.5)
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_queue_rounded,
                            size: 14,
                            color: !isOfflineMode
                                ? Colors.white
                                : NeuColors.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            AppStrings.onlineMode,
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: !isOfflineMode
                                  ? Colors.white
                                  : NeuColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isOfflineMode
                ? AppStrings.offlineEngineActive
                : AppStrings.cloudApiActive,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: isOfflineMode ? NeuColors.success : NeuColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Model Selection Section ────────────────────────────────────────────────
  Widget _buildModelSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeuColors.background,
        borderRadius: BorderRadius.circular(20),
        boxShadow: neuRaisedShadows(depth: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: NeuColors.accent),
              const SizedBox(width: 8),
              Text(
                AppStrings.modelSelection,
                style: GoogleFonts.nunito(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: NeuColors.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: availableModels.map((m) {
              final isSel = selectedModel == m;
              final shortName = m.replaceAll('transformer_', 'TR:').replaceAll('cnn_', 'CNN:').replaceAll('interpolated_', 'int-');
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelectModel(m);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSel ? NeuColors.accent : NeuColors.background,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isSel
                        ? neuInsetShadows()
                        : neuRaisedShadows(depth: 0.4),
                  ),
                  child: Text(
                    shortName,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isSel ? Colors.white : NeuColors.textMuted,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.nunito(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: NeuColors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    String? badge,
    String? subBadge,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: NeuColors.background,
            borderRadius: BorderRadius.circular(16),
            boxShadow: neuRaisedShadows(depth: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: NeuColors.background,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: neuInsetShadows(),
                ),
                child: Icon(icon, size: 16, color: NeuColors.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.nunito(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: NeuColors.text,
                  ),
                ),
              ),
              if (subBadge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NeuColors.warning.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subBadge,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: NeuColors.warning,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: NeuColors.background,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: neuInsetShadows(),
                  ),
                  child: Text(
                    badge,
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: NeuColors.accent,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: NeuColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NeuColors.background,
        boxShadow: [
          BoxShadow(
            color: NeuColors.darkShadow.withOpacity(0.2),
            offset: const Offset(0, -4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOfflineMode
                  ? NeuColors.success
                  : (serverStatus == ServerStatus.online
                      ? NeuColors.success
                      : NeuColors.error),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isOfflineMode
                ? 'Offline Engine Active'
                : (serverStatus == ServerStatus.online
                    ? 'Online ($latencyMs ms)'
                    : 'Server Offline'),
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: NeuColors.textMuted,
            ),
          ),
          const Spacer(),
          Text(
            'BdSLW401',
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: NeuColors.accent,
            ),
          ),
        ],
      ),
    );
  }
}
