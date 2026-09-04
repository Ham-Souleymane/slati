package com.slatk.slatkapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class AdhanActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == AdhanAlarmReceiver.ACTION_STOP_ADHAN) {
            Log.d("AdhanActionReceiver", "Stop Adhan action received by user tap")

            // Stop any active audio, dismiss notification, and release wake lock
            AdhanAlarmReceiver.stopPlayback(context)

            // Also stop AdhanService if it was running
            try {
                AdhanService.currentInstance?.stopSelf()
            } catch (e: Exception) {
                Log.e("AdhanActionReceiver", "Error stopping service instance: ${e.message}")
            }

            // Dismiss the full-screen ringing activity if it is currently displayed
            try {
                AdhanRingingActivity.currentInstance?.let { activity ->
                    if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.LOLLIPOP) {
                        activity.finishAndRemoveTask()
                    } else {
                        activity.finish()
                    }
                }
                context.sendBroadcast(Intent(AdhanRingingActivity.ACTION_DISMISS_RINGING))
            } catch (e: Exception) {
                Log.e("AdhanActionReceiver", "Error dismissing ringing activity: ${e.message}")
            }
        }
    }
}
