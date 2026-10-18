package com.best4u.untouch

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.net.Uri
import android.os.Build
import io.flutter.embedding.engine.FlutterShellArgs

class MainActivity : FlutterActivity() {
    private var invites: AndroidInvites? = null

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        invites?.capture(intent.dataString)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        invites?.dispose()
        invites = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
    override fun getFlutterShellArgs(): FlutterShellArgs {
        val args = super.getFlutterShellArgs()
        // Physical MAR-LX1M profiling found long Skia shader compilation stalls
        // on sheet entrance. Impeller/OpenGLES was tested on this device; keep
        // the manifest's legacy fallback for other, unverified Android GPUs.
        if (Build.VERSION.SDK_INT >= 29 &&
            Build.MANUFACTURER.equals("HUAWEI", ignoreCase = true) &&
            Build.MODEL.replace('_', '-') == "MAR-LX1M") {
            args.add("--enable-impeller=true")
        }
        return args
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        invites = AndroidInvites(this, MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "untouch/invites"))
        invites?.capture(intent?.dataString)
        // Only fixed public destinations; account credentials never enter a URL.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "untouch/support")
            .setMethodCallHandler { call, result ->
                if (call.method != "openPage") {
                    result.notImplemented()
                } else {
                    val russian = call.argument<String>("language") == "ru"
                    val fragment = if (russian) "" else "#english"
                    val url = when (call.argument<String>("page")) {
                        "privacy", "support" -> "https://untouch-android-game-box-b30d4.web.app/privacy/$fragment"
                        "deletion" -> "https://untouch-android-game-box-b30d4.web.app/delete-account/$fragment"
                        else -> null
                    }
                    if (url == null) {
                        result.error("invalid_page", "Unknown support page", null)
                    } else {
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("browser_unavailable", "Browser unavailable", null)
                        }
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "untouch/adPrivacy")
            .setMethodCallHandler { call, result ->
                if (call.method != "openPolicy") {
                    result.notImplemented()
                } else {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(
                            "https://yandex.com/legal/confidential/"
                        )))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("browser_unavailable", "Browser unavailable", null)
                    }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "untouch/store")
            .setMethodCallHandler { call, result ->
                if (call.method != "manageSubscription") {
                    result.notImplemented()
                } else {
                    try {
                        val productId = (call.arguments as? Map<*, *>)?.get("productId") as? String
                        val knownSubscriptions = setOf(
                            "plus_weekly", "energy_batteries_2_v1", "energy_batteries_5_v1"
                        )
                        val uri = Uri.Builder()
                            .scheme("https")
                            .authority("play.google.com")
                            .path("/store/account/subscriptions")
                            .apply {
                                if (productId != null && productId in knownSubscriptions) {
                                    appendQueryParameter("sku", productId)
                                    appendQueryParameter("package", packageName)
                                }
                            }
                            .build()
                        startActivity(Intent(Intent.ACTION_VIEW, uri))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("store_unavailable", "Google Play unavailable", null)
                    }
                }
            }
    }
}
