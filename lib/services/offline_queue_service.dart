import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

class OfflineQueueService {
  OfflineQueueService({Connectivity? connectivity, Uuid? uuid})
    : _connectivity = connectivity ?? Connectivity(),
      _uuid = uuid ?? const Uuid();

  static const boxName = 'offline_message_queue';

  final Connectivity _connectivity;
  final Uuid _uuid;

  Future<Box> get _box async => Hive.openBox(boxName);

  Stream<bool> get onlineChanges {
    return _connectivity.onConnectivityChanged.map(_hasConnection).distinct();
  }

  Future<bool> get isOnline async {
    return _hasConnection(await _connectivity.checkConnectivity());
  }

  Future<String> enqueue(Map<String, dynamic> payload) async {
    final box = await _box;
    final localId = (payload['localId'] as String?) ?? _uuid.v4();
    await box.put(localId, {
      ...payload,
      'localId': localId,
      'queuedAt': DateTime.now().toIso8601String(),
      'retryCount': (payload['retryCount'] as int?) ?? 0,
    });
    return localId;
  }

  Future<List<Map<String, dynamic>>> queuedForConversation(
    String conversationId,
  ) async {
    final box = await _box;
    return box.values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((value) => value['conversationId'] == conversationId)
        .toList()
      ..sort((a, b) => '${a['queuedAt']}'.compareTo('${b['queuedAt']}'));
  }

  Future<void> remove(String localId) async {
    final box = await _box;
    await box.delete(localId);
  }

  Future<void> incrementRetry(String localId) async {
    final box = await _box;
    final value = box.get(localId);
    if (value is! Map) {
      return;
    }
    final payload = Map<String, dynamic>.from(value);
    payload['retryCount'] = ((payload['retryCount'] as num?)?.toInt() ?? 0) + 1;
    await box.put(localId, payload);
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }
}
