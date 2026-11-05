package id.nusa.nusa_chat

import android.content.Context
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.effect.FrameDropEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.EncoderSelector
import androidx.media3.transformer.EncoderUtil
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import com.google.common.collect.ImmutableList
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.concurrent.thread
import kotlin.math.max
import kotlin.math.min

/**
 * Encodes videos with a constant bitrate.
 *
 * Since Android 12 the platform raises the bitrate of a VBR video encoding to a
 * quality floor, so a requested bitrate says little about the resulting size: 1 Mbps
 * at 720p measured about 2.5 Mbps. The floor does not apply to CBR. Some hardware
 * encoders do not declare CBR and still honour it, which Media3's selection would
 * rule out, so the hardware encoder is chosen here with Media3's fallback off.
 */
class NusaChatPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val main = Handler(Looper.getMainLooper())
    private val progressHolder = ProgressHolder()

    private var transformer: Transformer? = null
    private var pendingResult: MethodChannel.Result? = null
    private var poll: Runnable? = null
    private var output: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "nusa_chat/video")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        stop()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "tracks" -> tracks(call.argument<String>("path")!!, result)
            "encode" -> encode(EncodeJob.from(call), result)
            "cancel" -> {
                stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    /** The sample types of a file. */
    private fun tracks(path: String, result: MethodChannel.Result) {
        thread {
            val extractor = MediaExtractor()
            try {
                extractor.setDataSource(path)
                var video: String? = null
                var audio: String? = null
                for (index in 0 until extractor.trackCount) {
                    val mime = extractor.getTrackFormat(index).getString(MediaFormat.KEY_MIME) ?: continue
                    if (video == null && mime.startsWith("video/")) video = mime
                    if (audio == null && mime.startsWith("audio/")) audio = mime
                }
                main.post { result.success(mapOf("video" to video, "audio" to audio)) }
            } catch (error: Exception) {
                main.post { result.error("unreadable", error.message, null) }
            } finally {
                extractor.release()
            }
        }
    }

    private fun encode(job: EncodeJob, result: MethodChannel.Result) {
        if (transformer != null) {
            result.error("busy", "Another video is being encoded", null)
            return
        }
        pendingResult = result
        output = job.output
        thread {
            val edited = try {
                editedItem(job)
            } catch (error: Exception) {
                main.post { finish { it.error("unreadable", error.message, null) } }
                return@thread
            }
            main.post { if (pendingResult != null) start(job, edited, constantBitrate = true) }
        }
    }

    /** With [constantBitrate] off, Media3 picks what the device can do; the size check in Dart still applies. */
    private fun start(job: EncodeJob, edited: EditedMediaItem, constantBitrate: Boolean) {
        // Media3's default operating rate is Integer.MAX_VALUE; MediaCodec documents Short.MAX_VALUE as "as fast as possible".
        val settings = VideoEncoderSettings.Builder()
            .setBitrate(job.videoBitrate)
            .setEncoderPerformanceParameters(OPERATING_RATE_MAX, PRIORITY_NON_REALTIME)
        if (constantBitrate) settings.setBitrateMode(MediaCodecInfo.EncoderCapabilities.BITRATE_MODE_CBR)
        val encoders = DefaultEncoderFactory.Builder(context)
            .setRequestedVideoEncoderSettings(settings.build())
            .setEnableFallback(!constantBitrate)
        if (constantBitrate) encoders.setVideoEncoderSelector(hardwareEncoders)

        val current = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoders.build())
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    finish { it.success(null) }
                }

                override fun onError(composition: Composition, exportResult: ExportResult, error: ExportException) {
                    File(job.output).delete()
                    if (constantBitrate) {
                        clearJob()
                        start(job, edited, constantBitrate = false)
                    } else {
                        finish { it.error("failed", error.message, null) }
                    }
                }
            })
            .build()
        transformer = current
        val composition = Composition.Builder(EditedMediaItemSequence.Builder(edited).build())
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL)
            .build()
        current.start(composition, job.output)
        startProgress(current)
    }

    /** Sized from the picture as it is displayed: the frames reach the effects already rotated. */
    private fun editedItem(job: EncodeJob): EditedMediaItem {
        val retriever = MediaMetadataRetriever()
        val width: Int
        val height: Int
        val rate: Float
        try {
            retriever.setDataSource(job.path)
            val rawWidth = retriever.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
            val rawHeight = retriever.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
            val sideways = retriever.int(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION) % 180 != 0
            width = if (sideways) rawHeight else rawWidth
            height = if (sideways) rawWidth else rawHeight
            rate = frameRate(job.path)
        } finally {
            retriever.release()
        }

        val effects = mutableListOf<Effect>()
        if (rate > job.maxFps + 1) effects += FrameDropEffect.createDefaultFrameDropEffect(job.maxFps.toFloat())
        val scale = min(
            1.0,
            min(job.maxShortSide.toDouble() / min(width, height), job.maxLongSide.toDouble() / max(width, height)),
        )
        if (scale < 1.0) {
            effects += Presentation.createForWidthAndHeight(
                aligned(width * scale),
                aligned(height * scale),
                Presentation.LAYOUT_SCALE_TO_FIT,
            )
        }

        val item = MediaItem.Builder()
            .setUri(Uri.fromFile(File(job.path)))
            .setClippingConfiguration(
                MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(job.startMs)
                    .setEndPositionMs(job.endMs)
                    .build(),
            )
            .build()
        return EditedMediaItem.Builder(item).setEffects(Effects(emptyList(), effects)).build()
    }

    private fun frameRate(path: String): Float {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
            for (index in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(index)
                val mime = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("video/") && format.containsKey(MediaFormat.KEY_FRAME_RATE)) {
                    return format.getInteger(MediaFormat.KEY_FRAME_RATE).toFloat()
                }
            }
        } finally {
            extractor.release()
        }
        return 0f
    }

    private fun startProgress(current: Transformer) {
        poll = object : Runnable {
            override fun run() {
                if (transformer !== current) return
                if (current.getProgress(progressHolder) == Transformer.PROGRESS_STATE_AVAILABLE) {
                    channel.invokeMethod("progress", progressHolder.progress / 100.0)
                }
                main.postDelayed(this, PROGRESS_INTERVAL_MS)
            }
        }.also { main.post(it) }
    }

    private fun clearJob() {
        poll?.let { main.removeCallbacks(it) }
        poll = null
        transformer = null
    }

    private fun finish(reply: (MethodChannel.Result) -> Unit) {
        clearJob()
        output = null
        val result = pendingResult
        pendingResult = null
        result?.let(reply)
    }

    /** `Transformer.cancel` never calls its listener, so the waiting call is answered here. */
    private fun stop() {
        transformer?.cancel()
        output?.let { File(it).delete() }
        finish { it.error("cancelled", null, null) }
    }

    private fun MediaMetadataRetriever.int(key: Int) = extractMetadata(key)?.toIntOrNull() ?: 0

    private data class EncodeJob(
        val path: String,
        val output: String,
        val maxShortSide: Int,
        val maxLongSide: Int,
        val videoBitrate: Int,
        val maxFps: Int,
        val startMs: Long,
        val endMs: Long,
    ) {
        companion object {
            fun from(call: MethodCall) = EncodeJob(
                path = call.argument<String>("path")!!,
                output = call.argument<String>("output")!!,
                maxShortSide = call.argument<Int>("maxShortSide")!!,
                maxLongSide = call.argument<Int>("maxLongSide")!!,
                videoBitrate = call.argument<Int>("videoBitrate")!!,
                maxFps = call.argument<Int>("maxFps")!!,
                startMs = call.argument<Number>("startMs")!!.toLong(),
                endMs = call.argument<Number>("endMs")!!.toLong(),
            )
        }
    }

    private companion object {
        const val PROGRESS_INTERVAL_MS = 250L
        const val OPERATING_RATE_MAX = 32767
        const val PRIORITY_NON_REALTIME = 1

        val hardwareEncoders = EncoderSelector { mime ->
            ImmutableList.copyOf(
                EncoderUtil.getSupportedEncoders(mime).filter {
                    EncoderUtil.isHardwareAccelerated(it, mime) && !it.name.endsWith(".secure")
                },
            )
        }

        /** Whole macroblocks, rounded down so it never scales up. */
        fun aligned(value: Double) = max(16, value.toInt() / 16 * 16)
    }
}
