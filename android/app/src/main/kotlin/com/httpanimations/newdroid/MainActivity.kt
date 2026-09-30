package com.httpanimations.newdroid

import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    private val channelName = "newdroid/device"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "installedPackages" -> result.success(installedPackages())
                        "sdkInt" -> result.success(Build.VERSION.SDK_INT)
                        "abis" -> result.success(Build.SUPPORTED_ABIS.toList())
                        "canInstallUnknownApps" ->
                            result.success(canInstallUnknownApps())
                        "openInstallSettings" -> {
                            openInstallSettings()
                            result.success(true)
                        }
                        "installApk" -> {
                            val path = call.argument<String>("path")
                            result.success(
                                path != null && installApk(File(path))
                            )
                        }
                        "openApp" -> {
                            val pkg = call.argument<String>("package")
                            result.success(pkg != null && openApp(pkg))
                        }
                        "uninstallApp" -> {
                            val pkg = call.argument<String>("package")
                            result.success(pkg != null && uninstallApp(pkg))
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("device_error", e.message, null)
                }
            }
    }

    private fun installedPackages(): Map<String, Any> {
        val pm = packageManager
        val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES.toLong()
        } else {
            @Suppress("DEPRECATION")
            PackageManager.GET_SIGNATURES.toLong()
        }
        val packages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getInstalledPackages(PackageManager.PackageInfoFlags.of(flags))
        } else {
            @Suppress("DEPRECATION")
            pm.getInstalledPackages(flags.toInt())
        }
        val out = HashMap<String, Any>()
        for (info in packages) {
            val app = info.applicationInfo ?: continue
            // Skip pure system components that cannot be updated anyway.
            if (info.packageName == packageName) continue
            val entry = HashMap<String, Any?>()
            entry["versionCode"] = info.longVersionCode
            entry["versionName"] = info.versionName ?: ""
            entry["label"] = app.loadLabel(pm).toString()
            entry["signer"] = signingSha256(info)
            entry["system"] =
                (app.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            out[info.packageName] = entry
        }
        return out
    }

    private fun signingSha256(info: android.content.pm.PackageInfo): String? {
        return try {
            val bytes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                val signing = info.signingInfo ?: return null
                val sigs = if (signing.hasMultipleSigners()) {
                    signing.apkContentsSigners
                } else {
                    signing.signingCertificateHistory
                }
                sigs.firstOrNull()?.toByteArray() ?: return null
            } else {
                @Suppress("DEPRECATION")
                info.signatures?.firstOrNull()?.toByteArray() ?: return null
            }
            MessageDigest.getInstance("SHA-256")
                .digest(bytes)
                .joinToString("") { "%02x".format(it) }
        } catch (e: Exception) {
            null
        }
    }

    private fun canInstallUnknownApps(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else {
            true
        }
    }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }

    private fun installApk(file: File): Boolean {
        if (!file.exists()) return false
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
        return true
    }

    private fun openApp(pkg: String): Boolean {
        val intent = packageManager.getLaunchIntentForPackage(pkg) ?: return false
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        return true
    }

    private fun uninstallApp(pkg: String): Boolean {
        val intent = Intent(Intent.ACTION_DELETE).apply {
            data = Uri.parse("package:$pkg")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        return true
    }
}
