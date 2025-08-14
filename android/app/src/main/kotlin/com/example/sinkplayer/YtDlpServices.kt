// package com.example.sinkplayer // Replace with your package name

// import android.content.Context
// import android.util.Log
// import kotlinx.coroutines.*
// import java.io.File
// import org.json.JSONObject
// import org.json.JSONArray
// import java.net.URLEncoder
// import java.util.concurrent.ConcurrentHashMap

// class YtDlpService(private val context: Context) {
//     private lateinit var ytDlpPath: String
//     private val thumbnailCache = ConcurrentHashMap<String, String>()
//     private val TAG = "YtDlpService"
//     // private external fun getYtDlpNativePath(): String
//     // private external fun isYtDlpExecutable(path: String): Boolean
    
//     // Quality presets for dynamic switching
//     enum class VideoQuality(val height: Int, val description: String) {
//         QUALITY_144P(144, "144p"),
//         QUALITY_240P(240, "240p"),
//         QUALITY_360P(360, "360p"),
//         QUALITY_480P(480, "480p"),
//         QUALITY_720P(720, "720p HD"),
//         QUALITY_1080P(1080, "1080p Full HD"),
//         QUALITY_1440P(1440, "1440p 2K"),
//         QUALITY_2160P(2160, "2160p 4K"),
//         QUALITY_4320P(4320, "4320p 8K"),
//         QUALITY_BEST(-1, "Best Available"),
//         QUALITY_WORST(-2, "Worst Available")
//     }
    
//     enum class AudioQuality(val bitrate: Int, val description: String) {
//         QUALITY_48K(48, "48 kbps"),
//         QUALITY_64K(64, "64 kbps"),
//         QUALITY_96K(96, "96 kbps"),
//         QUALITY_128K(128, "128 kbps"),
//         QUALITY_160K(160, "160 kbps"),
//         QUALITY_192K(192, "192 kbps"),
//         QUALITY_256K(256, "256 kbps"),
//         QUALITY_320K(320, "320 kbps"),
//         QUALITY_BEST(-1, "Best Available"),
//         QUALITY_WORST(-2, "Worst Available")
//     }
    
//     init {
//         Log.d(TAG, "Initializing YtDlpService")
//         setupYtDlpFallback()
//     }

    

    
    
//     private fun setupYtDlpFallback() {
//     Log.d(TAG, "Setting up yt-dlp binary")
//     val internalDir = context.filesDir
//     val ytDlpFile = File(internalDir, "yt-dlp")

//     Log.d(TAG, "Internal directory: ${internalDir.absolutePath}")
//     Log.d(TAG, "yt-dlp file path: ${ytDlpFile.absolutePath}")

//     try {
//         val assetInput = context.assets.open("yt-dlp")
//         val assetSize = assetInput.available()
//         Log.d(TAG, "Asset yt-dlp size from assets: $assetSize bytes")

//         if (!ytDlpFile.exists() || ytDlpFile.length() != assetSize.toLong()) {
//             Log.d(TAG, "yt-dlp binary missing or size mismatch. Copying from assets.")
//             context.assets.open("yt-dlp").use { input ->
//                 ytDlpFile.outputStream().use { output ->
//                     val copied = input.copyTo(output)
//                     Log.d(TAG, "Copied $copied bytes to internal storage.")
//                 }
//             }
//         } else {
//             Log.d(TAG, "yt-dlp already exists with correct size.")
//         }

//         // Double-check file length after copy
//         Log.d(TAG, "yt-dlp internal file length: ${ytDlpFile.length()}")

//         // Set executable permissions
//         setExecutablePermissions(ytDlpFile)

//         // Final checks
//         Log.d(TAG, "yt-dlp canExecute: ${ytDlpFile.canExecute()}, canRead: ${ytDlpFile.canRead()}, exists: ${ytDlpFile.exists()}")

//         ytDlpPath = ytDlpFile.absolutePath
//         Log.d(TAG, "yt-dlp path set to: $ytDlpPath")

//         // Test execution
//         testYtDlpVersion()

//     } catch (e: Exception) {
//         Log.e(TAG, "Error setting up yt-dlp binary", e)
//     }
// }

//     private fun setExecutablePermissions(file: File) {
//         try {
//             Log.d(TAG, "Setting executable permissions for: ${file.absolutePath}")
            
//             // Method 1: Java File.setExecutable()
//             val javaSetResult = file.setExecutable(true, false)
//             Log.d(TAG, "Java setExecutable result: $javaSetResult")
            
//             // Method 2: Runtime chmod (more reliable on Android)
//             try {
//                 val chmodProcess = Runtime.getRuntime().exec(arrayOf("chmod", "755", file.absolutePath))
//                 val chmodExitCode = chmodProcess.waitFor()
//                 Log.d(TAG, "chmod 755 exit code: $chmodExitCode")
                
//                 if (chmodExitCode != 0) {
//                     Log.w(TAG, "chmod 755 failed, trying alternative methods")
                    
//                     // Method 3: Alternative chmod syntax
//                     val altChmodProcess = Runtime.getRuntime().exec("chmod 0755 ${file.absolutePath}")
//                     val altChmodExitCode = altChmodProcess.waitFor()
//                     Log.d(TAG, "Alternative chmod exit code: $altChmodExitCode")
//                 }
//             } catch (e: Exception) {
//                 Log.w(TAG, "Runtime chmod failed", e)
//             }
            
//             // Method 4: ProcessBuilder approach
//             try {
//                 val processBuilder = ProcessBuilder("chmod", "755", file.absolutePath)
//                 val process = processBuilder.start()
//                 val exitCode = process.waitFor()
//                 Log.d(TAG, "ProcessBuilder chmod exit code: $exitCode")
//             } catch (e: Exception) {
//                 Log.w(TAG, "ProcessBuilder chmod failed", e)
//             }
            
//             // Verify permissions
//             val canExecute = file.canExecute()
//             val canRead = file.canRead()
//             Log.d(TAG, "File permissions check - canExecute: $canExecute, canRead: $canRead")
            
//             if (!canExecute) {
//                 Log.w(TAG, "File is still not executable after permission setting attempts")
//             }
            
//         } catch (e: Exception) {
//             Log.e(TAG, "Error setting executable permissions", e)
//         }
//     }
    
//     private fun testYtDlpVersion() {
//     try {
//         Log.d(TAG, "Testing yt-dlp version")

//         val ytDlpFile = File(ytDlpPath)

//         if (!ytDlpFile.exists()) {
//             Log.e(TAG, "yt-dlp file does not exist: $ytDlpPath")
//             return
//         }

//         if (!ytDlpFile.canExecute()) {
//             Log.w(TAG, "yt-dlp is not executable. Retrying permission set...")
//             setExecutablePermissions(ytDlpFile)
//         }

//         val command = listOf(ytDlpPath, "--version")
//         Log.d(TAG, "Running: ${command.joinToString(" ")}")

//         val process = ProcessBuilder(command)
//             .directory(context.filesDir)
//             .redirectErrorStream(true)
//             .start()

//         val output = process.inputStream.bufferedReader().readText()
//         val errorOutput = process.errorStream.bufferedReader().readText()
//         val exitCode = process.waitFor()

//         Log.d(TAG, "yt-dlp exit code: $exitCode")
//         if (output.isNotBlank()) Log.d(TAG, "yt-dlp stdout: $output")
//         if (errorOutput.isNotBlank()) Log.e(TAG, "yt-dlp stderr: $errorOutput")

//         if (exitCode != 0) {
//             Log.e(TAG, "yt-dlp command failed with exit code $exitCode")
//         }

//     } catch (e: Exception) {
//         Log.e(TAG, "yt-dlp execution error", e)
//     }
// }

    
//     private fun createProcessBuilder(command: List<String>): ProcessBuilder {
//         val processBuilder = ProcessBuilder(command)
//         processBuilder.directory(context.filesDir) // Set working directory
        
//         // Set environment variables if needed
//         val env = processBuilder.environment()
//         env["PATH"] = "${context.filesDir.absolutePath}:${env["PATH"]}"
        
//         return processBuilder
//     }

//     // Updated getBestStreams with better error handling
//     suspend fun getBestStreams(videoUrl: String): Map<String, String>? {
//         return withContext(Dispatchers.IO) {
//             try {
//                 Log.d(TAG, "Getting best streams for: $videoUrl")
                
//                 // Verify file permissions before executing
//                 val ytDlpFile = File(ytDlpPath)
//                 if (!ytDlpFile.canExecute()) {
//                     Log.e(TAG, "yt-dlp is not executable, attempting to fix permissions")
//                     setExecutablePermissions(ytDlpFile)
                    
//                     if (!ytDlpFile.canExecute()) {
//                         Log.e(TAG, "Cannot execute yt-dlp: permission denied")
//                         return@withContext null
//                     }
//                 }
                
//                 val command = listOf(
//                     ytDlpPath,
//                     "--format", "bestvideo+bestaudio/best",
//                     "--get-url",
//                     "--no-warnings",
//                     videoUrl
//                 )

//                 val processBuilder = createProcessBuilder(command)
//                 val process = processBuilder.start()
                
//                 val output = process.inputStream.bufferedReader().use { it.readText() }
//                 val errorOutput = process.errorStream.bufferedReader().use { it.readText() }
//                 val exitCode = process.waitFor()

//                 Log.d(TAG, "getBestStreams exit code: $exitCode")
//                 if (errorOutput.isNotEmpty()) Log.w(TAG, "getBestStreams stderr: $errorOutput")

//                 if (exitCode == 0) {
//                     val urls = output.trim().split("\n")
//                     return@withContext mapOf(
//                         "videoUrl" to urls[0],
//                         "audioUrl" to if (urls.size > 1) urls[1] else urls[0]
//                     )
//                 } else {
//                     Log.e(TAG, "Error getting best streams: $errorOutput")
//                     return@withContext null
//                 }
//             } catch (e: Exception) {
//                 Log.e(TAG, "Exception in getBestStreams", e)
//                 return@withContext null
//             }
//         }
//     }

//     suspend fun getAdaptiveStreams(url: String): Map<String, Any>? {
//         return withContext(Dispatchers.IO) {
//             try {
//                 val command = listOf(
//                     ytDlpPath,
//                     "--dump-json",
//                     "--format", "bestaudio",
//                     "--no-warnings",
//                     url
//                 )
                
//                 val processBuilder = createProcessBuilder(command)
//                 val process = processBuilder.start()
                
//                 val output = process.inputStream.bufferedReader().use { it.readText() }
//                 val error = process.errorStream.bufferedReader().use { it.readText() }
//                 val exitCode = process.waitFor()
                
//                 if (exitCode == 0) {
//                     val json = JSONObject(output)
//                     val formats = json.optJSONArray("formats") ?: return@withContext null
                    
//                     val audioStreams = mutableListOf<Map<String, Any>>()
                    
//                     for (i in 0 until formats.length()) {
//                         val format = formats.getJSONObject(i)
//                         if (format.optString("acodec", "none") != "none") {
//                             val streamInfo = mapOf(
//                                 "url" to format.optString("url", ""),
//                                 "formatId" to format.optString("format_id", ""),
//                                 "ext" to format.optString("ext", ""),
//                                 "abr" to format.optDouble("abr", 0.0),
//                                 "acodec" to format.optString("acodec", ""),
//                                 "filesize" to format.optLong("filesize", 0)
//                             )
//                             audioStreams.add(streamInfo)
//                         }
//                     }
                    
//                     // Sort by bitrate (highest first)
//                     audioStreams.sortByDescending { it["abr"] as Double }
                    
//                     return@withContext mapOf("audioStreams" to audioStreams)
//                 } else {
//                     Log.e(TAG, "Error getting adaptive streams: $error")
//                     return@withContext null
//                 }
//             } catch (e: Exception) {
//                 Log.e(TAG, "Exception in getAdaptiveStreams", e)
//                 return@withContext null
//             }
//         }
//     }
    
//     suspend fun getVideoInfo(url: String): Map<String, Any>? {
//         return withContext(Dispatchers.IO) {
//             Log.d(TAG, "Getting video info for URL: $url")
            
//             try {
//                 val command = listOf(
//                     ytDlpPath, 
//                     "--dump-json", 
//                     "--no-playlist", 
//                     "--write-thumbnail",
//                     "--skip-download",
//                     "--no-warnings",
//                     url
//                 )
                
//                 Log.d(TAG, "Executing command: ${command.joinToString(" ")}")
//                 val processBuilder = createProcessBuilder(command)
//                 val process = processBuilder.start()
                
//                 val output = process.inputStream.bufferedReader().use { it.readText() }
//                 val errorOutput = process.errorStream.bufferedReader().use { it.readText() }
//                 val exitCode = process.waitFor()
                
//                 Log.d(TAG, "Command exit code: $exitCode")
//                 if (errorOutput.isNotEmpty()) Log.w(TAG, "Command stderr: $errorOutput")
                
//                 if (exitCode == 0 && output.isNotEmpty()) {
//                     Log.d(TAG, "Successfully got video info, parsing JSON")
//                     val json = JSONObject(output)
                    
//                     val result: Map<String, Any> = mapOf(
//                         "id" to (json.optString("id", "") as Any),
//                         "title" to (json.optString("title", "") as Any),
//                         "description" to (json.optString("description", "") as Any),
//                         "duration" to (json.optInt("duration", 0) as Any),
//                         "thumbnail" to (getBestThumbnail(json) as Any),
//                         "uploader" to (json.optString("uploader", "") as Any),
//                         "uploaderAvatarUrl" to (getUploaderAvatar(json) as Any),
//                         "viewCount" to (json.optLong("view_count", 0) as Any),
//                         "likeCount" to (json.optLong("like_count", 0) as Any),
//                         "uploadDate" to (json.optString("upload_date", "") as Any),
//                         "channelId" to (json.optString("channel_id", "") as Any),
//                         "channelUrl" to (json.optString("channel_url", "") as Any),
//                         "tags" to (getTagsList(json) as Any),
//                         "categories" to (getCategoriesList(json) as Any)
//                     )
                    
//                     Log.d(TAG, "Video info parsed successfully - Title: ${result["title"]}")
//                     return@withContext result
//                 } else {
//                     Log.e(TAG, "Failed to get video info - Exit code: $exitCode")
//                     return@withContext null
//                 }
//             } catch (e: Exception) {
//                 Log.e(TAG, "Exception in getVideoInfo", e)
//                 return@withContext null
//             }
//         }
//     }
    
//     suspend fun searchVideos(query: String, maxResults: Int = 10): List<Map<String, Any>>? {
//         return withContext(Dispatchers.IO) {
//             Log.d(TAG, "Searching videos for query: '$query', maxResults: $maxResults")
            
//             try {
//                 val encodedQuery = URLEncoder.encode(query, "UTF-8")
//                 val searchUrl = "ytsearch$maxResults:$encodedQuery"
                
//                 val command = listOf(
//                     ytDlpPath,
//                     "--dump-json",
//                     "--flat-playlist",
//                     "--no-playlist",
//                     "--no-warnings",
//                     searchUrl
//                 )
                
//                 Log.d(TAG, "Search command: ${command.joinToString(" ")}")
//                 val processBuilder = createProcessBuilder(command)
//                 val process = processBuilder.start()
                
//                 val output = process.inputStream.bufferedReader().use { it.readText() }
//                 val errorOutput = process.errorStream.bufferedReader().use { it.readText() }
//                 val exitCode = process.waitFor()
                
//                 Log.d(TAG, "Search exit code: $exitCode")
//                 if (errorOutput.isNotEmpty()) Log.w(TAG, "Search stderr: $errorOutput")
                
//                 if (exitCode == 0 && output.isNotEmpty()) {
//                     val results = mutableListOf<Map<String, Any>>()
//                     val lines = output.lines().filter { it.trim().isNotEmpty() }
//                     Log.d(TAG, "Processing ${lines.size} search result lines")
                    
//                     lines.forEach { line ->
//                         try {
//                             val json = JSONObject(line)
//                             val result: Map<String, Any> = mapOf(
//                                 "id" to (json.optString("id", "") as Any),
//                                 "title" to (json.optString("title", "") as Any),
//                                 "uploader" to (json.optString("uploader", "") as Any),
//                                 "duration" to (json.optInt("duration", 0) as Any),
//                                 "viewCount" to (json.optLong("view_count", 0) as Any),
//                                 "url" to ("https://youtube.com/watch?v=${json.optString("id", "")}" as Any),
//                                 "thumbnail" to (getYoutubeThumbnail(json.optString("id", ""), "maxres") as Any)
//                             )
//                             results.add(result)
//                         } catch (e: Exception) {
//                             Log.w(TAG, "Failed to parse search result line: $line", e)
//                         }
//                     }
                    
//                     Log.d(TAG, "Search completed successfully with ${results.size} results")
//                     return@withContext results
//                 } else {
//                     Log.e(TAG, "Search failed - Exit code: $exitCode")
//                     return@withContext null
//                 }
//             } catch (e: Exception) {
//                 Log.e(TAG, "Exception in searchVideos", e)
//                 return@withContext null
//             }
//         }
//     }
    
//     suspend fun getHQStreams(url: String): Map<String, Any?>? {
//         return withContext(Dispatchers.IO) {
//             Log.d(TAG, "Getting HQ streams for URL: $url")
            
//             try {
//                 val command = listOf(
//                     ytDlpPath,
//                     "--dump-json",
//                     "--no-playlist",
//                     "--no-warnings",
//                     url
//                 )
                
//                 Log.d(TAG, "HQ streams command: ${command.joinToString(" ")}")
//                 val processBuilder = createProcessBuilder(command)
//                 val process = processBuilder.start()
                
//                 val output = process.inputStream.bufferedReader().use { it.readText() }
//                 val errorOutput = process.errorStream.bufferedReader().use { it.readText() }
//                 val exitCode = process.waitFor()
                
//                 Log.d(TAG, "HQ streams exit code: $exitCode")
//                 if (errorOutput.isNotEmpty()) Log.w(TAG, "HQ streams stderr: $errorOutput")
                
//                 if (exitCode == 0 && output.isNotEmpty()) {
//                     val json = JSONObject(output)
//                     val formats = json.optJSONArray("formats") ?: JSONArray()
                    
//                     Log.d(TAG, "Found ${formats.length()} formats")
                    
//                     val videoStreams = mutableListOf<Map<String, Any>>()
//                     val audioStreams = mutableListOf<Map<String, Any>>()
                    
//                     for (i in 0 until formats.length()) {
//                         val format = formats.getJSONObject(i)
//                         val formatMap: Map<String, Any> = mapOf(
//                             "formatId" to (format.optString("format_id", "") as Any),
//                             "url" to (format.optString("url", "") as Any),
//                             "ext" to (format.optString("ext", "") as Any),
//                             "quality" to (format.optString("quality", "") as Any),
//                             "resolution" to (format.optString("resolution", "") as Any),
//                             "fps" to (format.optInt("fps", 0) as Any),
//                             "filesize" to (format.optLong("filesize", 0) as Any),
//                             "vcodec" to (format.optString("vcodec", "") as Any),
//                             "acodec" to (format.optString("acodec", "") as Any),
//                             "abr" to (format.optDouble("abr", 0.0) as Any),
//                             "vbr" to (format.optDouble("vbr", 0.0) as Any),
//                             "tbr" to (format.optDouble("tbr", 0.0) as Any),
//                             "width" to (format.optInt("width", 0) as Any),
//                             "height" to (format.optInt("height", 0) as Any),
//                             "formatNote" to (format.optString("format_note", "") as Any),
//                             "protocol" to (format.optString("protocol", "") as Any)
//                         )
                        
//                         val vcodec = format.optString("vcodec", "")
//                         val acodec = format.optString("acodec", "")
                        
//                         if (vcodec != "none" && vcodec.isNotEmpty() && format.optInt("height", 0) > 0) {
//                             videoStreams.add(formatMap)
//                         }
//                         if (acodec != "none" && acodec.isNotEmpty() && format.optDouble("abr", 0.0) > 0) {
//                             audioStreams.add(formatMap)
//                         }
//                     }
                    
//                     // Sort streams by quality
//                     val sortedVideoStreams = videoStreams.sortedByDescending { 
//                         val height = it["height"] as Int
//                         val width = it["width"] as Int
//                         height * width
//                     }
                    
//                     val sortedAudioStreams = audioStreams.sortedByDescending { 
//                         it["abr"] as Double 
//                     }
                    
//                     Log.d(TAG, "Processed ${sortedVideoStreams.size} video streams and ${sortedAudioStreams.size} audio streams")
                    
//                     val result: Map<String, Any?> = mapOf(
//                             "videoStreams" to sortedVideoStreams,
//                             "audioStreams" to sortedAudioStreams,
//                             "bestVideo" to sortedVideoStreams.firstOrNull(),
//                             "bestAudio" to sortedAudioStreams.firstOrNull(),
//                             "availableVideoQualities" to getAvailableVideoQualities(sortedVideoStreams),
//                             "availableAudioQualities" to getAvailableAudioQualities(sortedAudioStreams)
//                     )                
//                     return@withContext result

//                 } else {
//                     Log.e(TAG, "Failed to get HQ streams - Exit code: $exitCode")
//                     return@withContext null
//                 }
//             } catch (e: Exception) {
//                 Log.e(TAG, "Exception in getHQStreams", e)
//                 return@withContext null
//             }
//         }
//     }
    
//     // Dynamic quality switching methods
//     suspend fun getStreamByVideoQuality(url: String, quality: VideoQuality): Map<String, Any?>? {
//         return withContext(Dispatchers.IO) {
//             Log.d(TAG, "Getting stream by video quality: ${quality.description}")
            
//             val allStreams = getHQStreams(url) ?: return@withContext null
//             val videoStreams = allStreams["videoStreams"] as? List<Map<String, Any>> ?: return@withContext null
            
//             val selectedStream = when (quality) {
//                 VideoQuality.QUALITY_BEST -> videoStreams.firstOrNull()
//                 VideoQuality.QUALITY_WORST -> videoStreams.lastOrNull()
//                 else -> {
//                     videoStreams.find { stream ->
//                         val height = stream["height"] as? Int ?: 0
//                         height <= quality.height && height > (quality.height - 240)
//                     } ?: videoStreams.minByOrNull { stream ->
//                         val height = stream["height"] as? Int ?: 0
//                         kotlin.math.abs(height - quality.height)
//                     }
//                 }
//             }
            
//             Log.d(TAG, "Selected video stream: ${selectedStream?.get("formatId")} - ${selectedStream?.get("resolution")}")
            
//             return@withContext mapOf(
//                 "selectedVideoStream" to selectedStream,
//                 "bestAudioStream" to allStreams["bestAudio"]
//             )
//         }
//     }
    
//     suspend fun getStreamByAudioQuality(url: String, quality: AudioQuality): Map<String, Any?>? {
//         return withContext(Dispatchers.IO) {
//             Log.d(TAG, "Getting stream by audio quality: ${quality.description}")
            
//             val allStreams = getHQStreams(url) ?: return@withContext null
//             val audioStreams = allStreams["audioStreams"] as? List<Map<String, Any>> ?: return@withContext null
            
//             val selectedStream = when (quality) {
//                 AudioQuality.QUALITY_BEST -> audioStreams.firstOrNull()
//                 AudioQuality.QUALITY_WORST -> audioStreams.lastOrNull()
//                 else -> {
//                     audioStreams.find { stream ->
//                         val abr = (stream["abr"] as? Double)?.toInt() ?: 0
//                         abr <= quality.bitrate && abr > (quality.bitrate - 64)
//                     } ?: audioStreams.minByOrNull { stream ->
//                         val abr = (stream["abr"] as? Double)?.toInt() ?: 0
//                         kotlin.math.abs(abr - quality.bitrate)
//                     }
//                 }
//             }
            
//             Log.d(TAG, "Selected audio stream: ${selectedStream?.get("formatId")} - ${selectedStream?.get("abr")} kbps")
            
//             return@withContext mapOf(
//                 "selectedAudioStream" to selectedStream,
//                 "bestVideoStream" to allStreams["bestVideo"]
//             )
//         }
//     }
    
//     suspend fun getCustomQualityStreams(url: String, videoQuality: VideoQuality, audioQuality: AudioQuality): Map<String, Any?>? {
//         return withContext(Dispatchers.IO) {
//             Log.d(TAG, "Getting custom quality streams - Video: ${videoQuality.description}, Audio: ${audioQuality.description}")
            
//             val videoStream = getStreamByVideoQuality(url, videoQuality)
//             val audioStream = getStreamByAudioQuality(url, audioQuality)
            
//             return@withContext mapOf(
//                 "selectedVideoStream" to videoStream?.get("selectedVideoStream"),
//                 "selectedAudioStream" to audioStream?.get("selectedAudioStream")
//             )
//         }
//     }
    
//     suspend fun batchGetThumbnails(videoIds: List<String>, quality: String = "maxres"): Map<String, String> {
//         return withContext(Dispatchers.IO) {
//             Log.d(TAG, "Batch getting thumbnails for ${videoIds.size} videos with quality: $quality")
            
//             val thumbnails = mutableMapOf<String, String>()
//             val chunkSize = 20
//             val chunks = videoIds.chunked(chunkSize)
            
//             Log.d(TAG, "Processing thumbnails in ${chunks.size} chunks of $chunkSize")
            
//             chunks.forEachIndexed { chunkIndex, chunk ->
//                 Log.d(TAG, "Processing chunk ${chunkIndex + 1}/${chunks.size}")
                
//                 val jobs = chunk.map { videoId ->
//                     async {
//                         val cached = thumbnailCache[videoId]
//                         if (cached != null) {
//                             Log.v(TAG, "Using cached thumbnail for video: $videoId")
//                             videoId to cached
//                         } else {
//                             val thumbnail = getYoutubeThumbnail(videoId, quality)
//                             thumbnailCache[videoId] = thumbnail
//                             Log.v(TAG, "Generated thumbnail for video: $videoId")
//                             videoId to thumbnail
//                         }
//                     }
//                 }
                
//                 jobs.awaitAll().forEach { (id, thumbnail) ->
//                     thumbnails[id] = thumbnail
//                 }
//             }
            
//             Log.d(TAG, "Batch thumbnail processing completed - Generated ${thumbnails.size} thumbnails")
//             return@withContext thumbnails
//         }
//     }
    
//     suspend fun getChannelInfo(channelUrl: String): Map<String, Any>? {
//         return withContext(Dispatchers.IO) {
//             Log.d(TAG, "Getting channel info for URL: $channelUrl")
            
//             try {
//                 val command = listOf(
//                     ytDlpPath,
//                     "--dump-json",
//                     "--playlist-items", "0",
//                     "--no-warnings",
//                     channelUrl
//                 )
                
//                 Log.d(TAG, "Channel info command: ${command.joinToString(" ")}")
//                 val process = ProcessBuilder(command).start()
                
//                 val output = process.inputStream.bufferedReader().use { it.readText() }
//                 val errorOutput = process.errorStream.bufferedReader().use { it.readText() }
//                 val exitCode = process.waitFor()
                
//                 Log.d(TAG, "Channel info exit code: $exitCode")
//                 if (errorOutput.isNotEmpty()) Log.w(TAG, "Channel info stderr: $errorOutput")
                
//                 if (exitCode == 0 && output.isNotEmpty()) {
//                     val json = JSONObject(output)
//                     val result: Map<String, Any> = mapOf(
//                         "id" to (json.optString("id", "") as Any),
//                         "title" to (json.optString("title", "") as Any),
//                         "description" to (json.optString("description", "") as Any),
//                         "subscriberCount" to (json.optLong("subscriber_count", 0) as Any),
//                         "videoCount" to (json.optLong("video_count", 0) as Any),
//                         "thumbnail" to (getBestThumbnail(json) as Any),
//                         "bannerUrl" to (json.optString("banner_url", "") as Any),
//                         "avatarUrl" to (getChannelAvatar(json) as Any),
//                         "verified" to (json.optBoolean("verified", false) as Any)
//                     )
                    
//                     Log.d(TAG, "Channel info retrieved successfully - Title: ${result["title"]}")
//                     return@withContext result
//                 } else {
//                     Log.e(TAG, "Failed to get channel info - Exit code: $exitCode")
//                     return@withContext null
//                 }
//             } catch (e: Exception) {
//                 Log.e(TAG, "Exception in getChannelInfo", e)
//                 return@withContext null
//             }
//         }
//     }
    
//     // Helper functions
//     private fun getBestThumbnail(json: JSONObject): String {
//         val thumbnails = json.optJSONArray("thumbnails")
//         if (thumbnails != null && thumbnails.length() > 0) {
//             for (i in thumbnails.length() - 1 downTo 0) {
//                 val thumbnail = thumbnails.getJSONObject(i)
//                 val url = thumbnail.optString("url", "")
//                 if (url.isNotEmpty()) {
//                     Log.v(TAG, "Selected thumbnail: $url")
//                     return url
//                 }
//             }
//         }
//         val fallback = json.optString("thumbnail", "")
//         Log.v(TAG, "Using fallback thumbnail: $fallback")
//         return fallback
//     }
    
//     private fun getUploaderAvatar(json: JSONObject): String {
//         val avatar = json.optString("uploader_avatar_url", 
//             json.optString("channel_avatar_url",
//                 json.optString("uploader_thumbnail", "")))
//         Log.v(TAG, "Uploader avatar: $avatar")
//         return avatar
//     }
    
//     private fun getChannelAvatar(json: JSONObject): String {
//         val thumbnails = json.optJSONArray("thumbnails")
//         if (thumbnails != null && thumbnails.length() > 0) {
//             val thumbnail = thumbnails.getJSONObject(0)
//             val url = thumbnail.optString("url", "")
//             Log.v(TAG, "Channel avatar: $url")
//             return url
//         }
//         return ""
//     }
    
//     private fun getYoutubeThumbnail(videoId: String, quality: String): String {
//         val url = when (quality) {
//             "maxres" -> "https://i.ytimg.com/vi/$videoId/maxresdefault.jpg"
//             "high" -> "https://i.ytimg.com/vi/$videoId/hqdefault.jpg"
//             "medium" -> "https://i.ytimg.com/vi/$videoId/mqdefault.jpg"
//             "standard" -> "https://i.ytimg.com/vi/$videoId/sddefault.jpg"
//             else -> "https://i.ytimg.com/vi/$videoId/hqdefault.jpg"
//         }
//         Log.v(TAG, "Generated thumbnail URL for $videoId: $url")
//         return url
//     }
    
//     private fun getTagsList(json: JSONObject): List<String> {
//         val tags = json.optJSONArray("tags") ?: return emptyList()
//         val tagsList = mutableListOf<String>()
//         for (i in 0 until tags.length()) {
//             tagsList.add(tags.getString(i))
//         }
//         Log.v(TAG, "Found ${tagsList.size} tags")
//         return tagsList
//     }
    
//     private fun getCategoriesList(json: JSONObject): List<String> {
//         val categories = json.optJSONArray("categories") ?: return emptyList()
//         val categoriesList = mutableListOf<String>()
//         for (i in 0 until categories.length()) {
//             categoriesList.add(categories.getString(i))
//         }
//         Log.v(TAG, "Found ${categoriesList.size} categories")
//         return categoriesList
//     }
    
//     private fun getAvailableVideoQualities(videoStreams: List<Map<String, Any>>): List<Map<String, Any>> {
//         val qualities = mutableSetOf<Int>()
//         videoStreams.forEach { stream ->
//             val height = stream["height"] as? Int ?: 0
//             if (height > 0) qualities.add(height)
//         }
        
//         return qualities.sorted().map { height ->
//             mapOf(
//                 "height" to height,
//                 "description" to "${height}p",
//                 "available" to true
//             )
//         }
//     }
    
//     private fun getAvailableAudioQualities(audioStreams: List<Map<String, Any>>): List<Map<String, Any>> {
//         val qualities = mutableSetOf<Int>()
//         audioStreams.forEach { stream ->
//             val abr = (stream["abr"] as? Double)?.toInt() ?: 0
//             if (abr > 0) qualities.add(abr)
//         }
        
//         return qualities.sorted().map { bitrate ->
//             mapOf(
//                 "bitrate" to bitrate,
//                 "description" to "${bitrate} kbps",
//                 "available" to true
//             )
//         }
//     }
    
//     // Utility function to clear thumbnail cache if needed
//     fun clearThumbnailCache() {
//         Log.d(TAG, "Clearing thumbnail cache - ${thumbnailCache.size} items")
//         thumbnailCache.clear()
//     }
    
//     // Get current cache size
//     fun getThumbnailCacheSize(): Int {
//         return thumbnailCache.size
//     }
// }