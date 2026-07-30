"""
Analyze a WAV recording: pitch detection (YIN), waveform stats, and report.

Usage:
  python tools/analyze_recording.py <wav_file>
  python tools/analyze_recording.py sing_sprout/test_data/child_recording_20260730.wav
"""

import argparse
import math
import struct
import sys
from pathlib import Path


def read_wav(path):
    """Read 16-bit mono WAV, return (samples, sample_rate)."""
    with open(path, "rb") as f:
        data = f.read()

    if data[:4] != b"RIFF":
        raise ValueError("Not a WAV file")

    # Find 'fmt ' and 'data' chunks
    offset = 12
    sample_rate = 44100
    data_offset = 0
    data_size = 0

    while offset < len(data) - 8:
        chunk_id = data[offset : offset + 4]
        chunk_size = struct.unpack_from("<I", data, offset + 4)[0]
        if chunk_id == b"fmt ":
            fmt_data = data[offset + 8 : offset + 8 + chunk_size]
            # fmt body: audio_format(2) + num_channels(2) + sample_rate(4) + ...
            sample_rate = struct.unpack_from("<I", fmt_data, 4)[0]
        elif chunk_id == b"data":
            data_offset = offset + 8
            data_size = chunk_size
            break
        offset += 8 + chunk_size

    if data_size == 0:
        raise ValueError("No data chunk found")

    num_samples = data_size // 2
    samples = []
    for i in range(num_samples):
        val = struct.unpack_from("<h", data, data_offset + i * 2)[0]
        samples.append(val / 32768.0)

    return samples, sample_rate


def yin_pitch(samples, sample_rate, window_size=1024, hop_size=512,
              threshold=0.15, min_freq=80, max_freq=1000):
    """YIN pitch detection. Returns list of (time_sec, freq_hz)."""
    min_tau = max(1, sample_rate // max_freq)
    max_tau = min(sample_rate // min_freq, window_size // 2)
    num_windows = (len(samples) - window_size) // hop_size + 1
    if num_windows <= 0:
        return []

    results = []
    for w in range(num_windows):
        offset = w * hop_size
        time_sec = offset / sample_rate

        # RMS silence gate
        rms = math.sqrt(sum(samples[offset + j] ** 2 for j in range(window_size)) / window_size)
        if rms < 0.01:
            results.append((time_sec, 0.0))
            continue

        # YIN difference function
        diff = [0.0] * (max_tau + 1)
        for tau in range(max_tau + 1):
            d = 0.0
            for j in range(window_size):
                idx = offset + j + tau
                if idx >= len(samples):
                    idx = len(samples) - 1
                diff_val = samples[offset + j] - samples[idx]
                d += diff_val * diff_val
            diff[tau] = d

        # Cumulative mean normalized difference
        cmnd = [1.0] * (max_tau + 1)
        running_sum = 0.0
        for tau in range(1, max_tau + 1):
            running_sum += diff[tau]
            cmnd[tau] = diff[tau] * tau / (running_sum + 1e-12)

        # Find first dip below threshold (local minimum)
        tau_est = -1
        for tau in range(min_tau, max_tau):
            if (cmnd[tau] < threshold
                    and cmnd[tau] < cmnd[tau - 1]
                    and cmnd[tau] < cmnd[tau + 1]):
                tau_est = tau
                break

        if tau_est < 0:
            # Absolute minimum in range
            min_val = float("inf")
            for tau in range(min_tau, max_tau):
                if cmnd[tau] < min_val:
                    min_val = cmnd[tau]
                    tau_est = tau
            if min_val > 0.5:
                results.append((time_sec, 0.0))
                continue

        # Parabolic interpolation
        d0 = cmnd[tau_est - 1] if tau_est > 0 else cmnd[tau_est]
        d1 = cmnd[tau_est]
        d2 = cmnd[tau_est + 1] if tau_est < max_tau else cmnd[tau_est]
        better_tau = tau_est + (d2 - d0) / (2 * (2 * d1 - d0 - d2) + 1e-12)

        freq = sample_rate / better_tau
        if 65 <= freq <= 1200:
            results.append((time_sec, freq))
        else:
            results.append((time_sec, 0.0))

    return results


def freq_to_midi(freq):
    """Convert frequency to MIDI note number."""
    if freq <= 0:
        return -1
    return round(12 * math.log2(freq / 440.0) + 69)


def midi_to_note_name(midi):
    """Convert MIDI number to note name."""
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    return f"{names[midi % 12]}{midi // 12 - 1}"


def freq_to_cents(freq, ref_freq):
    """Difference in cents between two frequencies."""
    if freq <= 0 or ref_freq <= 0:
        return None
    return 1200 * math.log2(freq / ref_freq)


def analyze(path):
    """Run full analysis and print report."""
    print(f"Analyzing: {path}")
    samples, sr = read_wav(path)
    duration = len(samples) / sr
    print(f"  Duration: {duration:.2f}s, Sample rate: {sr}Hz, Samples: {len(samples)}")
    print(f"  File: {Path(path).name}\n")

    # Amplitude stats
    abs_samples = [abs(s) for s in samples]
    peak = max(abs_samples)
    rms = math.sqrt(sum(s * s for s in samples) / len(samples))
    print(f"  Peak: {peak:.3f} ({20 * math.log10(peak + 1e-12):.1f} dBFS)")
    print(f"  RMS:  {rms:.4f}  ({20 * math.log10(rms + 1e-12):.1f} dBFS)")

    # Silence ratio
    silence_threshold = 0.01
    silent_frames = sum(1 for s in abs_samples if s < silence_threshold)
    silence_ratio = silent_frames / len(samples)
    print(f"  Silence: {silence_ratio * 100:.1f}% (< {silence_threshold})")

    # Pitch detection
    pitch = yin_pitch(samples, sr)
    voiced = [(t, f) for t, f in pitch if f > 0]
    voiced_ratio = len(voiced) / len(pitch) if pitch else 0
    print(f"\n  YIN frames: {len(pitch)} (hop=512 @ {sr}Hz)")
    print(f"  Voiced frames: {len(voiced)} ({voiced_ratio * 100:.1f}%)")

    if voiced:
        freqs = [f for _, f in voiced]
        freqs.sort()
        midi_notes = [freq_to_midi(f) for f in freqs]
        midi_notes = [m for m in midi_notes if m >= 0]

        print(f"\n  Frequency range: {freqs[0]:.1f} – {freqs[-1]:.1f} Hz")
        print(f"  Median frequency: {freqs[len(freqs) // 2]:.1f} Hz")
        print(f"  Mean frequency:   {sum(freqs) / len(freqs):.1f} Hz")

        if midi_notes:
            unique_notes = sorted(set(midi_notes))
            print(f"  MIDI range: {min(midi_notes)} – {max(midi_notes)}")
            print(f"  Unique notes: {len(unique_notes)}")
            notes_str = ", ".join(midi_to_note_name(n) for n in unique_notes[:15])
            if len(unique_notes) > 15:
                notes_str += f" … (+{len(unique_notes) - 15} more)"
            print(f"  Notes: {notes_str}")

        # Pitch stability (std dev of voiced freqs)
        if len(freqs) > 1:
            mean_f = sum(freqs) / len(freqs)
            variance = sum((f - mean_f) ** 2 for f in freqs) / len(freqs)
            std_dev = math.sqrt(variance)
            std_cents = 1200 * math.log2((mean_f + std_dev) / mean_f)
            print(f"  Pitch stability: σ = {std_dev:.1f} Hz ({std_cents:.1f} cents)")
    else:
        print("\n  !! No voiced pitch detected -- this may be speech, silence, or noise")

    # Segment analysis: split into 0.5s chunks
    print(f"\n  ── Time segments (0.5s windows) ──")
    segment_s = 0.5
    for t_start in [i * segment_s for i in range(int(duration / segment_s) + 1)]:
        t_end = t_start + segment_s
        seg_pitch = [f for ts, f in pitch if t_start <= ts < t_end and f > 0]
        seg_all = [f for ts, f in pitch if t_start <= ts < t_end]
        if seg_all:
            seg_voiced = len(seg_pitch) / len(seg_all) * 100
            if seg_pitch:
                median_f = sorted(seg_pitch)[len(seg_pitch) // 2]
                midi = freq_to_midi(median_f)
                note = midi_to_note_name(midi)
                print(f"  {t_start:.1f}s–{t_end:.1f}s: {seg_voiced:.0f}% voiced, "
                      f"median {median_f:.0f}Hz ({note})")
            else:
                print(f"  {t_start:.1f}s–{t_end:.1f}s: {seg_voiced:.0f}% voiced, no pitch")

    # Conclusion
    print(f"\n  ── Summary ──")
    if voiced_ratio > 0.5:
        print(f"  This appears to be a HUMMING/SINGING recording.")
        if midi_notes:
            print(f"  Detected {len(unique_notes)} unique notes over {duration:.1f}s")
    elif voiced_ratio > 0.2:
        print(f"  This appears to be SPEECH with some pitched segments.")
    else:
        print(f"  This appears to be mostly SILENCE or NOISE.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Analyze a WAV recording")
    parser.add_argument("wav_file", help="Path to WAV file")
    args = parser.parse_args()
    analyze(args.wav_file)
