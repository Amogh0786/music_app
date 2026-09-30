package com.example.music_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.os.Build
import android.view.KeyEvent
import android.widget.RemoteViews
import java.io.File

class DilSeMusicWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_PLAY_PAUSE -> sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            ACTION_NEXT -> sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            ACTION_PREVIOUS -> sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
            ACTION_UPDATE_WIDGET -> {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val thisWidget = ComponentName(context, DilSeMusicWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
                if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                    onUpdate(context, appWidgetManager, appWidgetIds)
                }
            }
        }
    }

    private fun sendMediaKeyEvent(context: Context, keyCode: Int) {
        val downIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(context.packageName)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        context.sendBroadcast(downIntent)

        val upIntent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            setPackage(context.packageName)
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, keyCode))
        }
        context.sendBroadcast(upIntent)
    }

    companion object {
        const val ACTION_PLAY_PAUSE = "com.example.music_app.ACTION_PLAY_PAUSE"
        const val ACTION_NEXT = "com.example.music_app.ACTION_NEXT"
        const val ACTION_PREVIOUS = "com.example.music_app.ACTION_PREVIOUS"
        const val ACTION_UPDATE_WIDGET = "com.example.music_app.ACTION_UPDATE_WIDGET"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val title = prefs.getString("flutter.widget_title", "DilSe Music") ?: "DilSe Music"
            val artist = prefs.getString("flutter.widget_artist", "Tap to play") ?: "Tap to play"
            val isPlaying = prefs.getBoolean("flutter.widget_is_playing", false)
            val artworkPath = prefs.getString("flutter.widget_artwork_path", null)

            val views = RemoteViews(context.packageName, R.layout.dilse_music_widget)
            views.setTextViewText(R.id.widget_song_title, title)
            views.setTextViewText(R.id.widget_song_artist, artist)

            val playPauseIcon = if (isPlaying) {
                R.drawable.audio_service_pause
            } else {
                R.drawable.audio_service_play_arrow
            }
            views.setImageViewResource(R.id.widget_btn_play_pause, playPauseIcon)

            // High-res album artwork
            if (artworkPath != null && File(artworkPath).exists()) {
                try {
                    val bitmap = BitmapFactory.decodeFile(artworkPath)
                    if (bitmap != null) {
                        views.setImageViewBitmap(R.id.widget_album_art, bitmap)
                    } else {
                        views.setImageViewResource(R.id.widget_album_art, R.drawable.ic_stat_music)
                    }
                } catch (_: Exception) {
                    views.setImageViewResource(R.id.widget_album_art, R.drawable.ic_stat_music)
                }
            } else {
                views.setImageViewResource(R.id.widget_album_art, R.drawable.ic_stat_music)
            }

            val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            // Click body to open app
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openAppPendingIntent = PendingIntent.getActivity(context, 0, openAppIntent, flag)
            views.setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent)

            // Play / Pause
            val playPauseIntent = Intent(context, DilSeMusicWidgetProvider::class.java).apply {
                action = ACTION_PLAY_PAUSE
            }
            views.setOnClickPendingIntent(
                R.id.widget_btn_play_pause,
                PendingIntent.getBroadcast(context, 1, playPauseIntent, flag)
            )

            // Next
            val nextIntent = Intent(context, DilSeMusicWidgetProvider::class.java).apply {
                action = ACTION_NEXT
            }
            views.setOnClickPendingIntent(
                R.id.widget_btn_next,
                PendingIntent.getBroadcast(context, 2, nextIntent, flag)
            )

            // Previous
            val prevIntent = Intent(context, DilSeMusicWidgetProvider::class.java).apply {
                action = ACTION_PREVIOUS
            }
            views.setOnClickPendingIntent(
                R.id.widget_btn_prev,
                PendingIntent.getBroadcast(context, 3, prevIntent, flag)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun updateAllWidgets(context: Context) {
            try {
                val appWidgetManager = AppWidgetManager.getInstance(context)
                val thisWidget = ComponentName(context, DilSeMusicWidgetProvider::class.java)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
                if (appWidgetIds != null && appWidgetIds.isNotEmpty()) {
                    for (id in appWidgetIds) {
                        updateAppWidget(context, appWidgetManager, id)
                    }
                }
            } catch (_: Exception) {}
        }
    }
}
