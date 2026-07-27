package com.krce.bus.api

import android.util.Log
import com.krce.bus.BuildConfig
import kotlinx.coroutines.*
import okhttp3.*

/**
 * WebSocket manager for real-time GPS and alert updates.
 *
 * - URL is read from BuildConfig.WS_BASE_URL (set via gradle.properties).
 *   No hardcoded IP addresses anywhere in this file.
 * - Automatically reconnects on failure with a 5-second delay.
 * - In production the URL starts with wss:// (TLS).
 * - In local dev the URL starts with ws:// (matches Android emulator localhost).
 */
class WebSocketManager(private val token: String) {

    private var webSocket: WebSocket? = null
    
    // I-20: Singleton OkHttpClient at class level
    companion object {
        private val client = OkHttpClient.Builder()
            .retryOnConnectionFailure(true)
            .build()
    }

    // I-19: Proper coroutine scope for reconnection
    private val managerScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var messageCallback: ((String) -> Unit)? = null
    private var isRunning = false

    // WS_BASE_URL comes from BuildConfig — "ws://..." for dev, "wss://..." for production
    private val wsUrl: String
        get() = "${BuildConfig.WS_BASE_URL}ws?token=$token"

    fun connect(onMessageReceived: (String) -> Unit) {
        messageCallback = onMessageReceived
        isRunning = true
        openSocket()
    }

    private fun openSocket() {
        val request = Request.Builder().url(wsUrl).build()
        val listener = object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d("WebSocket", "Connected to $wsUrl")
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                Log.d("WebSocket", "Received: $text")
                messageCallback?.invoke(text)
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                webSocket.close(1000, null)
                Log.d("WebSocket", "Closing: $code / $reason")
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e("WebSocket", "Connection failed: ${t.message}")
                if (isRunning) {
                    // I-19: Use managerScope instead of orphaned CoroutineScope(Dispatchers.IO)
                    managerScope.launch {
                        delay(5000)
                        if (isRunning) {
                            Log.d("WebSocket", "Attempting reconnect...")
                            openSocket()
                        }
                    }
                }
            }
        }
        webSocket = client.newWebSocket(request, listener)
    }

    fun send(message: String) {
        webSocket?.send(message)
    }

    fun close() {
        isRunning = false
        webSocket?.close(1000, "User disconnected")
        webSocket = null
        managerScope.cancel()
    }
}
