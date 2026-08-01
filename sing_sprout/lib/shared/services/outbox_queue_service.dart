import '../models/voice_card.dart';
import '../services/api_service.dart';
import '../services/local_storage_service.dart';
import 'oss_upload_service.dart';

/// Offline outbox queue — caches postcards when offline, auto-sends when online.
class OutboxQueueService {
  static final OutboxQueueService _instance = OutboxQueueService._();
  factory OutboxQueueService() => _instance;
  OutboxQueueService._();

  static const _filename = 'pending_outbox.json';
  final _storage = LocalStorageService();

  /// Add a card to the send queue.
  Future<void> enqueue(VoiceCard card) async {
    final list = await _storage.readList(_filename);
    list.add(card.toJson());
    await _storage.writeList(_filename, list);
  }

  /// Process all pending postcards in the queue.
  Future<void> processQueue({required String deviceId}) async {
    final list = await _storage.readList(_filename);
    if (list.isEmpty) return;

    final api = ApiService();
    final uploader = OSSUploadService();
    final remaining = <Map<String, dynamic>>[];

    for (final item in list) {
      try {
        final card = VoiceCard.fromJson(item);

        // 1. Upload audio to OSS
        final audioPath = card.audioPath;
        if (audioPath == null || audioPath.isEmpty) {
          remaining.add(item);
          continue;
        }
        final ossKey = await uploader.upload(
          filePath: audioPath,
          cardId: card.id,
        );
        if (ossKey == null) {
          remaining.add(item);
          continue;
        }

        // 2. Generate share link via backend
        await api.generateShareLink(
          cardId: card.id,
          deviceId: deviceId,
          audioOssKey: ossKey,
          coverOssKey: card.coverUrl,
          textContent: card.textContent,
        );
      } catch (_) {
        remaining.add(item);
      }
    }

    await _storage.writeList(_filename, remaining);
  }

  /// Number of pending cards.
  Future<int> get pendingCount async {
    final list = await _storage.readList(_filename);
    return list.length;
  }
}
