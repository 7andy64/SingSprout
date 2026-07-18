/// 本地音频服务 stub（web 预览模式）
class AudioService {
  static final AudioService _instance = AudioService._();
  factory AudioService() => _instance;
  AudioService._();

  bool _isRecording = false;
  bool _isPlaying = false;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;

  Future<bool> requestMicPermission() async => true;

  Future<String?> startRecording() async {
    _isRecording = true;
    return 'mock_recording.mp3';
  }

  Future<String?> stopRecording() async {
    _isRecording = false;
    return 'mock_recording.mp3';
  }

  Future<void> playAudio(String filePath) async {
    _isPlaying = true;
  }

  Future<void> stopPlayback() async {
    _isPlaying = false;
  }

  void dispose() {
    _isRecording = false;
    _isPlaying = false;
  }
}
