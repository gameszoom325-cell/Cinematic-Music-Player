import 'dart:async';
import 'package:flutter/foundation.dart';
import '../auth/session_manager.dart';
import '../auth/auth_service.dart';
import 'cloud_database.dart';
import 'sync_service.dart';

enum SyncStatus { idle, syncing, success, error }

/// Orchestrates background sync cycles, reactive notifications,
/// manual trigger requests, and multi-device management.
class SyncManager extends ChangeNotifier {
  SyncManager._internal();
  static final SyncManager instance = SyncManager._internal();

  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  DateTime? _lastSyncTime;
  List<DeviceModel> _connectedDevices = [];
  Timer? _periodicTimer;
  bool _isDisposed = false;

  SyncStatus get status => _status;
  bool get isSyncing => _status == SyncStatus.syncing;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime ?? SessionManager.instance.lastSyncTime;
  List<DeviceModel> get connectedDevices => List.unmodifiable(_connectedDevices);

  Future<void> init() async {
    await CloudDatabase.instance.init();
    _lastSyncTime = SessionManager.instance.lastSyncTime;

    // Refresh devices list if user is logged in
    final user = SessionManager.instance.currentUser;
    if (user != null && !user.isGuest) {
      await refreshConnectedDevices();
      // Trigger background sync on startup
      unawaited(syncAll());
    }

    // Schedule background periodic sync every 5 minutes
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      final u = SessionManager.instance.currentUser;
      if (u != null && !u.isGuest && _status != SyncStatus.syncing) {
        syncAll();
      }
    });
  }

  /// Manually or automatically trigger cloud synchronization
  Future<bool> syncAll({bool force = false}) async {
    final user = SessionManager.instance.currentUser;
    if (user == null || user.isGuest) {
      _status = SyncStatus.idle;
      _notify();
      return false;
    }

    if (_status == SyncStatus.syncing && !force) return false;

    _status = SyncStatus.syncing;
    _lastError = null;
    _notify();

    try {
      final success = await SyncService.instance.syncAll(user.userId);
      if (success) {
        _status = SyncStatus.success;
        _lastSyncTime = DateTime.now();
        await refreshConnectedDevices();
      } else {
        _status = SyncStatus.error;
        _lastError = "Could not sync with cloud vault";
      }
    } catch (e) {
      _status = SyncStatus.error;
      _lastError = e.toString();
    }

    _notify();

    // Reset status to idle after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (_status == SyncStatus.success) {
        _status = SyncStatus.idle;
        _notify();
      }
    });

    return _status == SyncStatus.success;
  }

  /// Refresh the list of all connected devices for this account
  Future<void> refreshConnectedDevices() async {
    final user = SessionManager.instance.currentUser;
    if (user == null || user.isGuest) {
      _connectedDevices = [];
      _notify();
      return;
    }

    try {
      _connectedDevices = await CloudDatabase.instance.getConnectedDevices(
        user.userId,
        currentDeviceId: SessionManager.instance.deviceId,
      );
      _notify();
    } catch (e) {
      debugPrint("Error refreshing connected devices: $e");
    }
  }

  /// Remove a connected device from the account
  Future<bool> removeDevice(String deviceId) async {
    final user = SessionManager.instance.currentUser;
    if (user == null || user.isGuest) return false;

    try {
      final removed = await CloudDatabase.instance.removeDevice(user.userId, deviceId);
      if (removed) {
        // If the removed device is THIS device, logout locally
        if (deviceId == SessionManager.instance.deviceId) {
          await AuthService.instance.logout();
        } else {
          await refreshConnectedDevices();
        }
        return true;
      }
    } catch (e) {
      debugPrint("Error removing device: $e");
    }
    return false;
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _periodicTimer?.cancel();
    super.dispose();
  }
}
