// // WebViewDownloader.kt - New file to handle YouTube integrity checks
// package com.example.sinkplayer

// import android.content.Context
// import android.os.Handler
// import android.os.Looper
// import android.webkit.WebView
// import android.webkit.WebViewClient
// import android.webkit.WebSettings
// import okhttp3.OkHttpClient
// import okhttp3.Request
// import okhttp3.Headers
// import okhttp3.MediaType.Companion.toMediaType
// import okhttp3.RequestBody.Companion.toRequestBody
// import org.schabi.newpipe.extractor.downloader.Downloader
// import org.schabi.newpipe.extractor.downloader.Response
// import java.util.concurrent.TimeUnit
// import java.util.concurrent.CountDownLatch
// import java.util.concurrent.atomic.AtomicReference

// class WebViewDownloader(
//     private val context: Context,
//     private val isMobile: Boolean = true
// ) : Downloader() {
    
//     private val client = OkHttpClient.Builder()
//         .connectTimeout(45, TimeUnit.SECONDS)
//         .readTimeout(45, TimeUnit.SECONDS)
//         .writeTimeout(45, TimeUnit.SECONDS)
//         .addInterceptor { chain ->
//             val request = chain.request()
//             val modifiedRequest = request.newBuilder()
//                 .headers(generateAdvancedHeaders(request.url.toString()))
//                 .build()
//             chain.proceed(modifiedRequest)
//         }
//         .build()

//     companion object {
//         private var cachedIntegrityToken: String? = null
//         private var tokenTimestamp: Long = 0
//         private const val TOKEN_EXPIRY_MS = 30 * 60 * 1000L // 30 minutes

//         fun generateAdvancedHeaders(url: String): Headers {
//             val headers = Headers.Builder()
            
//             // More comprehensive headers for YouTube
//             headers.add("User-Agent", "Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
//             headers.add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8")
//             headers.add("Accept-Language", "en-US,en;q=0.9")
//             headers.add("Accept-Encoding", "gzip, deflate, br")
//             headers.add("Connection", "keep-alive")
//             headers.add("DNT", "1")
//             headers.add("Upgrade-Insecure-Requests", "1")
//             headers.add("Sec-Fetch-Dest", "document")
//             headers.add("Sec-Fetch-Mode", "navigate")
//             headers.add("Sec-Fetch-Site", "none")
//             headers.add("Sec-Fetch-User", "?1")
//             headers.add("Cache-Control", "max-age=0")

//             // YouTube-specific headers
//             if (url.contains("youtube.com") || url.contains("youtu.be") || url.contains("googlevideo.com")) {
//                 headers.add("Referer", "https://www.youtube.com/")
//                 headers.add("Origin", "https://www.youtube.com")
                
//                 // Updated YouTube client headers for 2025
//                 headers.add("X-YouTube-Client-Name", "1")
//                 headers.add("X-YouTube-Client-Version", "2.20250702.00.00")
//                 headers.add("X-YouTube-Page-CL", "634414992")
//                 headers.add("X-YouTube-Page-Label", "youtube.desktop.web_20250702_00_RC00")
//                 headers.add("X-YouTube-Utc-Offset", "0")
//                 headers.add("X-YouTube-Time-Zone", "UTC")
//                 headers.add("X-YouTube-Ad-Signals", "dt=1720000000000&flash=0&frm&u_tz=0&u_his=2")
                
//                 // Add cached integrity token if available
//                 cachedIntegrityToken?.let { token ->
//                     if (System.currentTimeMillis() - tokenTimestamp < TOKEN_EXPIRY_MS) {
//                         headers.add("X-Goog-Visitor-Id", token)
//                     }
//                 }
//             }

//             return headers.build()
//         }
//     }

//     override fun execute(request: org.schabi.newpipe.extractor.downloader.Request): Response {
//         return try {
//             // For YouTube requests, try to get integrity token first
//             if (request.url().contains("youtube.com") && shouldRefreshToken()) {
//                 getIntegrityToken()
//             }

//             val requestBuilder = Request.Builder()
//                 .url(request.url())
//                 .headers(generateAdvancedHeaders(request.url()))

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

//             Response(
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

//     private fun shouldRefreshToken(): Boolean {
//         return cachedIntegrityToken == null || 
//                (System.currentTimeMillis() - tokenTimestamp) > TOKEN_EXPIRY_MS
//     }

//     private fun getIntegrityToken() {
//         try {
//             val latch = CountDownLatch(1)
//             val tokenRef = AtomicReference<String?>()

//             Handler(Looper.getMainLooper()).post {
//                 try {
//                     val webView = WebView(context)
//                     webView.settings.apply {
//                         javaScriptEnabled = true
//                         domStorageEnabled = true
//                         cacheMode = WebSettings.LOAD_DEFAULT
//                         userAgentString = "Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36"
//                     }

//                     webView.webViewClient = object : WebViewClient() {
//                         override fun onPageFinished(view: WebView?, url: String?) {
//                             super.onPageFinished(view, url)
                            
//                             // Extract visitor ID or integrity token from the page
//                             webView.evaluateJavascript(
//                                 """
//                                 (function() {
//                                     try {
//                                         // Try to get visitor ID from ytcfg
//                                         if (window.ytcfg && window.ytcfg.get) {
//                                             var visitorData = window.ytcfg.get('VISITOR_DATA');
//                                             if (visitorData) return visitorData;
//                                         }
                                        
//                                         // Try to get from ytInitialData
//                                         if (window.ytInitialData && window.ytInitialData.responseContext) {
//                                             var visitorData = window.ytInitialData.responseContext.visitorData;
//                                             if (visitorData) return visitorData;
//                                         }
                                        
//                                         // Try to get from any global variable
//                                         var scripts = document.getElementsByTagName('script');
//                                         for (var i = 0; i < scripts.length; i++) {
//                                             var content = scripts[i].innerHTML;
//                                             var match = content.match(/"VISITOR_DATA":"([^"]+)"/);
//                                             if (match) return match[1];
//                                         }
                                        
//                                         return null;
//                                     } catch (e) {
//                                         return null;
//                                     }
//                                 })();
//                                 """.trimIndent()
//                             ) { result ->
//                                 if (result != null && result != "null" && result.length > 2) {
//                                     val token = result.replace("\"", "")
//                                     tokenRef.set(token)
//                                     cachedIntegrityToken = token
//                                     tokenTimestamp = System.currentTimeMillis()
//                                 }
//                                 latch.countDown()
//                             }
//                         }

//                         override fun onReceivedError(view: WebView?, errorCode: Int, description: String?, failingUrl: String?) {
//                             super.onReceivedError(view, errorCode, description, failingUrl)
//                             latch.countDown()
//                         }
//                     }

//                     webView.loadUrl("https://www.youtube.com")
                    
//                     // Timeout after 10 seconds
//                     Handler(Looper.getMainLooper()).postDelayed({
//                         latch.countDown()
//                     }, 10000)

//                 } catch (e: Exception) {
//                     latch.countDown()
//                 }
//             }

//             // Wait for WebView to complete or timeout
//             latch.await(15, TimeUnit.SECONDS)

//         } catch (e: Exception) {
//             // If WebView fails, continue without integrity token
//         }
//     }

//     private fun org.schabi.newpipe.extractor.downloader.Request.dataToPost(): String? {
//         return try {
//             val field = this.javaClass.getDeclaredField("postBody")
//             field.isAccessible = true
//             field.get(this) as? String
//         } catch (e: Exception) {
//             if (this.url().contains("?")) {
//                 this.url().substringAfter("?")
//             } else {
//                 null
//             }
//         }
//     }
// }