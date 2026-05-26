// android/app/src/main/kotlin/com/gamerrec/recording/RecordingConfig.kt

package com.gamerrec.recording

/**
 * Value object passed from Flutter through the platform channel.
 * audioMode values: 0=none, 1=systemOnly, 2=micOnly, 3=systemAndMic
 */
data class RecordingConfig(
    val width: Int,
    val height: Int,
    val frameRate: Int,
    val bitrateBps: Int,
    val audioMode: Int,
    val dndMode: Boolean = false,
    val videoEncoder: Int = 1,
    val orientationMode: Int = 0
)
