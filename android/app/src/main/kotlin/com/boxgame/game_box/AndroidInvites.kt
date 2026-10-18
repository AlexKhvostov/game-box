package com.best4u.untouch

import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

/** Bounded durable delivery only; validation/binding/rewards remain on the server. */
class AndroidInvites(context: Context, private val channel: MethodChannel) {
    private val appContext = context.applicationContext
    private val preferences = appContext.getSharedPreferences("untouch_invite_links_v1", Context.MODE_PRIVATE)
    private val handler = Handler(Looper.getMainLooper())
    private var referrerBusy = false
    private var disposed = false
    private var referrerClient: InstallReferrerClient? = null
    private val allowedPath = Regex("^/a/(?:[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}|[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{12})/?$", RegexOption.IGNORE_CASE)

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "peekAppLink" -> result.success(queue().optString(0).takeIf { it.isNotEmpty() })
                "ackAppLink" -> {
                    val items = queue()
                    if (items.optString(0) == call.argument<String>("url")) {
                        items.remove(0)
                        if (!preferences.edit().putString("queue", items.toString()).commit()) {
                            result.error("invite_storage_failed", "Delivery was not acknowledged", null)
                            return@setMethodCallHandler
                        }
                    }
                    result.success(null)
                }
                "readReferrer" -> readReferrer(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun queue(): JSONArray = try {
        JSONArray(preferences.getString("queue", "[]"))
    } catch (_: Exception) { JSONArray() }

    fun capture(value: String?) {
        if (disposed) return
        if (value == null || value.length > 2048) return
        val uri = Uri.parse(value)
        if (uri.scheme != "https" || uri.host !in setOf("untouch.fun", "untouch-android-game-box-b30d4.web.app") || uri.port != -1 ||
            uri.userInfo != null || uri.query != null || uri.fragment != null ||
            !allowedPath.matches(uri.encodedPath ?: "")) return
        val items = queue()
        for (index in 0 until items.length()) if (items.optString(index) == value) return
        if (items.length() >= 16) return // Intent flood bound, not a referral/reward limit.
        items.put(value)
        if (preferences.edit().putString("queue", items.toString()).commit()) {
            channel.invokeMethod("appLinkAvailable", null)
        }
    }

    private fun readReferrer(result: MethodChannel.Result) {
        if (referrerBusy) { result.success(mapOf("status" to "retry")); return }
        referrerBusy = true
        val client = InstallReferrerClient.newBuilder(appContext).build()
        referrerClient = client
        var replied = false
        lateinit var timeout: Runnable
        fun finish(status: String, value: String? = null) {
            if (replied) return
            replied = true
            referrerBusy = false
            referrerClient = null
            handler.removeCallbacks(timeout)
            try { client.endConnection() } catch (_: Exception) { }
            if (!disposed) result.success(mapOf("status" to status, "value" to value))
        }
        timeout = Runnable { finish("retry") }
        handler.postDelayed(timeout, 8000)
        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    handler.post {
                        if (replied || disposed) return@post
                        when (responseCode) {
                            InstallReferrerClient.InstallReferrerResponse.OK -> {
                                try {
                                    val value = client.installReferrer.installReferrer
                                    if (value.length > 4096) finish("absent") else finish("available", value)
                                } catch (_: Exception) { finish("retry") }
                            }
                            InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED,
                            InstallReferrerClient.InstallReferrerResponse.DEVELOPER_ERROR -> finish("absent")
                            else -> finish("retry")
                        }
                    }
                }
                override fun onInstallReferrerServiceDisconnected() { handler.post { finish("retry") } }
            })
        } catch (_: Exception) { finish("retry") }
    }

    fun dispose() {
        disposed = true
        channel.setMethodCallHandler(null)
        handler.removeCallbacksAndMessages(null)
        try { referrerClient?.endConnection() } catch (_: Exception) { }
        referrerClient = null
        referrerBusy = false
    }
}
