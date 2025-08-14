// // Updated NewPipeMethodHandler.kt
// package com.example.sinkplayer

// import android.os.Handler
// import android.os.Looper
// import android.util.Log
// import android.webkit.WebView
// import android.content.Context
// import io.flutter.embedding.engine.FlutterEngine
// import io.flutter.plugin.common.MethodChannel
// import org.schabi.newpipe.extractor.NewPipe
// import org.schabi.newpipe.extractor.stream.StreamInfo
// import org.schabi.newpipe.extractor.stream.StreamType
// import org.schabi.newpipe.extractor.stream.VideoStream
// import org.schabi.newpipe.extractor.stream.AudioStream
// import java.util.*
// import com.example.sinkplayer.WebViewDownloader

// class NewPipeMethodHandler(
//     private val flutterEngine: FlutterEngine,
//     private val context: Context
// ) {
//     private val TAG = "NewPipeMethodHandler"

//     fun register() {
//         MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.sinkplayer.newpipe")
//             .setMethodCallHandler { call, result ->
//                 Log.d(TAG, "Method called: ${call.method}")
//                 when (call.method) {
//                     "getVideoStreams" -> {
//                         val videoUrl = call.argument<String>("videoUrl") ?: ""
//                         val preferredQuality = call.argument<String>("preferredQuality") ?: "720p"
//                         val isMobile = call.argument<Boolean>("isMobile") ?: true
//                         getVideoStreams(videoUrl, preferredQuality, isMobile, result)
//                     }
//                     else -> {
//                         Log.w(TAG, "Unknown method called: ${call.method}")
//                         result.notImplemented()
//                     }
//                 }
//             }
//     }

//     private fun getVideoStreams(
//         videoUrl: String,
//         preferredQuality: String,
//         isMobile: Boolean,
//         result: MethodChannel.Result
//     ) {
//         Thread {
//             try {
//                 // Initialize WebView for integrity checks
//                 Handler(Looper.getMainLooper()).post {
//                     try {
//                         WebView.setWebContentsDebuggingEnabled(false)
//                         val webView = WebView(context)
//                         webView.settings.javaScriptEnabled = true
//                         webView.settings.userAgentString = if (isMobile) {
//                             "Mozilla/5.0 (Linux; Android 10; Pixel 4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
//                         } else {
//                             "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
//                         }
                        
//                         // Initialize NewPipe with WebView-enabled downloader
//                         NewPipe.init(WebViewDownloader(context, isMobile))
                        
//                         processVideoStream(videoUrl, preferredQuality, result)
                        
//                     } catch (e: Exception) {
//                         Log.e(TAG, "WebView initialization failed", e)
//                         // Fallback to custom downloader
//                         NewPipe.init(CustomDownloader(isMobile))
//                         processVideoStream(videoUrl, preferredQuality, result)
//                     }
//                 }
//             } catch (e: Exception) {
//                 Log.e(TAG, "Error in getVideoStreams", e)
//                 Handler(Looper.getMainLooper()).post {
//                     result.error("STREAM_ERROR", "Failed to initialize: ${e.message}", null)
//                 }
//             }
//         }.start()
//     }

//     private fun processVideoStream(
//         videoUrl: String,
//         preferredQuality: String,
//         result: MethodChannel.Result
//     ) {
//         Thread {
//             try {
//                 val service = NewPipe.getService("YouTube")
//                 Log.d(TAG, "Fetching stream info for URL: $videoUrl")
                
//                 // Enhanced retry logic with exponential backoff
//                 var retries = 5
//                 var streamInfo: StreamInfo? = null
//                 var lastException: Exception? = null
//                 var backoffMs = 1000L
                
//                 while (retries > 0) {
//                     try {
//                         val streamExtractor = service.getStreamExtractor(videoUrl)
//                         streamExtractor.fetchPage()
                        
//                         if (streamExtractor.streamType != StreamType.VIDEO_STREAM) {
//                             throw Exception("The provided URL is not a video stream")
//                         }
                        
//                         streamInfo = StreamInfo.getInfo(streamExtractor)
//                         Log.d(TAG, "Successfully fetched stream info for: ${streamInfo.name}")
//                         break
//                     } catch (e: Exception) {
//                         lastException = e
//                         Log.w(TAG, "Attempt ${6-retries} failed: ${e.message}")
//                         retries--
//                         if (retries > 0) {
//                             Thread.sleep(backoffMs)
//                             backoffMs *= 2 // Exponential backoff
//                         }
//                     }
//                 }
                
//                 streamInfo ?: throw lastException ?: Exception("Failed after 5 attempts")

//                 val videoStreams = streamInfo.videoStreams
//                 val audioStreams = streamInfo.audioStreams

//                 if (videoStreams.isEmpty()) throw Exception("No video streams available")
//                 if (audioStreams.isEmpty()) throw Exception("No audio streams available")

//                 val selectedVideo = selectBestVideoStream(videoStreams, preferredQuality) 
//                     ?: videoStreams.maxByOrNull { it.bitrate }
//                     ?: throw Exception("Could not select a video stream")

//                 val selectedAudio = audioStreams.maxByOrNull { it.averageBitrate }
//                     ?: throw Exception("Could not select an audio stream")

//                 Log.d(TAG, "Selected streams - Video: ${selectedVideo.width}x${selectedVideo.height}, " +
//                       "Audio: ${selectedAudio.averageBitrate}bps")

//                 // Prepare result with all necessary information
//                 val resultMap = mutableMapOf(
//                     "videoUrl" to selectedVideo.url,
//                     "audioUrl" to selectedAudio.url,
//                     "selectedQuality" to "${selectedVideo.height}p",
//                     "availableQualities" to getAvailableQualities(videoStreams),
//                     "bitrate" to selectedAudio.averageBitrate,
//                     "title" to streamInfo.name,
//                     "duration" to streamInfo.duration,
//                     "headers" to WebViewDownloader.generateAdvancedHeaders(videoUrl)
//                 )

//                 // Handle nullable format names
//                 selectedVideo.format?.let { format ->
//                     resultMap["videoCodec"] = format.name
//                 }
                
//                 selectedAudio.format?.let { format ->
//                     resultMap["audioCodec"] = format.name
//                 }

//                 Handler(Looper.getMainLooper()).post {
//                     result.success(resultMap)
//                 }

//             } catch (e: Exception) {
//                 Log.e(TAG, "Error getting video streams", e)
//                 Handler(Looper.getMainLooper()).post {
//                     result.error("STREAM_ERROR", "Failed to load video streams: ${e.message}", null)
//                 }
//             }
//         }.start()
//     }

//     private fun selectBestVideoStream(streams: List<VideoStream>, preferredQuality: String): VideoStream? {
//         Log.d(TAG, "Selecting best video stream for quality: $preferredQuality")
        
//         val targetHeight = when (preferredQuality.lowercase()) {
//             "auto" -> Int.MAX_VALUE
//             "144p" -> 144
//             "240p" -> 240
//             "360p" -> 360
//             "480p" -> 480
//             "720p" -> 720
//             "1080p" -> 1080
//             "1440p" -> 1440
//             "2160p", "4k" -> 2160
//             else -> 720 // default
//         }

//         // Filter streams that match or are below the target quality
//         val candidates = streams.filter { it.height <= targetHeight }
        
//         if (candidates.isEmpty()) {
//             Log.w(TAG, "No streams below target quality, using lowest available")
//             return streams.minByOrNull { it.height }
//         }

//         // Find the stream closest to but not exceeding the target quality
//         return candidates.maxByOrNull { it.height }.also {
//             Log.d(TAG, "Selected stream with height: ${it?.height}")
//         }
//     }

//     private fun getAvailableQualities(streams: List<VideoStream>): List<String> {
//         val uniqueQualities = streams
//             .map { "${it.height}p" }
//             .distinct()
//             .sortedBy { it.replace("p", "").toInt() }
        
//         Log.d(TAG, "Available qualities: ${uniqueQualities.joinToString()}")
//         return uniqueQualities
//     }
// }