import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/cinematic_colors.dart';
import '../theme/glassmorphism.dart';

/// Semantic version specification and comparison utilities
class AppVersion {
  static const String current = "1.1.9";
  static const int buildNumber = 15;
  static const String releaseStage = "Release";

  /// Compares two semver strings (e.g. "1.1.3" and "1.1.2")
  /// Returns > 0 if v1 > v2, < 0 if v1 < v2, and 0 if equal.
  static int compare(String v1, String v2) {
    final clean1 = _clean(v1);
    final clean2 = _clean(v2);

    final parts1 = clean1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = clean2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    while (parts1.length < 3) {
      parts1.add(0);
    }
    while (parts2.length < 3) {
      parts2.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (parts1[i] > parts2[i]) return 1;
      if (parts1[i] < parts2[i]) return -1;
    }
    return 0;
  }

  static String _clean(String ver) {
    var v = ver.trim();
    if (v.startsWith('v') || v.startsWith('V')) {
      v = v.substring(1);
    }
    final plusIdx = v.indexOf('+');
    if (plusIdx != -1) {
      v = v.substring(0, plusIdx);
    }
    final dashIdx = v.indexOf('-');
    if (dashIdx != -1) {
      v = v.substring(0, dashIdx);
    }
    return v;
  }
}

/// Metadata describing an available update
class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String releaseName;
  final String releaseNotes;
  final String htmlUrl;
  final String? directDownloadUrl;
  final DateTime publishedAt;
  final bool hasUpdate;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.htmlUrl,
    this.directDownloadUrl,
    required this.publishedAt,
    required this.hasUpdate,
  });
}

/// In-app GitHub release update service with persistent suppression and smart semver checking
class UpdateService {
  static String githubRepo = "gameszoom325-cell/Cinematic-Music-Player";

  static const String _prefKeyRemindUntil = "update_remind_later_until";
  static const String _prefKeySkipVersion = "update_skip_version";

  /// Checks GitHub releases API for newer version
  static Future<UpdateInfo?> checkForUpdates() async {
    try {
      final uri = Uri.parse("https://api.github.com/repos/$githubRepo/releases/latest");
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'CinematicMusicPlayer-App/1.1.3',
        },
      ).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawTag = data['tag_name'] as String? ?? '1.0.0';
        final releaseName = data['name'] as String? ?? rawTag;
        final releaseNotes = data['body'] as String? ?? 'Backend evolution, stream caching, and smart updates.';
        final htmlUrl = data['html_url'] as String? ?? 'https://github.com/$githubRepo/releases';
        final publishedStr = data['published_at'] as String? ?? '';
        final publishedAt = DateTime.tryParse(publishedStr) ?? DateTime.now();

        final hasNewer = AppVersion.compare(rawTag, AppVersion.current) > 0;

        // Resolve platform specific download asset
        String? downloadUrl;
        final assets = (data['assets'] as List<dynamic>?) ?? [];
        if (Platform.isAndroid) {
          final apkAsset = assets.firstWhere(
            (a) => (a['name'] as String? ?? '').endsWith('.apk'),
            orElse: () => null,
          );
          if (apkAsset != null) {
            downloadUrl = apkAsset['browser_download_url'] as String?;
          }
        } else if (Platform.isWindows) {
          final exeAsset = assets.firstWhere(
            (a) => (a['name'] as String? ?? '').endsWith('.exe'),
            orElse: () => assets.firstWhere(
              (a) => (a['name'] as String? ?? '').endsWith('.zip'),
              orElse: () => null,
            ),
          );
          if (exeAsset != null) {
            downloadUrl = exeAsset['browser_download_url'] as String?;
          }
        }

        return UpdateInfo(
          currentVersion: AppVersion.current,
          latestVersion: AppVersion._clean(rawTag),
          releaseName: releaseName,
          releaseNotes: releaseNotes,
          htmlUrl: htmlUrl,
          directDownloadUrl: downloadUrl,
          publishedAt: publishedAt,
          hasUpdate: hasNewer,
        );
      }
    } catch (e) {
      debugPrint("Update check notice: $e");
    }
    return null;
  }

  /// Checks whether an update alert for targetVersion is currently suppressed
  static Future<bool> isSuppressed(String targetVersion) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Check if user explicitly chose to skip this specific version
      final skipped = prefs.getString(_prefKeySkipVersion);
      if (skipped != null && AppVersion._clean(skipped) == AppVersion._clean(targetVersion)) {
        return true;
      }

      // 2. Check if user chose "Remind Me Later" and cooldown is still active
      final remindUntil = prefs.getInt(_prefKeyRemindUntil);
      if (remindUntil != null && DateTime.now().millisecondsSinceEpoch < remindUntil) {
        return true;
      }
    } catch (e) {
      debugPrint("UpdateService.isSuppressed warning: $e");
    }
    return false;
  }

  /// Sets a 24-hour reminder cooldown
  static Future<void> remindLater() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cooldownTime = DateTime.now().add(const Duration(hours: 24)).millisecondsSinceEpoch;
      await prefs.setInt(_prefKeyRemindUntil, cooldownTime);
      debugPrint("UpdateService: Reminder cooldown set until ${DateTime.fromMillisecondsSinceEpoch(cooldownTime)}");
    } catch (e) {
      debugPrint("UpdateService.remindLater error: $e");
    }
  }

  /// Permanently skips update prompt for a specific version tag
  static Future<void> skipVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeySkipVersion, AppVersion._clean(version));
      debugPrint("UpdateService: Version $version marked as skipped.");
    } catch (e) {
      debugPrint("UpdateService.skipVersion error: $e");
    }
  }

  /// Clears any reminder or skipped version suppressions
  static Future<void> resetSuppression() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyRemindUntil);
      await prefs.remove(_prefKeySkipVersion);
    } catch (_) {}
  }

  /// Check and prompt update dialog if newer version is available
  static Future<void> checkAndShowDialog(BuildContext context, {bool isManual = false}) async {
    final info = await checkForUpdates();

    if (!context.mounted) return;

    if (info != null && info.hasUpdate) {
      // If automatic check, respect user's suppression preferences
      if (!isManual) {
        final suppressed = await isSuppressed(info.latestVersion);
        if (suppressed) {
          debugPrint("UpdateService: Update prompt for v${info.latestVersion} suppressed by user preference.");
          return;
        }
      }

      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (_) => CinematicUpdateDialog(info: info),
      );
    } else if (isManual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("You are using the latest version (${AppVersion.current})"),
          backgroundColor: CinematicColors.electricViolet,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  static const String fallbackReleaseUrl = "https://github.com/gameszoom325-cell/Cinematic-Music-Player/releases/tag/v1.1.9";

  /// Launch GitHub release URL in external browser using LaunchMode.externalApplication.
  /// If launch fails, displays a floating SnackBar containing the URL with a COPY action.
  static Future<bool> openReleaseUrl(
    String url, {
    BuildContext? context,
    ScaffoldMessengerState? messenger,
  }) async {
    final cleanUrl = url.trim().isNotEmpty ? url.trim() : fallbackReleaseUrl;
    final uri = Uri.parse(cleanUrl);
    bool launched = false;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("UpdateService: Could not launch update URL ($cleanUrl): $e");
      launched = false;
    }

    if (!launched) {
      final msg = messenger ?? (context != null && context.mounted ? ScaffoldMessenger.maybeOf(context) : null);
      if (msg != null) {
        msg.showSnackBar(
          SnackBar(
            content: SelectableText(
              "Unable to open link in browser. Copy URL:\n$cleanUrl",
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            backgroundColor: Colors.redAccent.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: "COPY",
              textColor: Colors.amberAccent,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: cleanUrl));
              },
            ),
          ),
        );
      }
    }
    return launched;
  }

  /// Launch download or release URL in external browser
  static Future<void> openDownload(
    String url, {
    BuildContext? context,
    ScaffoldMessengerState? messenger,
  }) async {
    await openReleaseUrl(url, context: context, messenger: messenger);
  }
}

/// Polished Glassmorphic Update Dialog with Update Now, Remind Me Later, and Skip This Version
class CinematicUpdateDialog extends StatelessWidget {
  final UpdateInfo info;

  const CinematicUpdateDialog({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    // Resolve target release URL: ensure it points to the GitHub release page
    String targetUrl = info.htmlUrl;
    if (targetUrl.isEmpty || !targetUrl.contains('github.com')) {
      final tag = info.latestVersion.isNotEmpty ? 'v${info.latestVersion}' : 'v1.1.9';
      targetUrl = 'https://github.com/${UpdateService.githubRepo}/releases/tag/$tag';
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: CinematicGlassCard(
          padding: const EdgeInsets.all(24),
          borderRadius: 24,
          borderColor: CinematicColors.electricViolet.withOpacity(0.4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [CinematicColors.electricViolet, CinematicColors.deepPlum],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CinematicColors.electricViolet.withOpacity(0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text("🚀", style: TextStyle(fontSize: 24)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "New Version Available",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          "A performance & playback upgrade is ready.",
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Version Badges
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("INSTALLED", style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          "v${info.currentVersion}",
                          style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: CinematicColors.electricViolet, size: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text("LATEST", style: TextStyle(color: CinematicColors.neonCyan, fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          "v${info.latestVersion}",
                          style: const TextStyle(color: CinematicColors.neonCyan, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Release notes
              const Text(
                "WHAT'S NEW",
                style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes.trim(),
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, height: 1.45),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons: Update Now, Remind Me Later, Skip This Version
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: BorderSide(color: Colors.white.withOpacity(0.18)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await UpdateService.remindLater();
                      },
                      child: const Text("Remind Later", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CinematicColors.electricViolet,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(context);
                        await UpdateService.openReleaseUrl(
                          targetUrl,
                          messenger: messenger,
                        );
                      },
                      child: const Text("Update Now", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await UpdateService.skipVersion(info.latestVersion);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Version v${info.latestVersion} will be skipped."),
                          backgroundColor: Colors.grey[850],
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Text(
                    "Skip this version",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
