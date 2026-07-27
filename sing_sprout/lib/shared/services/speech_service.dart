import 'package:flutter/foundation.dart';
import 'dash_scope_service.dart';

/// Speech recognition via DashScope's Paraformer ASR.
///
/// Transcribes a pre-recorded WAV file — no microphone conflict
/// because the audio has already been captured by the time this runs.
class SpeechService {
  static final SpeechService _instance = SpeechService._();
  factory SpeechService() => _instance;
  SpeechService._();

  /// Whether speech recognition is available (DashScope key configured).
  Future<bool> get isAvailable => DashScopeService().isConfigured;

  /// Transcribe a WAV audio file. Returns the recognized text or null.
  ///
  /// The file is sent to DashScope's Paraformer ASR API after recording
  /// completes, so there is no conflict with the microphone.
  Future<String?> transcribe(String wavFilePath) async {
    debugPrint('[SpeechService] Transcribing: $wavFilePath');
    final text = await DashScopeService().transcribeFile(wavFilePath);
    if (text != null) {
      debugPrint('[SpeechService] Result: "$text"');
    }
    return text;
  }
}
