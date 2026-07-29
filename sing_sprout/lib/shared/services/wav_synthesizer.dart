import 'dart:math';
import 'dart:typed_data';
import '../../core/constants/enums.dart';
import 'arrangement_engine.dart';
import 'audio_processor.dart';

/// Real-time modulation parameters for the editor controls.
///
/// temperature (0-1): warmth — higher = longer releases, softer tone
/// speed (0.5-2.0): tempo multiplier
/// instrumentMix (0-1): 0 = melody only, 1 = full band balance
class ModulationParams {
  final double temperature;
  final double speed;
  final double instrumentMix;

  const ModulationParams({
    this.temperature = 0.5,
    this.speed = 1.0,
    this.instrumentMix = 0.5,
  });

  static const neutral = ModulationParams();
}

/// Renders multi-track MIDI arrangements to WAV audio via waveform synthesis.
///
/// Pure Dart, 0MB model. Generates 16-bit 44100Hz mono WAV.
class WavSynthesizer {
  /// Output sample rate. 22050Hz is enough for children's humming music
  /// (Nyquist = 11025Hz, highest melody ~1047Hz at C6).
  /// Halves file size vs 44100Hz with negligible quality loss.
  static const sampleRate = 22050;

  // ── Public API ──

  /// Render modulated samples (CPU-only, no I/O). Suitable for isolate offloading.
  static Float64List renderModulatedSamples({
    required Arrangement baseArrangement,
    required List<MidiNoteEvent> melody,
    required StyleSeed style,
    required ModulationParams params,
  }) {
    List<MidiNoteEvent> chords, bass, percussion;
    double totalDuration;
    final speedFactor = 1.0 / params.speed;
    if ((params.speed - 1.0).abs() > 0.01) {
      chords = _scaleTiming(baseArrangement.chords, speedFactor);
      bass = _scaleTiming(baseArrangement.bass, speedFactor);
      percussion = _scaleTiming(baseArrangement.percussion, speedFactor);
      totalDuration = baseArrangement.totalDurationSeconds * speedFactor;
    } else {
      chords = baseArrangement.chords;
      bass = baseArrangement.bass;
      percussion = baseArrangement.percussion;
      totalDuration = baseArrangement.totalDurationSeconds;
    }

    final warmth = params.temperature;
    final melodyAdsr = _interpolateAdsr(_AdsrPreset.melody, warmth);
    final chordAdsr = style == StyleSeed.mountainStream
        ? _interpolateAdsr(_AdsrPreset.pad, warmth)
        : _interpolateAdsr(_AdsrPreset.chord, warmth);
    final bassAdsr = _interpolateAdsr(_AdsrPreset.bass, warmth);

    final mix = params.instrumentMix;
    final melodyGain = 0.75 - (mix - 0.5) * 0.15;
    final chordBaseGain = style == StyleSeed.mountainStream ? 0.18 : 0.35;
    final chordGain = chordBaseGain * (mix * 2).clamp(0.1, 1.0);
    final bassGain = 0.55 * (mix * 2).clamp(0.1, 1.0);
    final percGain = mix.clamp(0.0, 1.0);

    final chordWave = style == StyleSeed.frogDrum ? _WaveType.triangle : _WaveType.sine;

    final numSamples = (sampleRate * totalDuration).ceil();
    final buffer = Float64List(numSamples);

    _renderTrack(buffer, bass, bassAdsr, _WaveType.sine, gain: bassGain);
    _renderTrack(buffer, chords, chordAdsr, chordWave, gain: chordGain);
    if (percussion.isNotEmpty && percGain > 0.05) {
      _renderPercussion(buffer, percussion, seed: _percussionSeed(melody));
    }
    _renderTrack(buffer, melody, melodyAdsr, _WaveType.sine, gain: melodyGain);

    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = tanh(buffer[i] * 1.3) * 0.85;
    }

    return buffer;
  }

  /// Render with modulation params applied and write to file.
  static Future<String> renderModulated({
    required Arrangement baseArrangement,
    required List<MidiNoteEvent> melody,
    required StyleSeed style,
    required ModulationParams params,
    required String outputPath,
  }) async {
    final buffer = renderModulatedSamples(
      baseArrangement: baseArrangement,
      melody: melody,
      style: style,
      params: params,
    );
    await AudioProcessor.writeWav(outputPath, buffer, sampleRate);
    return outputPath;
  }

  /// Standard render without modulation.
  static Float64List render({
    required List<MidiNoteEvent> melody,
    required List<MidiNoteEvent> chords,
    required List<MidiNoteEvent> bass,
    required List<MidiNoteEvent> percussion,
    required StyleSeed style,
    required double totalDuration,
  }) {
    final numSamples = (sampleRate * totalDuration).ceil();
    final buffer = Float64List(numSamples);

    _renderTrack(buffer, bass, _AdsrPreset.bass, _WaveType.sine, gain: 0.55);

    final chordGain = style == StyleSeed.mountainStream ? 0.18 : 0.35;
    final chordAdsr = style == StyleSeed.mountainStream ? _AdsrPreset.pad : _AdsrPreset.chord;
    final chordWave = style == StyleSeed.frogDrum ? _WaveType.triangle : _WaveType.sine;
    _renderTrack(buffer, chords, chordAdsr, chordWave, gain: chordGain);

    if (percussion.isNotEmpty) {
      _renderPercussion(buffer, percussion, seed: _percussionSeed(melody));
    }

    _renderTrack(buffer, melody, _AdsrPreset.melody, _WaveType.sine, gain: 0.75);

    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = tanh(buffer[i] * 1.3) * 0.85;
    }

    return buffer;
  }

  /// Render to WAV file (no modulation).
  static Future<String> renderToFile({
    required dynamic arrangementOrNotes,
    required StyleSeed style,
    required String outputPath,
    double? totalDuration,
  }) async {
    Float64List samples;
    if (arrangementOrNotes is Arrangement) {
      samples = render(
        melody: arrangementOrNotes.melody,
        chords: arrangementOrNotes.chords,
        bass: arrangementOrNotes.bass,
        percussion: arrangementOrNotes.percussion,
        style: style,
        totalDuration: totalDuration ?? arrangementOrNotes.totalDurationSeconds,
      );
    } else {
      final notes = <MidiNoteEvent>[];
      final dur = totalDuration ?? 3.0;
      final noteLen = dur / 3;
      for (var i = 0; i < 3; i++) {
        notes.add(MidiNoteEvent(noteNumber: 60 + i * 2, startSeconds: i * noteLen, durationSeconds: noteLen * 0.85));
      }
      final arr = Arrangement(melody: notes, chords: [], bass: [], percussion: [], tempoBpm: 80, tonicMidi: 60, totalDurationSeconds: dur);
      samples = render(melody: arr.melody, chords: arr.chords, bass: arr.bass, percussion: arr.percussion, style: style, totalDuration: dur);
    }
    await AudioProcessor.writeWav(outputPath, samples, sampleRate);
    return outputPath;
  }

  // ── Speed scaling ──

  /// Scale start and duration of every note by [factor].
  static List<MidiNoteEvent> _scaleTiming(List<MidiNoteEvent> notes, double factor) {
    return notes.map((n) => MidiNoteEvent(
      noteNumber: n.noteNumber,
      startSeconds: n.startSeconds * factor,
      durationSeconds: n.durationSeconds * factor,
      velocity: n.velocity,
    )).toList();
  }

  // ── ADSR interpolation (temperature → warmth) ──

  /// temperature 0=cold(staccato) → 1=warm(legato, long release)
  static _AdsrPreset _interpolateAdsr(_AdsrPreset base, double warmth) {
    // warm = longer attack, longer release, slightly higher sustain
    return _AdsrPreset(
      base.attack + warmth * 0.04,    // 0.02→0.06 for melody
      base.decay + warmth * 0.03,
      (base.sustain + warmth * 0.1).clamp(0.2, 0.85),
      base.release + warmth * 0.25,   // 0.12→0.37 for melody
    );
  }

  // ── Track Rendering ──

  static void _renderTrack(Float64List buffer, List<MidiNoteEvent> notes, _AdsrPreset adsr, _WaveType wave, {double gain = 0.5}) {
    for (final note in notes) {
      if (note.noteNumber < 0 || note.noteNumber > 127) continue;
      final freq = _midiToFreq(note.noteNumber);
      final startSample = (note.startSeconds * sampleRate).round().clamp(0, buffer.length - 1);
      final durationSamples = (note.durationSeconds * sampleRate).round();
      final endSample = (startSample + durationSamples).clamp(0, buffer.length);
      for (var i = startSample; i < endSample; i++) {
        final t = (i - startSample) / sampleRate;
        final env = _adsrEnvelope(t, note.durationSeconds, adsr);
        if (env <= 1e-6) continue;
        buffer[i] += _waveSample(freq, t, wave) * env * gain * note.velocity;
      }
    }
  }

  // ── Percussion ──

  static int _percussionSeed(List<MidiNoteEvent> melody) {
    var h = 0;
    for (final n in melody) {
      h = (h * 31 + n.noteNumber) & 0x7FFFFFFF;
    }
    return h == 0 ? 42 : h;
  }

  static void _renderPercussion(Float64List buffer, List<MidiNoteEvent> notes, {int seed = 42}) {
    final rng = Random(seed);
    for (final note in notes) {
      final startSample = (note.startSeconds * sampleRate).round().clamp(0, buffer.length - 1);
      final endSample = (startSample + (note.durationSeconds * sampleRate).round()).clamp(0, buffer.length);
      switch (note.noteNumber) {
        case 36: _renderKick(buffer, startSample, endSample, note.velocity); break;
        case 38: _renderSnare(buffer, startSample, endSample, note.velocity, rng); break;
        case 42: _renderHihat(buffer, startSample, endSample, note.velocity, rng); break;
      }
    }
  }

  static void _renderKick(Float64List b, int s, int e, double v) {
    for (var i = s; i < e; i++) {
      final t = (i - s) / sampleRate;
      b[i] += sin(2 * pi * (150 - t * 800).clamp(40, 200) * t) * exp(-t * 25) * 0.8 * v;
    }
  }

  static void _renderSnare(Float64List b, int s, int e, double v, Random r) {
    for (var i = s; i < e; i++) {
      final t = (i - s) / sampleRate;
      final env = exp(-t * 35);
      b[i] += ((r.nextDouble() * 2 - 1) * 0.5 + sin(2 * pi * 200 * t) * 0.5) * env * 0.7 * v;
    }
  }

  static void _renderHihat(Float64List b, int s, int e, double v, Random r) {
    var prev = 0.0;
    for (var i = s; i < e; i++) {
      final t = (i - s) / sampleRate;
      final raw = (r.nextDouble() * 2 - 1);
      b[i] += ((raw - prev) * 0.5) * exp(-t * 60) * 0.45 * v;
      prev = raw;
    }
  }

  // ── Waveforms ──

  static double _waveSample(double freq, double t, _WaveType type) {
    final phase = freq * t;
    switch (type) {
      case _WaveType.sine: return sin(2 * pi * phase);
      case _WaveType.triangle:
        final p = phase - phase.floor();
        return p < 0.25 ? 4 * p : p < 0.75 ? 2 - 4 * p : 4 * p - 4;
      case _WaveType.saw: return 2 * (phase - phase.floor()) - 1;
      case _WaveType.square: return sin(2 * pi * phase) >= 0 ? 1.0 : -1.0;
    }
  }

  // ── ADSR ──

  static double _adsrEnvelope(double t, double noteDuration, _AdsrPreset preset) {
    if (t < 0) return 0;
    if (t < preset.attack) return t / preset.attack;
    final aEnd = preset.attack + preset.decay;
    if (t < aEnd) return 1.0 - (1.0 - preset.sustain) * ((t - preset.attack) / preset.decay);
    final releaseStart = noteDuration - preset.release;
    if (t < releaseStart) return preset.sustain;
    if (t < noteDuration) return preset.sustain * (1.0 - (t - releaseStart) / preset.release);
    return 0;
  }

  // ── Utils ──

  static double _midiToFreq(int midi) => 440.0 * pow(2.0, (midi - 69) / 12.0);

  static double tanh(double x) {
    final x2 = x * x;
    return x * (27 + x2) / (27 + 9 * x2);
  }
}

// ── Internal types ──

enum _WaveType { sine, triangle, saw, square }

class _AdsrPreset {
  final double attack, decay, sustain, release;
  const _AdsrPreset(this.attack, this.decay, this.sustain, this.release);

  static const melody = _AdsrPreset(0.02, 0.05, 0.70, 0.12);
  static const chord  = _AdsrPreset(0.01, 0.04, 0.50, 0.10);
  static const pad    = _AdsrPreset(0.10, 0.15, 0.55, 0.60);
  static const bass   = _AdsrPreset(0.015, 0.05, 0.70, 0.15);
}
