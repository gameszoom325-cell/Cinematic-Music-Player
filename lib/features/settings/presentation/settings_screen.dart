import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../visualizer/providers/visualizer_provider.dart';
import '../../visualizer/models/visualizer_preset.dart';
import '../../auth/providers/auth_provider.dart';
import '../../sync/providers/sync_provider.dart';
import '../../../auth/user_model.dart';
import '../../../auth/session_manager.dart';
import '../../../auth/auth_service.dart';
import '../../../auth/welcome_screen.dart';
import '../../../auth/login_screen.dart';
import '../../../sync/cloud_database.dart';
import '../../../sync/sync_manager.dart';
import '../../../core/theme/cinematic_colors.dart';
import '../../../core/theme/glassmorphism.dart';
import '../../../core/theme/typography.dart';
import '../../../core/services/update_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return "Never";
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  void _showRemoveDeviceDialog(BuildContext context, DeviceModel device, WidgetRef ref) {
    final isThisDevice = device.deviceId == SessionManager.instance.deviceId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: CinematicColors.obsidianCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isThisDevice ? "Disconnect This Device?" : "Remove Device?",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          isThisDevice
              ? "This will log you out of this device and return to local vault mode."
              : "Are you sure you want to de-authorize '${device.deviceName}'? It will be disconnected from cloud sync.",
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await SyncManager.instance.removeDevice(device.deviceId);
              if (isThisDevice) {
                ref.read(authProvider.notifier).refresh();
              }
            },
            child: Text(isThisDevice ? "Disconnect" : "Remove"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final syncMgr = ref.watch(syncProvider);
    final visualizerState = ref.watch(visualizerProvider);
    final visualizerNotifier = ref.read(visualizerProvider.notifier);

    final isLoggedIn = user != null && !user.isGuest;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Settings", style: CinematicTypography.displayTitle),
              const SizedBox(height: 18),

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    // 1. Account & Multi-Device Profile Card
                    _buildSectionHeader("ACCOUNT & MULTI-DEVICE"),
                    _buildAccountCard(context, user, isLoggedIn, ref),
                    const SizedBox(height: 24),

                    // 2. Cloud Synchronization Section
                    if (isLoggedIn) ...[
                      _buildSectionHeader("CLOUD SYNCHRONIZATION"),
                      _buildSyncCard(context, syncMgr),
                      const SizedBox(height: 24),

                      // 3. Connected Devices Section
                      _buildSectionHeader("CONNECTED DEVICES"),
                      _buildConnectedDevicesCard(context, syncMgr, ref),
                      const SizedBox(height: 24),
                    ],

                    // 4. Visualizer Engine
                    _buildSectionHeader("VISUALIZER ENGINE"),
                    CinematicGlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 18,
                      child: Column(
                        children: [
                          _buildDropdownTile<VisualizerPresetType>(
                            title: "Active Visualizer Preset",
                            value: visualizerState.preset,
                            items: const [
                              DropdownMenuItem(
                                value: VisualizerPresetType.orb3d,
                                child: Text("3D Liquid Raymarched Orb"),
                              ),
                              DropdownMenuItem(
                                value: VisualizerPresetType.polarRing,
                                child: Text("Polar Spectrum Ring"),
                              ),
                              DropdownMenuItem(
                                value: VisualizerPresetType.auroraMesh,
                                child: Text("Aurora Dynamic Mesh"),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) visualizerNotifier.setPreset(val);
                            },
                          ),
                          const Divider(color: Colors.white12, height: 24),
                          _buildDropdownTile<AtmosphereType>(
                            title: "Atmospheric Simulation",
                            value: visualizerState.atmosphere,
                            items: const [
                              DropdownMenuItem(value: AtmosphereType.none, child: Text("None")),
                              DropdownMenuItem(value: AtmosphereType.rain, child: Text("Rain Mode")),
                              DropdownMenuItem(value: AtmosphereType.snow, child: Text("Snow Particles")),
                              DropdownMenuItem(value: AtmosphereType.dust, child: Text("Floating Dust")),
                              DropdownMenuItem(value: AtmosphereType.fireflies, child: Text("Fireflies")),
                            ],
                            onChanged: (val) {
                              if (val != null) visualizerNotifier.setAtmosphere(val);
                            },
                          ),
                          const Divider(color: Colors.white12, height: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text("Audio Reactive Sensitivity", style: TextStyle(color: Colors.white, fontSize: 14)),
                                  Text(
                                    "${visualizerState.sensitivity.toStringAsFixed(1)}x",
                                    style: const TextStyle(
                                      color: CinematicColors.neonCyan,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Slider(
                                value: visualizerState.sensitivity,
                                min: 0.4,
                                max: 2.5,
                                activeColor: CinematicColors.electricViolet,
                                inactiveColor: Colors.white12,
                                onChanged: (val) => visualizerNotifier.setSensitivity(val),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 5. Audio Engine & Performance Info
                    _buildSectionHeader("AUDIO ENGINE & PERFORMANCE"),
                    CinematicGlassCard(
                      padding: const EdgeInsets.all(16),
                      borderRadius: 18,
                      child: Column(
                        children: [
                          _buildInfoTile("Platform Backend", "just_audio (Gapless) + audio_service"),
                          const Divider(color: Colors.white12, height: 20),
                          _buildInfoTile("Audio Reactive Bridge", "Hybrid: Native FFT + Offline Waveform"),
                          const Divider(color: Colors.white12, height: 20),
                          _buildInfoTile("Target Render Framerate", "60 - 120 FPS (Impeller GPU Accelerated)"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 6. About Cinematic Music Player
                    _buildSectionHeader("ABOUT CINEMATIC MUSIC PLAYER"),
                    _buildAboutCard(context),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Account Card ---
  Widget _buildAccountCard(BuildContext context, UserModel? user, bool isLoggedIn, WidgetRef ref) {
    if (!isLoggedIn) {
      return CinematicGlassCard(
        padding: const EdgeInsets.all(18),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.person_outline_rounded, color: Colors.white70, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Offline Vault Mode",
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Running locally. Sign in to sync across Windows & Android.",
                        style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CinematicColors.electricViolet,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      );
                    },
                    child: const Text("Sign In or Create Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return CinematicGlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      borderColor: CinematicColors.electricViolet.withOpacity(0.35),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [CinematicColors.electricViolet, CinematicColors.deepPlum],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: CinematicColors.electricViolet, width: 2),
                ),
                child: Center(
                  child: Text(
                    user!.username.substring(0, 1).toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            user.username,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.greenAccent.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                          ),
                          child: const Text(
                            "SYNC ACTIVE",
                            style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Member since ${user.createdDate.year}-${user.createdDate.month.toString().padLeft(2, '0')}",
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent.withOpacity(0.85),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                ),
                onPressed: () async {
                  await ref.read(authProvider.notifier).logout();
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text("Log Out", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Cloud Sync Card ---
  Widget _buildSyncCard(BuildContext context, SyncManager syncMgr) {
    return CinematicGlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        syncMgr.isSyncing
                            ? Icons.sync_rounded
                            : (syncMgr.status == SyncStatus.error ? Icons.sync_problem_rounded : Icons.cloud_done_rounded),
                        color: syncMgr.status == SyncStatus.error
                            ? Colors.redAccent
                            : (syncMgr.isSyncing ? CinematicColors.neonCyan : Colors.greenAccent),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        syncMgr.isSyncing
                            ? "Syncing Vault..."
                            : (syncMgr.status == SyncStatus.error ? "Sync Error" : "Cloud Synchronized"),
                        style: TextStyle(
                          color: syncMgr.status == SyncStatus.error ? Colors.redAccent : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Last synchronized: ${_formatTimeAgo(syncMgr.lastSyncTime)}",
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: CinematicColors.electricViolet,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: syncMgr.isSyncing ? null : () => syncMgr.syncAll(force: true),
                icon: syncMgr.isSyncing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.sync_rounded, size: 16),
                label: Text(
                  syncMgr.isSyncing ? "Syncing" : "Sync Now",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            "Unified across devices: Playlists • Favorites • Recently Played • Audio Settings • Visualizer Presets",
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  // --- Connected Devices Card ---
  Widget _buildConnectedDevicesCard(BuildContext context, SyncManager syncMgr, WidgetRef ref) {
    final devices = syncMgr.connectedDevices;
    final currentDeviceId = SessionManager.instance.deviceId;

    return CinematicGlassCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "ACTIVE SESSIONS (${devices.length})",
                style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18, color: Colors.white54),
                onPressed: () => syncMgr.refreshConnectedDevices(),
                tooltip: "Refresh Devices",
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(
                    SessionManager.instance.getPlatform() == "windows"
                        ? Icons.desktop_windows_rounded
                        : Icons.phone_android_rounded,
                    color: CinematicColors.electricViolet,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "${SessionManager.instance.deviceName} (This Device)",
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text("CURRENT", style: TextStyle(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: devices.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white12, height: 16),
              itemBuilder: (context, index) {
                final d = devices[index];
                final isCurrent = d.deviceId == currentDeviceId;
                final isWindows = d.platform.toLowerCase() == "windows";

                return Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isCurrent ? CinematicColors.electricViolet : Colors.white).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isWindows ? Icons.desktop_windows_rounded : Icons.phone_android_rounded,
                        color: isCurrent ? CinematicColors.electricViolet : Colors.white70,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  d.deviceName,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrent) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.greenAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    "THIS DEVICE",
                                    style: TextStyle(color: Colors.greenAccent, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Synced ${_formatTimeAgo(d.lastSyncTime)} • v${d.appVersion}",
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white38, size: 18),
                      tooltip: "Remove Device",
                      onPressed: () => _showRemoveDeviceDialog(context, d, ref),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDropdownTile<T>({
    required String title,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        DropdownButton<T>(
          value: value,
          dropdownColor: CinematicColors.obsidianCard,
          underline: const SizedBox(),
          style: const TextStyle(color: CinematicColors.neonCyan, fontSize: 13),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return CinematicGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/icons/app_icon.png',
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56,
                    height: 56,
                    color: CinematicColors.electricViolet,
                    child: const Icon(Icons.graphic_eq_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Cinematic Music Player",
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Studio Edition • Release v${AppVersion.current}",
                      style: const TextStyle(color: CinematicColors.electricViolet, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Cross-Platform for Windows & Android",
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 14),
          Text(
            "Designed as a 100% private personal audio sanctuary. Features real-time GLSL 460 GPU audio-reactive shaders, synced LRC karaoke lyrics, and zero-compromise gapless fidelity.",
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "© 2026 Cinematic Audio Works",
                style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 11),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CinematicColors.electricViolet.withOpacity(0.25),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      side: BorderSide(color: CinematicColors.electricViolet.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => UpdateService.checkAndShowDialog(context, isManual: true),
                    icon: const Icon(Icons.system_update_rounded, size: 14),
                    label: const Text("Check Updates", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      showAboutDialog(
                        context: context,
                        applicationName: "Cinematic Music Player",
                        applicationVersion: "v${AppVersion.current}",
                        applicationIcon: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset('assets/icons/app_icon.png', width: 48, height: 48),
                        ),
                        children: [
                          const SizedBox(height: 12),
                          const Text(
                            "A private cross-platform cinematic music player built with Flutter, just_audio, audio_service, and custom GLSL 460 fragment shaders.\n\nEnjoy pure local audio playback across Windows and Android.",
                            style: TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ],
                      );
                    },
                    child: const Text("Licenses", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
