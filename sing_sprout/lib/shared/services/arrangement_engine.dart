import 'dart:math';
import '../../core/constants/enums.dart';
import 'audio_processor.dart';
import 'dash_scope_service.dart';

/// Multi-track arrangement produced by the rule engine.
class Arrangement {
  final List<MidiNoteEvent> melody;
  final List<MidiNoteEvent> chords;
  final List<MidiNoteEvent> bass;
  final List<MidiNoteEvent> percussion; // empty for non-rhythmic styles
  final double tempoBpm;
  final int tonicMidi;
  final double totalDurationSeconds;

  const Arrangement({
    required this.melody,
    required this.chords,
    required this.bass,
    required this.percussion,
    required this.tempoBpm,
    required this.tonicMidi,
    required this.totalDurationSeconds,
  });

  List<MidiNoteEvent> get allNotes => [...melody, ...chords, ...bass, ...percussion];
}

/// Rule-based arrangement engine (0MB model).
///
/// Two modes:
/// 1. AI-driven — `arrangeFromAiScore()` converts AI's per-bar score
///    directly to note events. No templates. AI controls every note.
/// 2. Pure rule — `arrange()` uses music-theory templates for offline mode.
class ArrangementEngine {

  // ── AI Score → Arrangement (no templates) ──

  /// Convert AI-written per-bar score directly to a playable arrangement.
  /// No templates or rule-based filling — the AI controls every note.
  ///
  /// If [score] includes melody fields, those replace the [melody] parameter
  /// (speech mode — AI composed the melody too).
  static Arrangement arrangeFromAiScore({
    required List<MidiNoteEvent> melody,
    required AiFullScore score,
    required int tonicMidi,
    double? durationOverride,
  }) {
    final beatDuration = 60.0 / score.tempoBpm;
    final barDuration = beatDuration * 4.0;

    // Use AI-composed melody if available
    List<MidiNoteEvent> finalMelody;
    if (score.melody != null && score.melody!.isNotEmpty && score.melodyRhythm != null) {
      finalMelody = _aiMelodyToEvents(score, beatDuration);
    } else {
      finalMelody = melody;
    }

    final totalDuration = durationOverride ??
        (finalMelody.isNotEmpty
            ? (finalMelody.map((n) => n.startSeconds + n.durationSeconds).reduce(max) + 1.0).clamp(3.0, 30.0)
            : score.bars.length * barDuration);

    final chordNotes = <MidiNoteEvent>[];
    final bassNotes = <MidiNoteEvent>[];
    final percNotes = <MidiNoteEvent>[];

    for (var i = 0; i < score.bars.length; i++) {
      final bar = score.bars[i];
      final barStart = i * barDuration;
      if (barStart >= totalDuration) break;

      final dyn = bar.dynamic_;

      // ── Chords: AI wrote voicing + rhythm ──
      if (bar.chord.isNotEmpty && bar.chordRhythm.isNotEmpty) {
        var chordTime = barStart;
        for (final dur in bar.chordRhythm) {
          if (chordTime >= totalDuration) break;
          // Cycle through chord notes for arpeggiation variety
          final noteIdx = ((chordTime - barStart) / beatDuration * bar.chord.length).round() % bar.chord.length;
          final midi = bar.chord[noteIdx % bar.chord.length];
          chordNotes.add(MidiNoteEvent(
            noteNumber: midi,
            startSeconds: chordTime,
            durationSeconds: (dur * beatDuration * 0.9).clamp(0.05, barDuration),
            velocity: (0.35 * dyn).clamp(0.15, 0.6),
          ));
          chordTime += dur * beatDuration;
        }
      }

      // ── Bass: AI wrote notes + rhythm ──
      if (bar.bass.isNotEmpty && bar.bassRhythm.isNotEmpty) {
        var bassTime = barStart;
        for (var j = 0; j < bar.bass.length && j < bar.bassRhythm.length; j++) {
          if (bassTime >= totalDuration) break;
          bassNotes.add(MidiNoteEvent(
            noteNumber: bar.bass[j].clamp(28, 72),
            startSeconds: bassTime,
            durationSeconds: (bar.bassRhythm[j] * beatDuration * 0.85).clamp(0.05, barDuration),
            velocity: (0.5 * dyn).clamp(0.25, 0.7),
          ));
          bassTime += bar.bassRhythm[j] * beatDuration;
        }
      }

      // ── Percussion: AI wrote per-8th-note pattern ──
      if (bar.percussion.isNotEmpty) {
        final eighthDuration = beatDuration * 0.5;
        for (var j = 0; j < bar.percussion.length; j++) {
          final hitTime = barStart + j * eighthDuration;
          if (hitTime >= totalDuration) break;
          final hit = bar.percussion[j];
          if (hit == null || hit.isEmpty) continue;

          final vel = (0.6 * dyn).clamp(0.3, 0.8);
          if (hit.contains('kick')) {
            percNotes.add(MidiNoteEvent(
              noteNumber: _kick, startSeconds: hitTime,
              durationSeconds: 0.1, velocity: vel,
            ));
          }
          if (hit.contains('snare')) {
            percNotes.add(MidiNoteEvent(
              noteNumber: _snare, startSeconds: hitTime,
              durationSeconds: 0.08, velocity: vel * 0.95,
            ));
          }
          if (hit.contains('hh')) {
            percNotes.add(MidiNoteEvent(
              noteNumber: _hihat, startSeconds: hitTime,
              durationSeconds: 0.03, velocity: vel * 0.6,
            ));
          }
        }
      }
    }

    return Arrangement(
      melody: finalMelody,
      chords: chordNotes,
      bass: bassNotes,
      percussion: percNotes,
      tempoBpm: score.tempoBpm,
      tonicMidi: tonicMidi,
      totalDurationSeconds: totalDuration,
    );
  }

  /// Convert AI-composed melody (MIDI note list + rhythm) to MidiNoteEvents.
  static List<MidiNoteEvent> _aiMelodyToEvents(AiFullScore score, double beatDuration) {
    final events = <MidiNoteEvent>[];
    final notes = score.melody!;
    final rhythm = score.melodyRhythm!;
    var time = 0.0;

    for (var i = 0; i < notes.length && i < rhythm.length; i++) {
      final dur = rhythm[i] * beatDuration;
      events.add(MidiNoteEvent(
        noteNumber: notes[i].clamp(48, 84),
        startSeconds: time,
        durationSeconds: dur * 0.85,
        velocity: 0.65,
      ));
      time += dur;
    }

    return events;
  }

  // ── Rule-based arrangement (offline fallback) ──
  // ── Major scale intervals (semitones from tonic) ──
  static const _majorScale = [0, 2, 4, 5, 7, 9, 11];
  static const _pentatonic = [0, 2, 4, 7, 9];

  // ── Chord degree → scale-index offsets for triads ──
  // I: 1-3-5, ii: 2-4-6, iii: 3-5-7, IV: 4-6-1(oct), V: 5-7-2(oct), vi: 6-1(oct)-3(oct)
  static const _chordOffsets = {
    1: [0, 2, 4],
    2: [1, 3, 5],
    3: [2, 4, 6],
    4: [3, 5, 0], // 0 maps to +octave
    5: [4, 6, 1], // 1 maps to +octave
    6: [5, 0, 2], // 0,2 map to +octave
  };

  // ── Style templates ──

  static const _styleProfiles = {
    StyleSeed.morningDew: _StyleProfile(
      progression: [1, 5, 6, 4],
      tempo: 75,
      chordRhythm: _ChordRhythm.arpeggiated,
      chordDurationBeats: 4,
      bassPattern: _BassPattern.rootOnOneAndThree,
      scale: _majorScale,
      hasPercussion: false,
    ),
    StyleSeed.mountainStream: _StyleProfile(
      progression: [1, 4, 1, 5],
      tempo: 60,
      chordRhythm: _ChordRhythm.pad,
      chordDurationBeats: 8,
      bassPattern: _BassPattern.heldRoot,
      scale: _pentatonic,
      hasPercussion: false,
    ),
    StyleSeed.frogDrum: _StyleProfile(
      progression: [1, 4, 5, 1],
      tempo: 100,
      chordRhythm: _ChordRhythm.staccato,
      chordDurationBeats: 2,
      bassPattern: _BassPattern.rootFifth,
      scale: _pentatonic,
      hasPercussion: true,
    ),
    StyleSeed.random: _StyleProfile(
      progression: [1, 5, 6, 4],
      tempo: 85,
      chordRhythm: _ChordRhythm.arpeggiated,
      chordDurationBeats: 4,
      bassPattern: _BassPattern.rootOnOneAndThree,
      scale: _majorScale,
      hasPercussion: false,
    ),
  };

  /// Generate full arrangement from melody + style.
  static Arrangement arrange({
    required List<MidiNoteEvent> melody,
    required StyleSeed style,
    double? durationOverride,
  }) {
    if (melody.isEmpty) {
      return _emptyArrangement(style, durationOverride ?? 4.0);
    }

    var profile = _styleProfiles[style]!;

    // Random style: randomize profile
    if (style == StyleSeed.random) {
      final rng = Random();
      final templates = [
        _styleProfiles[StyleSeed.morningDew]!,
        _styleProfiles[StyleSeed.mountainStream]!,
        _styleProfiles[StyleSeed.frogDrum]!,
      ];
      profile = templates[rng.nextInt(3)];
      // Randomize progression
      final allProgs = [
        [1, 5, 6, 4],
        [1, 4, 1, 5],
        [1, 6, 4, 5],
        [4, 5, 1, 1],
      ];
      profile = _StyleProfile(
        progression: allProgs[rng.nextInt(allProgs.length)],
        tempo: 60 + rng.nextInt(50).toDouble(),
        chordRhythm: profile.chordRhythm,
        chordDurationBeats: profile.chordDurationBeats,
        bassPattern: profile.bassPattern,
        scale: rng.nextBool() ? _majorScale : _pentatonic,
        hasPercussion: profile.hasPercussion,
      );
    }

    // ── 1. Detect tonic from melody ──
    final tonicMidi = _detectTonic(melody);

    // ── 2. Calculate duration ──
    final totalDuration = durationOverride ??
        (melody.map((n) => n.startSeconds + n.durationSeconds).reduce(max) + 1.0).clamp(3.0, 30.0);

    // ── 3. Generate chord track ──
    final chordNotes = _generateChords(
      tonicMidi, profile, totalDuration, profile.scale,
    );

    // ── 4. Generate bass track ──
    final bassNotes = _generateBass(
      tonicMidi, profile, totalDuration, profile.scale,
    );

    // ── 5. Generate percussion ──
    List<MidiNoteEvent> percNotes = [];
    if (profile.hasPercussion) {
      percNotes = _generatePercussion(totalDuration, profile.tempo);
    }

    return Arrangement(
      melody: melody,
      chords: chordNotes,
      bass: bassNotes,
      percussion: percNotes,
      tempoBpm: profile.tempo,
      tonicMidi: tonicMidi,
      totalDurationSeconds: totalDuration,
    );
  }

  // ── Tonic Detection ──

  /// Find the most likely tonic from melody pitch classes.
  /// Uses a simplified Krumhansl-Schmuckler approach: weight by duration.
  static int _detectTonic(List<MidiNoteEvent> melody) {
    final pitchClassWeight = List.filled(12, 0.0);
    var totalWeight = 0.0;

    for (final note in melody) {
      final pc = note.noteNumber % 12;
      final weight = note.durationSeconds;
      pitchClassWeight[pc] += weight;
      totalWeight += weight;
    }

    if (totalWeight == 0) return 60; // default C4

    // Major key profiles (Krumhansl-Schmuckler, simplified)
    const majorProfile = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88];

    // Try each possible tonic, correlate with major profile
    var bestTonic = 0;
    var bestScore = -1.0;

    for (var tonic = 0; tonic < 12; tonic++) {
      var score = 0.0;
      for (var i = 0; i < 12; i++) {
        final pc = (i - tonic + 12) % 12;
        score += pitchClassWeight[i] * majorProfile[pc];
      }
      if (score > bestScore) {
        bestScore = score;
        bestTonic = tonic;
      }
    }

    // Map pitch class to MIDI octave around middle of melody range
    final avgMidi = melody.map((n) => n.noteNumber).reduce((a, b) => a + b) ~/ melody.length;
    final octave = (avgMidi / 12).round() - 1;
    return octave * 12 + bestTonic;
  }

  // ── Chord Generation ──

  static List<MidiNoteEvent> _generateChords(
    int tonicMidi,
    _StyleProfile profile,
    double totalDuration,
    List<int> scale,
  ) {
    final notes = <MidiNoteEvent>[];
    final beatDuration = 60.0 / profile.tempo;
    final barBeats = 4.0;
    final barDuration = beatDuration * barBeats;

    var barIndex = 0;
    var time = 0.0;

    while (time < totalDuration) {
      final degree = profile.progression[barIndex % profile.progression.length];
      final offsets = _chordOffsets[degree]!;

      // Build chord note numbers
      final chordMidi = offsets.map((offset) {
        var midi = tonicMidi + scale[offset % scale.length];
        if (offset >= scale.length) midi += 12; // octave up
        while (midi > tonicMidi + 24) midi -= 12;
        if (midi < tonicMidi - 12) midi += 12;
        return midi;
      }).toList();

      switch (profile.chordRhythm) {
        case _ChordRhythm.arpeggiated:
          // Broken chord: play each note as eighth notes
          final noteLen = beatDuration * 0.5;
          for (var subTime = time; subTime < time + barDuration && subTime < totalDuration; subTime += noteLen) {
            final idx = ((subTime - time) / noteLen).round() % chordMidi.length;
            notes.add(MidiNoteEvent(
              noteNumber: chordMidi[idx],
              startSeconds: subTime,
              durationSeconds: noteLen * 0.9,
              velocity: 0.4,
            ));
          }
          break;

        case _ChordRhythm.pad:
          // Held chord pad: all notes held for full duration
          for (final midi in chordMidi) {
            notes.add(MidiNoteEvent(
              noteNumber: midi,
              startSeconds: time,
              durationSeconds: (barDuration * 0.95).clamp(0, totalDuration - time),
              velocity: 0.2,
            ));
          }
          break;

        case _ChordRhythm.staccato:
          // Short staccato hits on each beat
          for (var beat = 0; beat < barBeats; beat++) {
            final hitTime = time + beat * beatDuration;
            if (hitTime >= totalDuration) break;
            for (final midi in chordMidi) {
              notes.add(MidiNoteEvent(
                noteNumber: midi,
                startSeconds: hitTime,
                durationSeconds: beatDuration * 0.3,
                velocity: 0.5,
              ));
            }
          }
          break;
      }

      barIndex++;
      time += barDuration;
    }

    return notes;
  }

  // ── Bass Generation ──

  static List<MidiNoteEvent> _generateBass(
    int tonicMidi,
    _StyleProfile profile,
    double totalDuration,
    List<int> scale,
  ) {
    final notes = <MidiNoteEvent>[];
    final beatDuration = 60.0 / profile.tempo;
    final barDuration = beatDuration * 4;

    var barIndex = 0;
    var time = 0.0;

    while (time < totalDuration) {
      final degree = profile.progression[barIndex % profile.progression.length];
      final rootOffset = scale[degree - 1]; // degree 1 = index 0
      final rootMidi = tonicMidi + rootOffset - 12; // bass octave

      switch (profile.bassPattern) {
        case _BassPattern.rootOnOneAndThree:
          notes.add(MidiNoteEvent(
            noteNumber: rootMidi,
            startSeconds: time,
            durationSeconds: beatDuration * 1.8,
            velocity: 0.5,
          ));
          if (time + beatDuration * 2 < totalDuration) {
            notes.add(MidiNoteEvent(
              noteNumber: rootMidi,
              startSeconds: time + beatDuration * 2,
              durationSeconds: beatDuration * 1.8,
              velocity: 0.45,
            ));
          }
          break;

        case _BassPattern.heldRoot:
          notes.add(MidiNoteEvent(
            noteNumber: rootMidi,
            startSeconds: time,
            durationSeconds: (barDuration * 0.95).clamp(0, totalDuration - time),
            velocity: 0.3,
          ));
          break;

        case _BassPattern.rootFifth:
          final fifthOffset = scale[(degree - 1 + 4) % scale.length];
          final fifthMidi = tonicMidi + fifthOffset - 12;
          for (var beat = 0; beat < 4; beat++) {
            final noteTime = time + beat * beatDuration;
            if (noteTime >= totalDuration) break;
            notes.add(MidiNoteEvent(
              noteNumber: beat.isEven ? rootMidi : fifthMidi,
              startSeconds: noteTime,
              durationSeconds: beatDuration * 0.7,
              velocity: 0.55,
            ));
          }
          break;
      }

      barIndex++;
      time += barDuration;
    }

    return notes;
  }

  // ── Percussion Generation ──

  /// MIDI note numbers for GM percussion (channel 10).
  static const _kick = 36;
  static const _snare = 38;
  static const _hihat = 42;

  static List<MidiNoteEvent> _generatePercussion(double totalDuration, double tempo) {
    final notes = <MidiNoteEvent>[];
    final beatDuration = 60.0 / tempo;
    var time = 0.0;

    while (time < totalDuration) {
      // Kick on beats 1 and 3
      notes.add(MidiNoteEvent(
        noteNumber: _kick,
        startSeconds: time,
        durationSeconds: 0.1,
        velocity: 0.7,
      ));
      notes.add(MidiNoteEvent(
        noteNumber: _kick,
        startSeconds: time + beatDuration * 2,
        durationSeconds: 0.1,
        velocity: 0.6,
      ));

      // Snare on beats 2 and 4
      notes.add(MidiNoteEvent(
        noteNumber: _snare,
        startSeconds: time + beatDuration,
        durationSeconds: 0.08,
        velocity: 0.65,
      ));
      notes.add(MidiNoteEvent(
        noteNumber: _snare,
        startSeconds: time + beatDuration * 3,
        durationSeconds: 0.08,
        velocity: 0.65,
      ));

      // Hi-hat eighth notes
      for (var i = 0; i < 8; i++) {
        final ht = time + i * beatDuration * 0.5;
        if (ht >= totalDuration) break;
        notes.add(MidiNoteEvent(
          noteNumber: _hihat,
          startSeconds: ht,
          durationSeconds: 0.03,
          velocity: 0.4,
        ));
      }

      time += beatDuration * 4;
    }

    return notes;
  }

  // ── Helpers ──

  static Arrangement _emptyArrangement(StyleSeed style, double duration) {
    final profile = _styleProfiles[style]!;
    return Arrangement(
      melody: [],
      chords: [],
      bass: [],
      percussion: [],
      tempoBpm: profile.tempo,
      tonicMidi: 60,
      totalDurationSeconds: duration,
    );
  }
}

// ── Internal types ──

enum _ChordRhythm { arpeggiated, pad, staccato }
enum _BassPattern { rootOnOneAndThree, heldRoot, rootFifth }

class _StyleProfile {
  final List<int> progression; // scale degrees, e.g. [1,5,6,4]
  final double tempo;
  final _ChordRhythm chordRhythm;
  final double chordDurationBeats;
  final _BassPattern bassPattern;
  final List<int> scale;
  final bool hasPercussion;

  const _StyleProfile({
    required this.progression,
    required this.tempo,
    required this.chordRhythm,
    required this.chordDurationBeats,
    required this.bassPattern,
    required this.scale,
    required this.hasPercussion,
  });
}
