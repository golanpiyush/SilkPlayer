// package com.example.sinkplayer

// import okhttp3.OkHttpClient
// import okhttp3.Request
// import okhttp3.Headers
// import okhttp3.MediaType.Companion.toMediaType
// import okhttp3.RequestBody.Companion.toRequestBody
// import org.schabi.newpipe.extractor.downloader.Downloader
// import org.schabi.newpipe.extractor.downloader.Response
// import java.util.concurrent.TimeUnit

// class CustomDownloader(private val isMobile: Boolean = true) : Downloader() {
//     private val client = OkHttpClient.Builder()
//         .connectTimeout(30, TimeUnit.SECONDS)
//         .readTimeout(30, TimeUnit.SECONDS)
//         .writeTimeout(30, TimeUnit.SECONDS)
//         .addInterceptor { chain ->
//             val request = chain.request()
//             val modifiedRequest = request.newBuilder()
//                 .headers(generateYouTubeHeaders(isMobile, request.url.toString()))
//                 .build()
//             chain.proceed(modifiedRequest)
//         }
//         .build()

//     companion object {
//         fun generateYouTubeHeaders(isMobile: Boolean, url: String): Headers {
//             val headers = Headers.Builder()
            
//             // Add platform-specific user agent
//             val userAgent = if (isMobile) {
//                 "Mozilla/5.0 (Linux; Android 10; Pixel 4) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
//             } else {
//                 "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
//             }
            
//             headers.add("User-Agent", userAgent)
//             headers.add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8")
//             headers.add("Accept-Language", "en-US,en;q=0.9")
//             headers.add("Accept-Encoding", "gzip, deflate, br")
//             headers.add("Connection", "keep-alive")
//             headers.add("DNT", "1")
//             headers.add("Upgrade-Insecure-Requests", "1")
//             headers.add("X-Requested-With", "com.example.sinkplayer")

//             // YouTube-specific headers
//             if (url.contains("youtube.com") || url.contains("youtu.be")) {
//                 headers.add("Referer", "https://www.youtube.com/")
//                 headers.add("Origin", "https://www.youtube.com")
//                 headers.add("X-YouTube-Client-Name", "1")
//                 headers.add("X-YouTube-Client-Version", "2.20250701.00.00")
//                 headers.add("X-YouTube-Page-CL", if (isMobile) "mweb" else "desktop")
//                 headers.add("X-YouTube-Page-Label", if (isMobile) "mweb-main" else "desktop-main")
//                 headers.add("X-YouTube-Device", if (isMobile) "mobile" else "desktop")
//                 headers.add("X-YouTube-Utc-Offset", "0")
//                 headers.add("X-YouTube-Time-Zone", "UTC")
//             }

//             return headers.build()
//         }
//     }

//     override fun execute(request: org.schabi.newpipe.extractor.downloader.Request): Response {
//         try {
//             val requestBuilder = Request.Builder()
//                 .url(request.url())
//                 .headers(generateYouTubeHeaders(isMobile, request.url()))

//             when (request.httpMethod()) {
//                 "POST" -> {
//                     val postBody = request.dataToPost() ?: ""
//                     val mediaType = "application/x-www-form-urlencoded".toMediaType()
//                     requestBuilder.post(postBody.toRequestBody(mediaType))
//                 }
//                 "HEAD" -> requestBuilder.head()
//                 else -> requestBuilder.get()
//             }

//             val okHttpRequest = requestBuilder.build()
//             val response = client.newCall(okHttpRequest).execute()
//             val body = response.body?.string() ?: ""

//             return Response(
//                 response.code,
//                 response.message,
//                 response.headers.toMultimap(),
//                 body,
//                 request.url()
//             )
//         } catch (e: Exception) {
//             throw Exception("Network request failed: ${e.message}", e)
//         }
//     }

//     private fun org.schabi.newpipe.extractor.downloader.Request.dataToPost(): String? {
//         return try {
//             // Try to access the postBody field through reflection
//             val field = this.javaClass.getDeclaredField("postBody")
//             field.isAccessible = true
//             field.get(this) as? String
//         } catch (e: Exception) {
//             // Fallback to parsing from URL if available
//             if (this.url().contains("?")) {
//                 this.url().substringAfter("?")
//             } else {
//                 null
//             }
//         }
//     }
// }