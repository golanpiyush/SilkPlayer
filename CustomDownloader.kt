package com.example.sinkplayer

import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Headers
import org.schabi.newpipe.extractor.downloader.Downloader
import org.schabi.newpipe.extractor.downloader.Response
import java.util.concurrent.TimeUnit

class CustomDownloader : Downloader() {
    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(30, TimeUnit.SECONDS)
        .build()

    override fun execute(request: org.schabi.newpipe.extractor.downloader.Request): Response {
        // Convert headers from Map<String, List<String>> to Headers
        val headersBuilder = Headers.Builder()
        
        // Add default headers that mimic a real browser
        headersBuilder.add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36")
        headersBuilder.add("Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8")
        headersBuilder.add("Accept-Language", "en-US,en;q=0.9")
        headersBuilder.add("Accept-Encoding", "gzip, deflate, br")
        headersBuilder.add("DNT", "1")
        headersBuilder.add("Connection", "keep-alive")
        headersBuilder.add("Upgrade-Insecure-Requests", "1")
        headersBuilder.add("Sec-Fetch-Dest", "document")
        headersBuilder.add("Sec-Fetch-Mode", "navigate")
        headersBuilder.add("Sec-Fetch-Site", "none")
        headersBuilder.add("Sec-Fetch-User", "?1")
        headersBuilder.add("Cache-Control", "max-age=0")
        
        // Add custom headers from the request (these may override defaults)
        request.headers().forEach { (key, values) ->
            values.forEach { value ->
                headersBuilder.add(key, value)
            }
        }

        val okHttpRequest = Request.Builder()
            .url(request.url())
            .headers(headersBuilder.build())
            .build()

        val response = client.newCall(okHttpRequest).execute()
        val body = response.body?.string() ?: ""

        // Convert response headers to the format expected by NewPipe Response
        val responseHeaders = mutableMapOf<String, MutableList<String>>()
        response.headers.forEach { pair ->
            val headerName = pair.first
            val headerValue = pair.second
            
            if (responseHeaders.containsKey(headerName)) {
                responseHeaders[headerName]?.add(headerValue)
            } else {
                responseHeaders[headerName] = mutableListOf(headerValue)
            }
        }

        return Response(
            response.code,
            response.message,
            responseHeaders,
            body,
            request.url()
        )
    }
}