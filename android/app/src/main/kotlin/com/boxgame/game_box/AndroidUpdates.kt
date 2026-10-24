package com.best4u.untouch

import android.app.Activity
import android.os.Build
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallException
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/** Play owns delivery/signatures/consent. Never downloads or installs an APK ourselves. */
class AndroidUpdates(private val activity: Activity, messenger: BinaryMessenger) {
    private val methods = MethodChannel(messenger, "untouch/updates")
    private val events = EventChannel(messenger, "untouch/updates/events")
    private val manager = AppUpdateManagerFactory.create(activity)
    private var sink: EventChannel.EventSink? = null
    private var lastInfo: AppUpdateInfo? = null
    private var closed = false
    private var starting = false
    private val options = AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build()
    private val listener = InstallStateUpdatedListener { state ->
        if (!closed) sink?.success(snapshot().toMutableMap().apply {
            put("installStatus", state.installStatus())
            put("downloadedBytes", state.bytesDownloaded())
            put("totalBytes", state.totalBytesToDownload())
            put("errorCode", state.installErrorCode())
        })
    }

    init {
        events.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, eventSink: EventChannel.EventSink) {
                sink = eventSink
                manager.registerListener(listener)
            }
            override fun onCancel(arguments: Any?) {
                sink = null
                manager.unregisterListener(listener)
            }
        })
        methods.setMethodCallHandler { call, result ->
            if (!fromPlay()) {
                result.success(mapOf("supported" to false))
            } else when (call.method) {
                "check" -> manager.appUpdateInfo
                    .addOnSuccessListener { info ->
                        lastInfo = info
                        if (!closed) result.success(snapshot())
                    }.addOnFailureListener { fail(result, it) }
                "startFlexible" -> start(result)
                "complete" -> manager.appUpdateInfo
                    .addOnSuccessListener { info ->
                        if (closed) return@addOnSuccessListener
                        lastInfo = info
                        if (info.installStatus() != InstallStatus.DOWNLOADED) {
                            result.error("not_downloaded", "Update not downloaded", null)
                        } else manager.completeUpdate()
                            .addOnSuccessListener { if (!closed) result.success(null) }
                            .addOnFailureListener { fail(result, it) }
                    }.addOnFailureListener { fail(result, it) }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun fromPlay(): Boolean = try {
        val installer = if (Build.VERSION.SDK_INT >= 30) {
            activity.packageManager.getInstallSourceInfo(activity.packageName).installingPackageName
        } else activity.packageManager.getInstallerPackageName(activity.packageName)
        installer == "com.android.vending"
    } catch (_: Exception) { false }

    @Suppress("DEPRECATION")
    private fun snapshot(): Map<String, Any> {
        val info = lastInfo
        val installed = activity.packageManager.getPackageInfo(activity.packageName, 0)
        val code = if (Build.VERSION.SDK_INT >= 28) installed.longVersionCode else installed.versionCode.toLong()
        return mapOf(
            "supported" to true,
            "installedVersion" to code,
            "availableVersion" to (info?.availableVersionCode() ?: 0),
            "available" to (info?.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE),
            "flexibleAllowed" to (info?.isUpdateTypeAllowed(options) ?: false),
            "installStatus" to (info?.installStatus() ?: InstallStatus.UNKNOWN),
            "downloadedBytes" to (info?.bytesDownloaded() ?: 0L),
            "totalBytes" to (info?.totalBytesToDownload() ?: 0L),
            "errorCode" to 0
        )
    }

    private fun start(result: MethodChannel.Result) {
        if (starting) {
            result.error("busy", "Update consent already open", null)
            return
        }
        starting = true
        // AppUpdateInfo is single-use. Always request a fresh instance on retry.
        manager.appUpdateInfo.addOnSuccessListener { info ->
            if (closed) return@addOnSuccessListener
            lastInfo = info
            if (info.installStatus() == InstallStatus.DOWNLOADED ||
                info.installStatus() == InstallStatus.DOWNLOADING ||
                info.installStatus() == InstallStatus.PENDING) {
                starting = false
                result.success(snapshot())
            } else if (info.updateAvailability() != UpdateAvailability.UPDATE_AVAILABLE ||
                !info.isUpdateTypeAllowed(options)) {
                starting = false
                result.success(snapshot())
            } else {
                try {
                    manager.startUpdateFlow(info, activity, options)
                        .addOnSuccessListener { code ->
                            starting = false
                            if (!closed) result.success(snapshot().toMutableMap().apply {
                                put("canceled", code == Activity.RESULT_CANCELED)
                                put("accepted", code == Activity.RESULT_OK)
                                put("failed", code != Activity.RESULT_OK && code != Activity.RESULT_CANCELED)
                            })
                        }.addOnFailureListener {
                            starting = false
                            fail(result, it)
                        }
                } catch (error: Exception) {
                    starting = false
                    fail(result, error)
                }
            }
        }.addOnFailureListener {
            starting = false
            fail(result, it)
        }
    }

    private fun fail(result: MethodChannel.Result, error: Exception) {
        if (!closed) result.error("play_update_failed", "Google Play update unavailable",
            (error as? InstallException)?.errorCode)
    }

    fun dispose() {
        closed = true
        manager.unregisterListener(listener)
        sink = null
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
    }
}
