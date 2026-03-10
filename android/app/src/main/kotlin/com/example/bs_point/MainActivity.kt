package com.hnglife.bspoint

import android.content.Context
import android.os.Build
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCarrierName" -> result.success(getCarrierName())
                else -> result.notImplemented()
            }
        }
    }

    private fun getCarrierName(): String? {
        return try {
            val telephonyManager =
                getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                    ?: return null

            val activeSubscriptionName = getActiveSubscriptionName()
            if (!activeSubscriptionName.isNullOrBlank()) {
                return activeSubscriptionName
            }

            val simOperatorName = telephonyManager.simOperatorName
            if (!simOperatorName.isNullOrBlank()) {
                return simOperatorName
            }

            val networkOperatorName = telephonyManager.networkOperatorName
            if (!networkOperatorName.isNullOrBlank()) {
                return networkOperatorName
            }

            null
        } catch (_: SecurityException) {
            null
        } catch (_: Exception) {
            null
        }
    }

    private fun getActiveSubscriptionName(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
            return null
        }

        val subscriptionManager = getSystemService(SubscriptionManager::class.java)
            ?: return null

        return try {
            subscriptionManager.activeSubscriptionInfoList
                ?.firstOrNull()
                ?.carrierName
                ?.toString()
        } catch (_: SecurityException) {
            null
        }
    }

    companion object {
        private const val CHANNEL_NAME = "com.hnglife.bspoint/device_info"
    }
}
