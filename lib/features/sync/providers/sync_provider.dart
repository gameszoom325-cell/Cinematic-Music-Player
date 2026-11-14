import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../sync/sync_manager.dart';

final syncProvider = ChangeNotifierProvider<SyncManager>((ref) {
  return SyncManager.instance;
});
