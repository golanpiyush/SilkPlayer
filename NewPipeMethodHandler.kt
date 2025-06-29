package com.example.sinkplayer

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.schabi.newpipe.extractor.NewPipe
import org.schabi.newpipe.extractor.stream.StreamInfoItem
import org.schabi.newpipe.extractor.stream.StreamExtractor
import org.schabi.newpipe.extractor.channel.ChannelExtractor
import org.schabi.newpipe.extractor.localization.DateWrapper
import com.example.sinkplayer.CustomDownloader
import java.text.SimpleDateFormat
import java.util.*

class NewPipeMethodHandler(private val flutterEngine: FlutterEngine) {
    fun register() {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.yourapp.newpipe")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTrendingVideos" -> getTrendingVideos(result)
                    "getVideosByInterest" -> {
                        val tag = call.argument<String>("tag") ?: ""
                        getVideosByInterest(tag, result)
                    }
                    "getDetailedVideoInfo" -> {
                        val videoId = call.argument<String>("videoId") ?: ""
                        getDetailedVideoInfo(videoId, result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun getTrendingVideos(result: MethodChannel.Result) {
        Thread {
            try {
                NewPipe.init(CustomDownloader())
                val service = NewPipe.getService("YouTube")
                
                // First try to get trending videos
                try {
                    val kioskList = service.kioskList
                    val trendingExtractor = kioskList.getExtractorById("Trending", null)
                    trendingExtractor.fetchPage()

                    val infoList = trendingExtractor.initialPage.items
                    val mapped = infoList
                        .filterIsInstance<StreamInfoItem>()
                        .take(10)
                        .map { mapBasicVideo(it) }

                    Handler(Looper.getMainLooper()).post {
                        result.success(mapped)
                    }
                } catch (trendingError: Exception) {
                    // Fallback: Try searching for popular terms instead
                    println("Trending failed, falling back to search: ${trendingError.message}")
                    
                    val searchExtractor = service.getSearchExtractor("music 2024 hindi", listOf(), "")
                    searchExtractor.fetchPage()

                    val infoList = searchExtractor.initialPage.items
                    val mapped = infoList
                        .filterIsInstance<StreamInfoItem>()
                        .take(10)
                        .map { mapBasicVideo(it) }

                    Handler(Looper.getMainLooper()).post {
                        result.success(mapped)
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
                Handler(Looper.getMainLooper()).post {
                    result.error("NEWPIPE_ERROR", e.message, null)
                }
            }
        }.start()
    }

    private fun getVideosByInterest(tag: String, result: MethodChannel.Result) {
        Thread {
            try {
                NewPipe.init(CustomDownloader())
                val service = NewPipe.getService("YouTube")
                val searchExtractor = service.getSearchExtractor(tag, listOf(), "")
                searchExtractor.fetchPage()

                val infoList = searchExtractor.initialPage.items
                val mapped = infoList
                    .filterIsInstance<StreamInfoItem>()
                    .take(10)
                    .map { mapBasicVideo(it) }

                Handler(Looper.getMainLooper()).post {
                    result.success(mapped)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                Handler(Looper.getMainLooper()).post {
                    result.error("NEWPIPE_ERROR", e.message, null)
                }
            }
        }.start()
    }

    private fun getDetailedVideoInfo(videoId: String, result: MethodChannel.Result) {
        Thread {
            try {
                NewPipe.init(CustomDownloader())
                val service = NewPipe.getService("YouTube")
                
                val videoUrl = "https://www.youtube.com/watch?v=$videoId"
                val streamExtractor = service.getStreamExtractor(videoUrl)
                streamExtractor.fetchPage()

                val videoMap = mapDetailedVideo(streamExtractor)

                Handler(Looper.getMainLooper()).post {
                    result.success(videoMap)
                }
            } catch (e: Exception) {
                e.printStackTrace()
                Handler(Looper.getMainLooper()).post {
                    result.error("NEWPIPE_ERROR", e.message, null)
                }
            }
        }.start()
    }

    private fun mapBasicVideo(item: StreamInfoItem): Map<String, Any?> {
        return mapOf(
            "id" to extractVideoId(item.url),
            "title" to item.name,
            "author" to (item.uploaderName ?: "Unknown"),
            "channelId" to extractChannelId(item.uploaderUrl),
            "description" to "", // Not available in basic info
            "duration" to (item.duration ?: 0L),
            "thumbnailUrl" to getBestThumbnail(item),
            "viewCount" to (item.viewCount ?: 0L),
            "uploadDate" to null, // Not always available in basic info
            "uploaderAvatarUrl" to null, // Requires channel info
            "isVerified" to false // Requires channel info
        )
    }

    private fun mapDetailedVideo(extractor: StreamExtractor): Map<String, Any?> {
        return mapOf(
            "id" to extractVideoId(extractor.url),
            "title" to extractor.name,
            "author" to (extractor.uploaderName ?: "Unknown"),
            "channelId" to extractChannelId(extractor.uploaderUrl),
            "description" to (extractor.description?.content ?: ""),
            "duration" to (extractor.length ?: 0L),
            "thumbnailUrl" to getBestThumbnailFromExtractor(extractor),
            "viewCount" to (extractor.viewCount ?: 0L),
            "uploadDate" to formatUploadDate(extractor.uploadDate),
            "uploaderAvatarUrl" to getBestUploaderAvatar(extractor),
            "isVerified" to (extractor.isUploaderVerified ?: false)
        )
    }

    private fun extractVideoId(url: String): String {
        return when {
            url.contains("v=") -> url.substringAfter("v=").substringBefore("&")
            url.contains("/watch/") -> url.substringAfter("/watch/").substringBefore("?")
            url.contains("youtu.be/") -> url.substringAfter("youtu.be/").substringBefore("?")
            else -> url.substringAfterLast("/")
        }
    }

    private fun extractChannelId(uploaderUrl: String?): String {
        if (uploaderUrl == null) return ""
        return when {
            uploaderUrl.contains("/channel/") -> uploaderUrl.substringAfter("/channel/").substringBefore("?")
            uploaderUrl.contains("/c/") -> uploaderUrl.substringAfter("/c/").substringBefore("?")
            uploaderUrl.contains("/user/") -> uploaderUrl.substringAfter("/user/").substringBefore("?")
            else -> ""
        }
    }

    private fun getBestThumbnail(item: StreamInfoItem): String {
        return try {
            val thumbnails = item.thumbnails
            if (thumbnails.isNotEmpty()) {
                thumbnails.maxByOrNull { it.width * it.height }?.url ?: ""
            } else {
                ""
            }
        } catch (e: Exception) {
            ""
        }
    }

    private fun getBestThumbnailFromExtractor(extractor: StreamExtractor): String {
        return try {
            val thumbnails = extractor.thumbnails
            if (thumbnails.isNotEmpty()) {
                thumbnails.maxByOrNull { it.width * it.height }?.url ?: ""
            } else {
                ""
            }
        } catch (e: Exception) {
            ""
        }
    }

    private fun getBestUploaderAvatar(extractor: StreamExtractor): String? {
        return try {
            val avatars = extractor.uploaderAvatars
            if (avatars.isNotEmpty()) {
                avatars.maxByOrNull { it.width * it.height }?.url
            } else {
                null
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun formatUploadDate(uploadDate: Any?): String? {
        return try {
            when (uploadDate) {
                is DateWrapper -> uploadDate.offsetDateTime()?.toString()
                is String -> uploadDate
                else -> uploadDate?.toString()
            }
        } catch (e: Exception) {
            null
        }
    }
}