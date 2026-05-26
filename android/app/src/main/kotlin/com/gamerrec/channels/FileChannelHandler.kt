// android/app/src/main/kotlin/com/gamerrec/channels/FileChannelHandler.kt

package com.gamerrec.channels

import android.content.Context
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.os.Environment
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

class FileChannelHandler(private val context: Context) :
    MethodChannel.MethodCallHandler {

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getRecordings"   -> result.success(getRecordings())
            "deleteRecording" -> {
                val path = call.argument<String>("path")
                    ?: return result.error("NO_PATH", "Missing path", null)
                result.success(deleteFile(path))
            }
            "shareRecording"  -> {
                val path = call.argument<String>("path")
                    ?: return result.error("NO_PATH", "Missing path", null)
                shareFile(path)
                result.success(null)
            }
            "openRecording" -> {
                val path = call.argument<String>("path")
                    ?: return result.error("NO_PATH", "Missing path", null)
                openFile(path)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun openFile(path: String) {
        val file = File(path)
        if (!file.exists()) return

        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "video/mp4")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    private fun recordingsDir(): File {
        val dir = context.getExternalFilesDir(Environment.DIRECTORY_MOVIES)
            ?: context.filesDir
        return File(dir, "GamerRec").also { it.mkdirs() }
    }

    private fun getRecordings(): List<Map<String, Any?>> {
        val dir = recordingsDir()
        if (!dir.exists()) return emptyList()
        return dir.listFiles()
            ?.filter { it.isFile && it.name.endsWith(".mp4") }
            ?.sortedByDescending { it.lastModified() }
            ?.map { file -> buildFileMap(file) }
            ?: emptyList()
    }

    private fun buildFileMap(file: File): Map<String, Any?> {
        val retriever = MediaMetadataRetriever()
        var durationMs: Long? = null
        var width: Int? = null
        var height: Int? = null

        try {
            retriever.setDataSource(file.absolutePath)
            val durStr = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_DURATION)
            durationMs = durStr?.toLongOrNull()
            width = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull()
            height = retriever.extractMetadata(
                MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull()
        } catch (_: Exception) {
        } finally {
            retriever.release()
        }

        return mapOf(
            "path"        to file.absolutePath,
            "name"        to file.name,
            "sizeBytes"   to file.length(),
            "createdAtMs" to file.lastModified(),
            "durationMs"  to durationMs,
            "width"       to width,
            "height"      to height,
        )
    }

    private fun deleteFile(path: String): Boolean {
        val file = File(path)
        return file.exists() && file.delete()
    }

    private fun shareFile(path: String) {
        val file = File(path)
        if (!file.exists()) return

        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file
        )

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "video/mp4"
            putExtra(Intent.EXTRA_STREAM, uri as android.os.Parcelable)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        context.startActivity(
            Intent.createChooser(shareIntent, "Share Recording")
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }
}
