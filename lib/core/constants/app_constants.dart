// lib/core/constants/app_constants.dart

class AppConstants {
  AppConstants._();

  // Platform Channel Names
  static const String recordingMethodChannel = 'com.gamerrec/recording';
  static const String recordingEventChannel = 'com.gamerrec/recording_events';
  static const String fileMethodChannel = 'com.gamerrec/files';
  static const String capabilitiesChannel = 'com.gamerrec/capabilities';

  // Method Channel Methods
  static const String methodStartRecording = 'startRecording';
  static const String methodStopRecording = 'stopRecording';
  static const String methodPauseRecording = 'pauseRecording';
  static const String methodResumeRecording = 'resumeRecording';
  static const String methodGetCapabilities = 'getDeviceCapabilities';
  static const String methodGetRecordings = 'getRecordings';
  static const String methodDeleteRecording = 'deleteRecording';
  static const String methodShareRecording = 'shareRecording';
  static const String methodOpenRecording = 'openRecording';

  // Native Event Types (received from Kotlin via EventChannel)
  static const String eventRecordingStarted = 'recording_started';
  static const String eventRecordingStopped = 'recording_stopped';
  static const String eventRecordingPaused = 'recording_paused';
  static const String eventRecordingResumed = 'recording_resumed';
  static const String eventRecordingProgress = 'recording_progress';
  static const String eventRecordingError = 'recording_error';

  // Recording Config Defaults (mirrors Appendix C)
  static const int defaultWidth = 1920;
  static const int defaultHeight = 1080;
  static const int defaultFpsIndex = 1; // 30 FPS
  static const int defaultBitrateMbps = 40;
  static const int defaultAudioMode = 3; // systemAndMic

  // Bitrate constraints
  static const int minBitrateMbps = 20;
  static const int maxBitrateMbps = 100;

  // App info
  static const String appName = 'Gamer Rec';
  static const String filePrefix = 'GamerRec';
}
