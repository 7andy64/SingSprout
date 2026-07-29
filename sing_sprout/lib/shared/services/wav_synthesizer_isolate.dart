import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import '../../core/constants/enums.dart';
import 'arrangement_engine.dart';
import 'audio_processor.dart';
import 'wav_synthesizer.dart';

/// Runs WAV synthesis in a background isolate so the UI thread stays responsive
/// on low-end Android devices.
///
/// The static [WavSynthesizer.render] / [WavSynthesizer.renderModulatedSamples]
/// are pure CPU work (no I/O, no platform channels) so they can be freely moved
/// into any isolate.
class WavSynthesizerIsolate {
  /// Render a full arrangement to a WAV file via an isolate.
  ///
  /// [timeout] defaults to 30 s — generous enough for a 60 s piece at 22050 Hz
  /// on a slow device, but prevents a hung isolate from blocking the user
  /// forever.
  static Future<String> renderToFile({
    required Arrangement arrangement,
    required StyleSeed style,
    required String outputPath,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final buffer = await _runInIsolate(
      arrangement: arrangement,
      style: style,
      timeout: timeout,
    );
    await AudioProcessor.writeWav(outputPath, buffer, WavSynthesizer.sampleRate);
    return outputPath;
  }

  /// Render modulated arrangement to a WAV file via an isolate.
  static Future<String> renderModulated({
    required Arrangement baseArrangement,
    required List<MidiNoteEvent> melody,
    required StyleSeed style,
    required ModulationParams params,
    required String outputPath,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final buffer = await _runModulatedInIsolate(
      baseArrangement: baseArrangement,
      melody: melody,
      style: style,
      params: params,
      timeout: timeout,
    );
    await AudioProcessor.writeWav(outputPath, buffer, WavSynthesizer.sampleRate);
    return outputPath;
  }

  /// Render to raw samples (no file I/O in the isolate — I/O stays on main).
  static Future<Float64List> render({
    required Arrangement arrangement,
    required StyleSeed style,
    Duration timeout = const Duration(seconds: 30),
  }) {
    return _runInIsolate(
      arrangement: arrangement,
      style: style,
      timeout: timeout,
    );
  }

  // ── Isolate plumbing (standard render) ──

  static Future<Float64List> _runInIsolate({
    required Arrangement arrangement,
    required StyleSeed style,
    required Duration timeout,
  }) async {
    final receivePort = ReceivePort();
    final completer = Completer<Float64List>();
    Isolate? isolate;
    Timer? timer;

    try {
      isolate = await Isolate.spawn(
        _isolateEntry,
        _IsolateRequest(receivePort.sendPort, arrangement.toMap(), style.index),
        errorsAreFatal: true,
        onExit: receivePort.sendPort,
        onError: receivePort.sendPort,
      );

      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          isolate?.kill(priority: Isolate.immediate);
          completer.completeError(
            TimeoutException('WAV合成超时 (${timeout.inSeconds}s)'),
          );
        }
      });

      receivePort.listen((msg) {
        if (completer.isCompleted) return;
        if (msg is TransferableTypedData) {
          final data = msg.materialize();
          completer.complete(data.asFloat64List(
            0,
            data.lengthInBytes ~/ 8,
          ));
        } else if (msg is List && msg.length == 2) {
          completer.completeError(
            Exception('Isolate合成失败: ${msg[0]}'),
            StackTrace.fromString(msg[1].toString()),
          );
        } else if (msg == null) {
          if (!completer.isCompleted) {
            completer.completeError(StateError('Isolate意外终止'));
          }
        }
      });

      return await completer.future;
    } finally {
      timer?.cancel();
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  // ── Isolate plumbing (modulated render) ──

  static Future<Float64List> _runModulatedInIsolate({
    required Arrangement baseArrangement,
    required List<MidiNoteEvent> melody,
    required StyleSeed style,
    required ModulationParams params,
    required Duration timeout,
  }) async {
    final receivePort = ReceivePort();
    final completer = Completer<Float64List>();
    Isolate? isolate;
    Timer? timer;

    try {
      isolate = await Isolate.spawn(
        _isolateEntryModulated,
        _IsolateModulatedRequest(
          receivePort.sendPort,
          baseArrangement.toMap(),
          melody.map((e) => e.toMap()).toList(),
          style.index,
          params.temperature,
          params.speed,
          params.instrumentMix,
        ),
        errorsAreFatal: true,
        onExit: receivePort.sendPort,
        onError: receivePort.sendPort,
      );

      timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          isolate?.kill(priority: Isolate.immediate);
          completer.completeError(
            TimeoutException('WAV合成超时 (${timeout.inSeconds}s)'),
          );
        }
      });

      receivePort.listen((msg) {
        if (completer.isCompleted) return;
        if (msg is TransferableTypedData) {
          final data = msg.materialize();
          completer.complete(data.asFloat64List(
            0,
            data.lengthInBytes ~/ 8,
          ));
        } else if (msg is List && msg.length == 2) {
          completer.completeError(
            Exception('Isolate合成失败: ${msg[0]}'),
            StackTrace.fromString(msg[1].toString()),
          );
        } else if (msg == null) {
          if (!completer.isCompleted) {
            completer.completeError(StateError('Isolate意外终止'));
          }
        }
      });

      return await completer.future;
    } finally {
      timer?.cancel();
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  /// Top-level entry point — must be static or top-level for Isolate.spawn.
  static void _isolateEntry(_IsolateRequest req) {
    try {
      final arrangement = Arrangement.fromMap(req.arrangementMap);
      final style = StyleSeed.values[req.styleIndex];
      final buffer = WavSynthesizer.render(
        melody: arrangement.melody,
        chords: arrangement.chords,
        bass: arrangement.bass,
        percussion: arrangement.percussion,
        style: style,
        totalDuration: arrangement.totalDurationSeconds,
      );
      final transferable = TransferableTypedData.fromList([buffer.buffer.asByteData()]);
      req.sendPort.send(transferable);
    } catch (e, st) {
      req.sendPort.send([e.toString(), st.toString()]);
    }
  }

  /// Modulated isolate entry point.
  static void _isolateEntryModulated(_IsolateModulatedRequest req) {
    try {
      final arrangement = Arrangement.fromMap(req.arrangementMap);
      final style = StyleSeed.values[req.styleIndex];
      final melody = req.melodyMaps.map((e) => MidiNoteEvent.fromMap(e)).toList();
      final params = ModulationParams(
        temperature: req.temperature,
        speed: req.speed,
        instrumentMix: req.instrumentMix,
      );
      final buffer = WavSynthesizer.renderModulatedSamples(
        baseArrangement: arrangement,
        melody: melody,
        style: style,
        params: params,
      );
      final transferable = TransferableTypedData.fromList([buffer.buffer.asByteData()]);
      req.sendPort.send(transferable);
    } catch (e, st) {
      req.sendPort.send([e.toString(), st.toString()]);
    }
  }
}

class _IsolateRequest {
  final SendPort sendPort;
  final Map<String, dynamic> arrangementMap;
  final int styleIndex;
  const _IsolateRequest(this.sendPort, this.arrangementMap, this.styleIndex);
}

class _IsolateModulatedRequest {
  final SendPort sendPort;
  final Map<String, dynamic> arrangementMap;
  final List<Map<String, dynamic>> melodyMaps;
  final int styleIndex;
  final double temperature;
  final double speed;
  final double instrumentMix;
  const _IsolateModulatedRequest(
    this.sendPort, this.arrangementMap, this.melodyMaps, this.styleIndex,
    this.temperature, this.speed, this.instrumentMix,
  );
}
