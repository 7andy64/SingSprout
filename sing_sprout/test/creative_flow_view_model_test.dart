import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mocktail/mocktail.dart';

import 'package:sing_sprout/features/humming_garden/view_models/creative_flow_view_model.dart';
import 'package:sing_sprout/core/constants/enums.dart';
import 'package:sing_sprout/shared/services/wav_synthesizer.dart' show ModulationParams;

class MockAudioPlayer extends Mock implements AudioPlayer {}

void main() {
  late MockAudioPlayer mockPlayer;
  late StreamController<Duration> positionController;
  late StreamController<Duration?> durationController;
  late StreamController<PlayerState> stateController;
  late StreamController<ProcessingState> processingController;

  setUp(() {
    mockPlayer = MockAudioPlayer();
    positionController = StreamController<Duration>.broadcast();
    durationController = StreamController<Duration?>.broadcast();
    stateController = StreamController<PlayerState>.broadcast();
    processingController = StreamController<ProcessingState>.broadcast();

    when(() => mockPlayer.positionStream)
        .thenAnswer((_) => positionController.stream);
    when(() => mockPlayer.durationStream)
        .thenAnswer((_) => durationController.stream);
    when(() => mockPlayer.playerStateStream)
        .thenAnswer((_) => stateController.stream);
    when(() => mockPlayer.processingStateStream)
        .thenAnswer((_) => processingController.stream);
    when(() => mockPlayer.pause()).thenAnswer((_) async {});
    when(() => mockPlayer.dispose()).thenAnswer((_) async {});
    when(() => mockPlayer.seek(any())).thenAnswer((_) async {});
    when(() => mockPlayer.setFilePath(any())).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await positionController.close();
    await durationController.close();
    await stateController.close();
    await processingController.close();
  });

  CreativeFlowViewModel createViewModel() {
    return CreativeFlowViewModel(player: mockPlayer);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Initial state
  // ═══════════════════════════════════════════════════════════════

  group('Initial state', () {
    test('defaults to idle stage', () {
      final vm = createViewModel();
      expect(vm.stage, CreativeFlowStage.idle);
      vm.dispose();
    });

    test('default style is morningDew', () {
      final vm = createViewModel();
      expect(vm.selectedStyle, StyleSeed.morningDew);
      vm.dispose();
    });

    test('no mood selected by default', () {
      final vm = createViewModel();
      expect(vm.selectedMood, isNull);
      vm.dispose();
    });

    test('default sliders at 0.5', () {
      final vm = createViewModel();
      expect(vm.temperature, 0.5);
      expect(vm.speed, 0.5);
      expect(vm.instrumentMix, 0.5);
      vm.dispose();
    });

    test('not playing initially', () {
      final vm = createViewModel();
      expect(vm.isPlaying, false);
      vm.dispose();
    });

    test('modParams starts neutral', () {
      final vm = createViewModel();
      expect(vm.modParams, ModulationParams.neutral);
      vm.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  formatTime — pure
  // ═══════════════════════════════════════════════════════════════

  group('formatTime', () {
    test('formats zero duration', () {
      final vm = createViewModel();
      expect(vm.formatTime(Duration.zero), '00:00');
      vm.dispose();
    });

    test('formats seconds only', () {
      final vm = createViewModel();
      expect(vm.formatTime(const Duration(seconds: 5)), '00:05');
      vm.dispose();
    });

    test('formats minutes and seconds', () {
      final vm = createViewModel();
      expect(vm.formatTime(const Duration(minutes: 3, seconds: 42)), '03:42');
      vm.dispose();
    });

    test('pads zeros correctly', () {
      final vm = createViewModel();
      expect(vm.formatTime(const Duration(minutes: 10, seconds: 7)), '10:07');
      vm.dispose();
    });

    test('formats over an hour', () {
      final vm = createViewModel();
      expect(vm.formatTime(const Duration(hours: 1, minutes: 15, seconds: 30)), '75:30');
      vm.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  styleAccentColor — mapping
  // ═══════════════════════════════════════════════════════════════

  group('styleAccentColor', () {
    test('morningDew → green', () {
      final vm = createViewModel();
      expect(vm.styleAccentColor(), const Color(0xFF7BC67E));
      vm.dispose();
    });

    test('mountainStream → blue', () {
      final vm = createViewModel();
      vm.selectStyle(StyleSeed.mountainStream);
      expect(vm.styleAccentColor(), const Color(0xFF4D96FF));
      vm.dispose();
    });

    test('frogDrum → orange', () {
      final vm = createViewModel();
      vm.selectStyle(StyleSeed.frogDrum);
      expect(vm.styleAccentColor(), const Color(0xFFFF8C42));
      vm.dispose();
    });

    test('random → purple', () {
      final vm = createViewModel();
      vm.selectStyle(StyleSeed.random);
      expect(vm.styleAccentColor(), const Color(0xFF9B59B6));
      vm.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  State setters
  // ═══════════════════════════════════════════════════════════════

  group('selectStyle', () {
    test('changes selectedStyle and notifies', () {
      final vm = createViewModel();
      var notified = false;
      vm.addListener(() => notified = true);

      vm.selectStyle(StyleSeed.mountainStream);
      expect(vm.selectedStyle, StyleSeed.mountainStream);
      expect(notified, isTrue);
      vm.dispose();
    });
  });

  group('selectMood', () {
    test('sets mood and notifies', () {
      final vm = createViewModel();
      var notified = false;
      vm.addListener(() => notified = true);

      vm.selectMood(MoodColor.green);
      expect(vm.selectedMood, MoodColor.green);
      expect(notified, isTrue);
      vm.dispose();
    });

    test('can set mood to null', () {
      final vm = createViewModel();
      vm.selectMood(MoodColor.red);
      vm.selectMood(null);
      expect(vm.selectedMood, isNull);
      vm.dispose();
    });
  });

  group('updateModulation', () {
    test('updates temperature and notifies', () {
      final vm = createViewModel();
      var notified = false;
      vm.addListener(() => notified = true);

      vm.updateModulation(temperature: 0.8);
      expect(vm.temperature, 0.8);
      expect(vm.speed, 0.5); // unchanged
      expect(notified, isTrue);
      vm.dispose();
    });

    test('updates speed and scales it for modParams', () {
      final vm = createViewModel();
      vm.updateModulation(speed: 0.3);
      expect(vm.speed, 0.3);
      // speed in modParams = speed * 1.5 + 0.5
      expect(vm.modParams.speed, closeTo(0.95, 0.01));
      vm.dispose();
    });

    test('updates instrumentMix', () {
      final vm = createViewModel();
      vm.updateModulation(instrumentMix: 0.7);
      expect(vm.instrumentMix, 0.7);
      expect(vm.modParams.instrumentMix, 0.7);
      vm.dispose();
    });

    test('updates multiple fields at once', () {
      final vm = createViewModel();
      vm.updateModulation(temperature: 0.2, speed: 0.8, instrumentMix: 0.6);
      expect(vm.temperature, 0.2);
      expect(vm.speed, 0.8);
      expect(vm.instrumentMix, 0.6);
      vm.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  Computed properties
  // ═══════════════════════════════════════════════════════════════

  group('computed properties', () {
    test('showLongPressHint is true during recording', () {
      final vm = createViewModel();
      vm.stage = CreativeFlowStage.recording;
      expect(vm.showLongPressHint, isTrue);
      vm.dispose();
    });

    test('showLongPressHint is false in other stages', () {
      final vm = createViewModel();
      for (final stage in CreativeFlowStage.values) {
        if (stage == CreativeFlowStage.recording) continue;
        vm.stage = stage;
        expect(vm.showLongPressHint, isFalse, reason: 'stage $stage');
      }
      vm.dispose();
    });

    test('showSilentGuide is false when amplitude is high', () {
      final vm = createViewModel();
      vm.smoothAmplitude = 0.5;
      vm.lastSoundTime = DateTime.now().subtract(const Duration(seconds: 3));
      expect(vm.showSilentGuide, isFalse);
      vm.dispose();
    });

    test('showSilentGuide is false within 2s of last sound even if amplitude low', () {
      final vm = createViewModel();
      vm.smoothAmplitude = 0.05;
      vm.lastSoundTime = DateTime.now();
      expect(vm.showSilentGuide, isFalse);
      vm.dispose();
    });

    test('elapsedRecordingSeconds is 0 when not recording', () {
      final vm = createViewModel();
      expect(vm.elapsedRecordingSeconds(), 0);
      vm.dispose();
    });

    test('recordingRingProgress is 0 when not started', () {
      final vm = createViewModel();
      expect(vm.recordingRingProgress(), 0.0);
      vm.dispose();
    });

    test('recordingRingProgress caps at 1.0', () {
      final vm = createViewModel();
      vm.recordingStartTime = DateTime.now().subtract(const Duration(seconds: 30));
      expect(vm.recordingRingProgress(), 1.0);
      vm.dispose();
    });

    test('silentSeconds returns 0 when lastSoundTime is null', () {
      final vm = createViewModel();
      expect(vm.silentSeconds(), 0);
      vm.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  elapsedString
  // ═══════════════════════════════════════════════════════════════

  group('elapsedString', () {
    test('formats 0 seconds', () {
      final vm = createViewModel();
      expect(vm.elapsedString(), '0:00');
      vm.dispose();
    });

    test('formats seconds with padding', () {
      final vm = createViewModel();
      vm.recordingStartTime = DateTime.now().subtract(const Duration(seconds: 7));
      expect(vm.elapsedString(), '0:07');
      vm.dispose();
    });

    test('formats minutes', () {
      final vm = createViewModel();
      vm.recordingStartTime = DateTime.now().subtract(const Duration(minutes: 2, seconds: 15));
      expect(vm.elapsedString(), '2:15');
      vm.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  Playback stream subscriptions
  // ═══════════════════════════════════════════════════════════════

  group('playback streams', () {
    test('positionStream updates playPosition', () async {
      final vm = createViewModel();
      positionController.add(const Duration(seconds: 10));

      // Allow microtask to process stream event
      await Future.delayed(Duration.zero);
      expect(vm.playPosition, const Duration(seconds: 10));
      vm.dispose();
    });

    test('durationStream updates playDuration', () async {
      final vm = createViewModel();
      durationController.add(const Duration(minutes: 3));

      await Future.delayed(Duration.zero);
      expect(vm.playDuration, const Duration(minutes: 3));
      vm.dispose();
    });

    test('durationStream handles null by using Duration.zero', () async {
      final vm = createViewModel();
      durationController.add(null);

      await Future.delayed(Duration.zero);
      expect(vm.playDuration, Duration.zero);
      vm.dispose();
    });

    test('playerStateStream updates isPlaying', () async {
      final vm = createViewModel();
      stateController.add(PlayerState(true, ProcessingState.ready));

      await Future.delayed(Duration.zero);
      expect(vm.isPlaying, true);

      stateController.add(PlayerState(false, ProcessingState.ready));

      await Future.delayed(Duration.zero);
      expect(vm.isPlaying, false);
      vm.dispose();
    });

    test('processingStateStream seeks to start and pauses on completed', () async {
      when(() => mockPlayer.seek(Duration.zero)).thenAnswer((_) async {});
      when(() => mockPlayer.pause()).thenAnswer((_) async {});

      final vm = createViewModel();
      processingController.add(ProcessingState.completed);

      await Future.delayed(Duration.zero);

      verify(() => mockPlayer.seek(Duration.zero)).called(1);
      verify(() => mockPlayer.pause()).called(1);
      vm.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  togglePlayPause (edge cases)
  // ═══════════════════════════════════════════════════════════════

  group('togglePlayPause', () {
    test('does nothing when generationResult is null', () async {
      final vm = createViewModel();
      await vm.togglePlayPause();
      // Should not throw, nothing to verify beyond no crash
      vm.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  triggerReRender guards
  // ═══════════════════════════════════════════════════════════════

  group('triggerReRender', () {
    test('does nothing when generationResult is null', () async {
      final vm = createViewModel();
      await vm.triggerReRender();
      expect(vm.isReRendering, false);
      vm.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════
  //  Dispose
  // ═══════════════════════════════════════════════════════════════

  group('dispose', () {
    test('disposes audio player', () {
      when(() => mockPlayer.dispose()).thenAnswer((_) async {});
      final vm = createViewModel();
      vm.dispose();
      verify(() => mockPlayer.dispose()).called(1);
    });
  });
}
