/// Audio device detection for EDITH.
///
/// HARDWARE CONSTRAINT: The HUD Egg is display-only (no mic, no speaker).
/// All audio goes through the phone OS:
/// - Input: built-in mic, Bluetooth headset mic, wired headset mic
/// - Output: phone speaker, Bluetooth earbuds/headphones, wired earphones
///
/// This service DETECTS actual devices via OS APIs. It does NOT create
/// custom Bluetooth audio drivers, custom routing, or a separate audio
/// protocol. Android manages routing; the app only reports status.
///
/// Bluetooth earbuds may provide both mic+speaker, but some headphones
/// are output-only. This service detects the actual capabilities instead
/// of assuming every connected headphone has a microphone.
///
/// Desktop (Windows/Linux): uses host OS default devices.
/// Web: unavailable (no device enumeration API).
library;

// ignore_for_file: experimental_member_use
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';

class AudioDeviceInfo {
  final String name;
  final bool isInput;
  final bool isOutput;
  final bool isBluetooth;
  final bool isWired;
  final bool isBuiltIn;

  const AudioDeviceInfo({
    required this.name,
    required this.isInput,
    required this.isOutput,
    required this.isBluetooth,
    required this.isWired,
    required this.isBuiltIn,
  });

  String get capabilities {
    final caps = <String>[];
    if (isInput) caps.add('mic');
    if (isOutput) caps.add('speaker');
    return caps.join('+');
  }

  String get typeLabel {
    if (isBluetooth) return 'Bluetooth';
    if (isWired) return 'Wired';
    if (isBuiltIn) return 'Built-in';
    return 'Other';
  }
}

bool _isBluetooth(AudioDeviceType t) {
  return t == AudioDeviceType.bluetoothSco ||
      t == AudioDeviceType.bluetoothA2dp;
}

bool _isWired(AudioDeviceType t) {
  return t == AudioDeviceType.wiredHeadset ||
      t == AudioDeviceType.wiredHeadphones ||
      t == AudioDeviceType.headsetMic ||
      t == AudioDeviceType.lineAnalog ||
      t == AudioDeviceType.lineDigital ||
      t == AudioDeviceType.auxLine;
}

bool _isBuiltIn(AudioDeviceType t) {
  return t == AudioDeviceType.builtInMic ||
      t == AudioDeviceType.builtInSpeaker ||
      t == AudioDeviceType.builtInEarpiece;
}

class AudioDeviceService {
  /// Get available input devices (microphones).
  /// Returns empty list on web or when unavailable.
  static Future<List<AudioDeviceInfo>> getInputDevices() async {
    if (kIsWeb) return [];
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices();
      final inputs = <AudioDeviceInfo>[];
      for (final d in devices) {
        if (d.isInput) {
          inputs.add(AudioDeviceInfo(
            name: d.name,
            isInput: true,
            isOutput: false,
            isBluetooth: _isBluetooth(d.type),
            isWired: _isWired(d.type),
            isBuiltIn: _isBuiltIn(d.type),
          ));
        }
      }
      // Always include built-in mic as fallback (OS default)
      if (inputs.isEmpty) {
        inputs.add(const AudioDeviceInfo(
          name: 'Built-in microphone (OS default)',
          isInput: true,
          isOutput: false,
          isBluetooth: false,
          isWired: false,
          isBuiltIn: true,
        ));
      }
      return inputs;
    } catch (_) {
      return [const AudioDeviceInfo(
        name: 'Built-in microphone (OS default)',
        isInput: true,
        isOutput: false,
        isBluetooth: false,
        isWired: false,
        isBuiltIn: true,
      )];
    }
  }

  /// Get available output devices (speakers).
  /// Returns empty list on web or when unavailable.
  static Future<List<AudioDeviceInfo>> getOutputDevices() async {
    if (kIsWeb) return [];
    try {
      final session = await AudioSession.instance;
      final devices = await session.getDevices();
      final outputs = <AudioDeviceInfo>[];
      for (final d in devices) {
        if (d.isOutput) {
          outputs.add(AudioDeviceInfo(
            name: d.name,
            isInput: false,
            isOutput: true,
            isBluetooth: _isBluetooth(d.type),
            isWired: _isWired(d.type),
            isBuiltIn: _isBuiltIn(d.type),
          ));
        }
      }
      if (outputs.isEmpty) {
        outputs.add(const AudioDeviceInfo(
          name: 'Phone speaker (OS default)',
          isInput: false,
          isOutput: true,
          isBluetooth: false,
          isWired: false,
          isBuiltIn: true,
        ));
      }
      return outputs;
    } catch (_) {
      return [const AudioDeviceInfo(
        name: 'Phone speaker (OS default)',
        isInput: false,
        isOutput: true,
        isBluetooth: false,
        isWired: false,
        isBuiltIn: true,
      )];
    }
  }

  /// Check if any Bluetooth device with microphone is available.
  /// (Earbuds with mic vs output-only headphones)
  static Future<bool> hasBluetoothMicrophone() async {
    final inputs = await getInputDevices();
    return inputs.any((d) => d.isBluetooth);
  }

  /// Check if any Bluetooth output device is available.
  static Future<bool> hasBluetoothOutput() async {
    final outputs = await getOutputDevices();
    return outputs.any((d) => d.isBluetooth);
  }
}
