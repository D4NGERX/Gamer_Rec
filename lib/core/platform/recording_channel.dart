// lib/core/platform/recording_channel.dart

import 'package:flutter/services.dart';
import '../constants/app_constants.dart';

/// Thin wrapper around Flutter MethodChannel / EventChannel.
/// All native calls are routed through this class so the rest of
/// the app never imports `package:flutter/services.dart` directly.
class RecordingChannel {
  static final RecordingChannel _instance = RecordingChannel._internal();
  factory RecordingChannel() => _instance;
  RecordingChannel._internal();

  final MethodChannel _methodChannel =
      const MethodChannel(AppConstants.recordingMethodChannel);

  final EventChannel _eventChannel =
      const EventChannel(AppConstants.recordingEventChannel);

  final MethodChannel _fileChannel =
      const MethodChannel(AppConstants.fileMethodChannel);

  final MethodChannel _capabilitiesChannel =
      const MethodChannel(AppConstants.capabilitiesChannel);

  // ── Recording Controls ────────────────────────────────────────────────────

  Future<void> startRecording(Map<String, dynamic> config) async {
    await _methodChannel.invokeMethod(
        AppConstants.methodStartRecording, config);
  }

  Future<void> stopRecording() async {
    await _methodChannel.invokeMethod(AppConstants.methodStopRecording);
  }

  Future<void> pauseRecording() async {
    await _methodChannel.invokeMethod(AppConstants.methodPauseRecording);
  }

  Future<void> resumeRecording() async {
    await _methodChannel.invokeMethod(AppConstants.methodResumeRecording);
  }

  // ── Device Capabilities ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getDeviceCapabilities() async {
    final result = await _capabilitiesChannel
        .invokeMethod<Map>(AppConstants.methodGetCapabilities);
    return Map<String, dynamic>.from(result ?? {});
  }

  // ── Event Stream ──────────────────────────────────────────────────────────

  /// Emits native recording status events as raw Maps.
  Stream<Map<String, dynamic>> get recordingEvents =>
      _eventChannel.receiveBroadcastStream().map((event) {
        if (event is Map) return Map<String, dynamic>.from(event);
        throw const FormatException('Unexpected event format from native side');
      });

  // ── File Operations ───────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getRecordings() async {
    final result =
        await _fileChannel.invokeMethod<List>(AppConstants.methodGetRecordings);
    if (result == null) return [];
    return result
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<bool> deleteRecording(String path) async {
    final result = await _fileChannel
        .invokeMethod<bool>(AppConstants.methodDeleteRecording, {'path': path});
    return result ?? false;
  }

  Future<void> shareRecording(String path) async {
    await _fileChannel
        .invokeMethod(AppConstants.methodShareRecording, {'path': path});
  }

  Future<void> openRecording(String path) async {
    await _fileChannel
        .invokeMethod(AppConstants.methodOpenRecording, {'path': path});
  }
}
