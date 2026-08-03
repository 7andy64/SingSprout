import 'package:flutter_test/flutter_test.dart';
import 'package:sing_sprout/shared/models/ai_music_models.dart';
import 'package:sing_sprout/shared/services/ai_music_service.dart';

void main() {
  group('AiGameNote', () {
    test('fromJson and toJson roundtrip', () {
      final original = AiGameNote(
        pitch: 64,
        startTime: 1.5,
        duration: 0.5,
        isPercussion: false,
      );
      final json = original.toJson();
      final restored = AiGameNote.fromJson(json);
      expect(restored.pitch, 64);
      expect(restored.startTime, 1.5);
      expect(restored.duration, 0.5);
      expect(restored.isPercussion, false);
    });

    test('percussion note fromJson', () {
      final json = {
        'pitch': 36,
        'startTime': 0.0,
        'duration': 0.1,
        'isPercussion': true,
        'percussionType': 'kick',
      };
      final note = AiGameNote.fromJson(json);
      expect(note.isPercussion, true);
      expect(note.percussionType, 'kick');
    });

    test('defaults isPercussion to false', () {
      final note = AiGameNote.fromJson({
        'pitch': 60,
        'startTime': 0.0,
        'duration': 0.5,
      });
      expect(note.isPercussion, false);
      expect(note.percussionType, null);
    });
  });

  group('AiMusicStyle', () {
    test('all styles have label and emoji', () {
      for (final style in AiMusicStyle.values) {
        expect(style.label, isNotEmpty);
        expect(style.emoji, isNotEmpty);
      }
    });

    test('labels are all unique', () {
      final labels = AiMusicStyle.values.map((s) => s.label).toSet();
      expect(labels.length, AiMusicStyle.values.length);
    });

    test('emojis are all unique', () {
      final emojis = AiMusicStyle.values.map((s) => s.emoji).toSet();
      expect(emojis.length, AiMusicStyle.values.length);
    });

    test('has exactly 4 styles', () {
      expect(AiMusicStyle.values.length, 4);
    });
  });

  group('pitchToTrack', () {
    test('maps low pitch to track 0', () {
      expect(AiMusicService.pitchToTrack(55, 3), 0);
      expect(AiMusicService.pitchToTrack(60, 3), 0);
    });

    test('maps mid pitch to track 1', () {
      expect(AiMusicService.pitchToTrack(65, 3), 1);
      expect(AiMusicService.pitchToTrack(70, 3), 1);
    });

    test('maps high pitch to track 2', () {
      expect(AiMusicService.pitchToTrack(75, 3), 2);
      expect(AiMusicService.pitchToTrack(84, 3), 2);
    });

    test('adapts to track count', () {
      // 2 tracks
      expect(AiMusicService.pitchToTrack(60, 2), 0);
      expect(AiMusicService.pitchToTrack(75, 2), 1);
      // 4 tracks
      expect(AiMusicService.pitchToTrack(55, 4), 0);
      expect(AiMusicService.pitchToTrack(62, 4), 0);
      expect(AiMusicService.pitchToTrack(70, 4), 2);
      expect(AiMusicService.pitchToTrack(84, 4), 3);
    });

    test('clamps output to valid range', () {
      expect(AiMusicService.pitchToTrack(0, 3), 0);
      expect(AiMusicService.pitchToTrack(127, 3), 2);
    });

    test('single track always returns 0', () {
      expect(AiMusicService.pitchToTrack(60, 1), 0);
      expect(AiMusicService.pitchToTrack(84, 1), 0);
    });
  });

  group('AiMusicResult', () {
    test('creates with required fields', () {
      final result = AiMusicResult(
        wavPath: '/tmp/test.wav',
        notes: [],
        tempo: 100,
        mood: '测试',
      );
      expect(result.wavPath, '/tmp/test.wav');
      expect(result.notes, isEmpty);
      expect(result.tempo, 100);
      expect(result.mood, '测试');
      expect(result.totalDurationSeconds, 30);
    });

    test('custom total duration', () {
      final result = AiMusicResult(
        wavPath: '/tmp/test.wav',
        notes: [],
        tempo: 100,
        mood: '测试',
        totalDurationSeconds: 60,
      );
      expect(result.totalDurationSeconds, 60);
    });
  });
}
