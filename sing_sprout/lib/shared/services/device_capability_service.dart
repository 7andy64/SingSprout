import 'dart:io';
import 'package:flutter/foundation.dart';

/// Detects device hardware capabilities for adaptive feature gating.
///
/// Reads total RAM from /proc/meminfo on Android. Falls back to a safe
/// low-end assumption on platforms where detection isn't available.
class DeviceCapabilityService {
  static final DeviceCapabilityService _instance = DeviceCapabilityService._();
  factory DeviceCapabilityService() => _instance;
  DeviceCapabilityService._();

  int? _totalRamMB;
  bool _detected = false;

  /// Total device RAM in megabytes, or null if detection failed.
  int? get totalRamMB {
    _detectIfNeeded();
    return _totalRamMB;
  }

  /// Whether the device has 2GB+ RAM (suitable for on-device AI models).
  bool get isHighEndDevice {
    _detectIfNeeded();
    if (_totalRamMB == null) return false;
    return _totalRamMB! >= _highEndThresholdMB;
  }

  /// Threshold: devices with ≥2GB RAM can run CREPE TFLite (~2MB model, ~50ms/frame).
  static const _highEndThresholdMB = 2048;

  /// Whether to attempt loading the CREPE TFLite model for pitch detection.
  ///
  /// Returns true only when device RAM ≥2GB. On 1-2GB devices the ~2MB model
  /// + inference overhead can cause OOM or jank during recording.
  bool get shouldUseAIPitchDetection => isHighEndDevice;

  void _detectIfNeeded() {
    if (_detected) return;
    _detected = true;
    _totalRamMB = _readTotalRam();
    debugPrint(
      '[DeviceCapability] RAM: ${_totalRamMB != null ? "${_totalRamMB}MB" : "unknown"}'
      ' → ${isHighEndDevice ? "high-end (AI enabled)" : "low-end (DSP only)"}',
    );
  }

  int? _readTotalRam() {
    try {
      final meminfo = File('/proc/meminfo');
      if (!meminfo.existsSync()) return null;

      final lines = meminfo.readAsLinesSync();
      for (final line in lines) {
        if (line.startsWith('MemTotal:')) {
          // Format: "MemTotal:       3852048 kB"
          final parts = line.split(RegExp(r'\s+'));
          if (parts.length >= 3) {
            final kb = int.tryParse(parts[1]);
            if (kb != null) return kb ~/ 1024; // kB → MB
          }
        }
      }
    } catch (e) {
      debugPrint('[DeviceCapability] Failed to read /proc/meminfo: $e');
    }
    return null;
  }
}
