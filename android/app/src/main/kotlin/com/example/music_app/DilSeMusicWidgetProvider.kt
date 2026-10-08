package com.example.music_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.*
import android.os.Build
import android.view.KeyEvent
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import kotlin.math.max

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
            ACTION_PLAY_PAUSE -> {
                // Optimistic zero-latency UI toggle
                optimisticTogglePlayPause(context)
                sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            }
            ACTION_NEXT -> sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            ACTION_PREVIOUS -> sendMediaKeyEvent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
            ACTION_SHUFFLE -> {
                optimisticToggleShuffle(context)
                dispatchCustomAction(context, "toggleShuffle")
            }
            ACTION_REPEAT -> {
                optimisticToggleRepeat(context)
                dispatchCustomAction(context, "toggleRepeat")
            }
            ACTION_PLAY_PLAYLIST -> {
                val playlistIndex = intent.getIntExtra(EXTRA_PLAYLIST_INDEX, 0)
                val playlistId = intent.getStringExtra(EXTRA_PLAYLIST_ID) ?: ""
                val playlistQuery = intent.getStringExtra(EXTRA_PLAYLIST_QUERY) ?: ""
                launchAppWithPlaylist(context, playlistIndex, playlistId, playlistQuery)
            }
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

    private fun optimisticTogglePlayPause(context: Context) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val current = prefs.getBoolean("flutter.widget_is_playing", false)
            prefs.edit().putBoolean("flutter.widget_is_playing", !current).apply()
            updateAllWidgets(context)
        } catch (_: Exception) {}
    }

    private fun optimisticToggleShuffle(context: Context) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val current = prefs.getBoolean("flutter.widget_is_shuffle", false)
            prefs.edit().putBoolean("flutter.widget_is_shuffle", !current).apply()
            updateAllWidgets(context)
        } catch (_: Exception) {}
    }

    private fun optimisticToggleRepeat(context: Context) {
        try {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val current = prefs.getBoolean("flutter.widget_is_repeat", false)
            prefs.edit().putBoolean("flutter.widget_is_repeat", !current).apply()
            updateAllWidgets(context)
        } catch (_: Exception) {}
    }

    private fun dispatchCustomAction(context: Context, action: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("widget_action", action)
        }
        context.startActivity(intent)
    }

    private fun launchAppWithPlaylist(context: Context, index: Int, id: String, query: String) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("widget_action", "playPlaylist")
            putExtra("playlist_index", index)
            putExtra("playlist_id", id)
            putExtra("playlist_query", query)
        }
        context.startActivity(intent)
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
        const val ACTION_SHUFFLE = "com.example.music_app.ACTION_SHUFFLE"
        const val ACTION_REPEAT = "com.example.music_app.ACTION_REPEAT"
        const val ACTION_PLAY_PLAYLIST = "com.example.music_app.ACTION_PLAY_PLAYLIST"
        const val ACTION_UPDATE_WIDGET = "com.example.music_app.ACTION_UPDATE_WIDGET"

        const val EXTRA_PLAYLIST_INDEX = "extra_playlist_index"
        const val EXTRA_PLAYLIST_ID = "extra_playlist_id"
        const val EXTRA_PLAYLIST_QUERY = "extra_playlist_query"

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val title = prefs.getString("flutter.widget_title", "DilSe Music") ?: "DilSe Music"
            val artist = prefs.getString("flutter.widget_artist", "Tap to play") ?: "Tap to play"
            val isPlaying = prefs.getBoolean("flutter.widget_is_playing", false)
            val isShuffle = prefs.getBoolean("flutter.widget_is_shuffle", false)
            val isRepeat = prefs.getBoolean("flutter.widget_is_repeat", false)
            val artworkPath = prefs.getString("flutter.widget_artwork_path", null)
            val dominantColorInt = prefs.getLong("flutter.widget_dominant_color", 0L).toInt()
            val positionMs = prefs.getLong("flutter.widget_position_ms", 0L)
            val durationMs = prefs.getLong("flutter.widget_duration_ms", 0L)
            val positionText = prefs.getString("flutter.widget_position_text", "0:00") ?: "0:00"
            val durationText = prefs.getString("flutter.widget_duration_text", "0:00") ?: "0:00"
            val playlistsJson = prefs.getString("flutter.widget_top_playlists_json", null)

            val views = RemoteViews(context.packageName, R.layout.dilse_music_widget)

            // 1. Resolve Dominant Color
            val dominantColor = if (dominantColorInt != 0) {
                dominantColorInt
            } else if (artworkPath != null && File(artworkPath).exists()) {
                extractDominantColorFromBitmap(artworkPath)
            } else {
                Color.parseColor("#FF5722") // Warm vibrant amber fallback
            }

            // 2. Synthesize Dynamic Frosted Glass Background Canvas
            val bgBitmap = createDynamicGlassBackground(context, dominantColor)
            if (bgBitmap != null) {
                views.setImageViewBitmap(R.id.widget_background_image, bgBitmap)
            }

            // 3. Track Metadata
            views.setTextViewText(R.id.widget_song_title, title)
            views.setTextViewText(R.id.widget_song_artist, artist)

            // 4. Squircle Album Art with Rounded Corners
            if (artworkPath != null && File(artworkPath).exists()) {
                try {
                    val rawBitmap = BitmapFactory.decodeFile(artworkPath)
                    if (rawBitmap != null) {
                        val roundedArt = createRoundedBitmap(rawBitmap, 28f)
                        views.setImageViewBitmap(R.id.widget_album_art, roundedArt)
                    } else {
                        views.setImageViewResource(R.id.widget_album_art, R.drawable.ic_stat_music)
                    }
                } catch (_: Exception) {
                    views.setImageViewResource(R.id.widget_album_art, R.drawable.ic_stat_music)
                }
            } else {
                views.setImageViewResource(R.id.widget_album_art, R.drawable.ic_stat_music)
            }

            // 5. Glowing Circular Play / Pause Deck
            val playPauseBitmap = createGlowingPlayButton(context, isPlaying, dominantColor)
            views.setImageViewBitmap(R.id.widget_btn_play_pause, playPauseBitmap)

            // 6. Responsive Shuffle & Repeat Tint States
            val activeColor = Color.WHITE
            val inactiveColor = Color.argb(100, 255, 255, 255)
            views.setInt(R.id.widget_btn_shuffle, "setColorFilter", if (isShuffle) activeColor else inactiveColor)
            views.setInt(R.id.widget_btn_repeat, "setColorFilter", if (isRepeat) activeColor else inactiveColor)

            // 7. Progress Bar & Monospace Timestamps
            val progress = if (durationMs > 0) {
                ((positionMs.toDouble() / durationMs.toDouble()) * 1000).toInt().coerceIn(0, 1000)
            } else {
                0
            }
            views.setProgressBar(R.id.widget_progress_bar, 1000, progress, false)
            views.setTextViewText(R.id.widget_time_current, positionText)
            views.setTextViewText(R.id.widget_time_total, durationText)

            // 8. PendingIntents for Touch Controls
            val flag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            // Click body to open app
            val openAppIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            views.setOnClickPendingIntent(R.id.widget_root, PendingIntent.getActivity(context, 0, openAppIntent, flag))

            // Play / Pause
            val playPauseIntent = Intent(context, DilSeMusicWidgetProvider::class.java).apply {
                action = ACTION_PLAY_PAUSE
            }
            views.setOnClickPendingIntent(R.id.widget_btn_play_pause, PendingIntent.getBroadcast(context, 1, playPauseIntent, flag))

            // Next
            val nextIntent = Intent(context, DilSeMusicWidgetProvider::class.java).apply {
                action = ACTION_NEXT
            }
            views.setOnClickPendingIntent(R.id.widget_btn_next, PendingIntent.getBroadcast(context, 2, nextIntent, flag))

            // Previous
            val prevIntent = Intent(context, DilSeMusicWidgetProvider::class.java).apply {
                action = ACTION_PREVIOUS
            }
            views.setOnClickPendingIntent(R.id.widget_btn_prev, PendingIntent.getBroadcast(context, 3, prevIntent, flag))

            // Shuffle
            val shuffleIntent = Intent(context, DilSeMusicWidgetProvider::class.java).apply {
                action = ACTION_SHUFFLE
            }
            views.setOnClickPendingIntent(R.id.widget_btn_shuffle, PendingIntent.getBroadcast(context, 4, shuffleIntent, flag))

            // Repeat
            val repeatIntent = Intent(context, DilSeMusicWidgetProvider::class.java).apply {
                action = ACTION_REPEAT
            }
            views.setOnClickPendingIntent(R.id.widget_btn_repeat, PendingIntent.getBroadcast(context, 5, repeatIntent, flag))

            // 9. Bottom Shelf: 5 Top Playlists Based On Listening Data
            setupTopPlaylists(context, views, playlistsJson, dominantColor, flag)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun setupTopPlaylists(
            context: Context,
            views: RemoteViews,
            playlistsJson: String?,
            dominantColor: Int,
            flag: Int
        ) {
            val defaultPlaylists = listOf(
                Pair("Daily\nMix", "Daily Mix"),
                Pair("Favorites", "Favorites"),
                Pair("Most\nPlayed", "Most Played"),
                Pair("History\nReplay", "History"),
                Pair("Chill\nVibes", "Chill Vibes")
            )

            var parsedList: List<Triple<String, String, String>>? = null
            if (!playlistsJson.isNullOrEmpty()) {
                try {
                    val array = JSONArray(playlistsJson)
                    val list = mutableListOf<Triple<String, String, String>>()
                    for (i in 0 until array.length().coerceAtMost(5)) {
                        val obj = array.getJSONObject(i)
                        val title = obj.optString("title", "Mix")
                        val id = obj.optString("id", "")
                        val query = obj.optString("query", title)
                        list.add(Triple(title, id, query))
                    }
                    if (list.isNotEmpty()) parsedList = list
                } catch (_: Exception) {}
            }

            val slotIds = intArrayOf(
                R.id.widget_playlist_0,
                R.id.widget_playlist_1,
                R.id.widget_playlist_2,
                R.id.widget_playlist_3,
                R.id.widget_playlist_4
            )
            val titleIds = intArrayOf(
                R.id.widget_playlist_title_0,
                R.id.widget_playlist_title_1,
                R.id.widget_playlist_title_2,
                R.id.widget_playlist_title_3,
                R.id.widget_playlist_title_4
            )
            val artIds = intArrayOf(
                R.id.widget_playlist_art_0,
                R.id.widget_playlist_art_1,
                R.id.widget_playlist_art_2,
                R.id.widget_playlist_art_3,
                R.id.widget_playlist_art_4
            )

            val badgeGradients = arrayOf(
                intArrayOf(Color.parseColor("#FF5E3A"), Color.parseColor("#FF2A68")),
                intArrayOf(Color.parseColor("#00B4DB"), Color.parseColor("#0083B0")),
                intArrayOf(Color.parseColor("#F7971E"), Color.parseColor("#FF7000")),
                intArrayOf(Color.parseColor("#11998E"), Color.parseColor("#38EF7D")),
                intArrayOf(Color.parseColor("#8E2DE2"), Color.parseColor("#4A00E0"))
            )

            for (i in 0 until 5) {
                val title = parsedList?.getOrNull(i)?.first ?: defaultPlaylists[i].first
                val id = parsedList?.getOrNull(i)?.second ?: "playlist_$i"
                val query = parsedList?.getOrNull(i)?.third ?: defaultPlaylists[i].second

                views.setTextViewText(titleIds[i], title)

                // Render micro squircle gradient badge
                val badgeBitmap = createPlaylistBadge(badgeGradients[i % badgeGradients.size])
                views.setImageViewBitmap(artIds[i], badgeBitmap)

                // Intent for tapping playlist
                val intent = Intent(context, DilSeMusicWidgetProvider::class.java).apply {
                    action = ACTION_PLAY_PLAYLIST
                    putExtra(EXTRA_PLAYLIST_INDEX, i)
                    putExtra(EXTRA_PLAYLIST_ID, id)
                    putExtra(EXTRA_PLAYLIST_QUERY, query)
                }
                views.setOnClickPendingIntent(slotIds[i], PendingIntent.getBroadcast(context, 10 + i, intent, flag))
            }
        }

        private fun createPlaylistBadge(colors: IntArray): Bitmap {
            val size = 56
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(0f, 0f, size.toFloat(), size.toFloat(), colors, null, Shader.TileMode.CLAMP)
            }
            val rect = RectF(0f, 0f, size.toFloat(), size.toFloat())
            canvas.drawRoundRect(rect, 14f, 14f, paint)
            return bitmap
        }

        private fun createRoundedBitmap(source: Bitmap, cornerRadiusDp: Float): Bitmap {
            val size = 200
            val scaled = Bitmap.createScaledBitmap(source, size, size, true)
            val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(output)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = BitmapShader(scaled, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
            }
            val rect = RectF(0f, 0f, size.toFloat(), size.toFloat())
            canvas.drawRoundRect(rect, cornerRadiusDp, cornerRadiusDp, paint)
            return output
        }

        private fun createGlowingPlayButton(context: Context, isPlaying: Boolean, dominantColor: Int): Bitmap {
            val size = 120
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val center = size / 2f

            // 1. Soft Ambient Halo Glow
            val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    center, center, center,
                    intArrayOf(
                        Color.argb(160, Color.red(dominantColor), Color.green(dominantColor), Color.blue(dominantColor)),
                        Color.argb(80, Color.red(dominantColor), Color.green(dominantColor), Color.blue(dominantColor)),
                        Color.TRANSPARENT
                    ),
                    floatArrayOf(0.0f, 0.65f, 1.0f),
                    Shader.TileMode.CLAMP
                )
            }
            canvas.drawCircle(center, center, glowPaint)

            // 2. Solid Inner Circle Deck with Subtle Radial Gradient
            val deckPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    center, center - 6f, center * 0.70f,
                    intArrayOf(
                        Color.WHITE,
                        Color.parseColor("#FFF4EE"),
                        Color.parseColor("#F0E6DD")
                    ),
                    null,
                    Shader.TileMode.CLAMP
                )
            }
            val deckRadius = center * 0.68f
            canvas.drawCircle(center, center, deckRadius, deckPaint)

            // 3. Crisp Play or Pause Glyph
            val glyphPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#121216")
                style = Paint.Style.FILL
            }

            if (isPlaying) {
                // Pause bars
                val barWidth = 8f
                val barHeight = 26f
                val spacing = 7f
                canvas.drawRoundRect(RectF(center - spacing - barWidth, center - barHeight / 2, center - spacing, center + barHeight / 2), 3f, 3f, glyphPaint)
                canvas.drawRoundRect(RectF(center + spacing, center - barHeight / 2, center + spacing + barWidth, center + barHeight / 2), 3f, 3f, glyphPaint)
            } else {
                // Play triangle
                val path = Path().apply {
                    val half = 15f
                    moveTo(center - 10f, center - half)
                    lineTo(center + 14f, center)
                    lineTo(center - 10f, center + half)
                    close()
                }
                canvas.drawPath(path, glyphPaint)
            }

            return bitmap
        }

        private fun createDynamicGlassBackground(context: Context, dominantColor: Int): Bitmap? {
            val width = 720
            val height = 360
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            val rect = RectF(0f, 0f, width.toFloat(), height.toFloat())
            val cornerRadius = 56f

            // 1. Base Dark Charcoal Obsidian Glass
            val basePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.parseColor("#FF0F0F16")
            }
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, basePaint)

            // 2. Dominant Color Ambient Bloons (Light Bleed Matching Mock)
            // Left bloom behind artwork
            val leftGlow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    width * 0.25f, height * 0.35f, width * 0.55f,
                    intArrayOf(
                        Color.argb(170, Color.red(dominantColor), Color.green(dominantColor), Color.blue(dominantColor)),
                        Color.argb(80, Color.red(dominantColor), Color.green(dominantColor), Color.blue(dominantColor)),
                        Color.TRANSPARENT
                    ),
                    floatArrayOf(0f, 0.55f, 1f),
                    Shader.TileMode.CLAMP
                )
            }
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, leftGlow)

            // Right/Center ambient warm glow
            val centerGlow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = RadialGradient(
                    width * 0.70f, height * 0.40f, width * 0.45f,
                    intArrayOf(
                        Color.argb(100, Color.red(dominantColor), Color.green(dominantColor), Color.blue(dominantColor)),
                        Color.TRANSPARENT
                    ),
                    floatArrayOf(0f, 1f),
                    Shader.TileMode.CLAMP
                )
            }
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, centerGlow)

            // Subtle dark vignette at the bottom for playlist readability
            val bottomVignette = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    0f, height * 0.55f, 0f, height.toFloat(),
                    Color.TRANSPARENT,
                    Color.argb(160, 10, 10, 15),
                    Shader.TileMode.CLAMP
                )
            }
            canvas.drawRoundRect(rect, cornerRadius, cornerRadius, bottomVignette)

            // 3. Translucent Glass Outline Stroke Border
            val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = 3f
                shader = LinearGradient(
                    0f, 0f, width.toFloat(), height.toFloat(),
                    intArrayOf(
                        Color.argb(90, 255, 255, 255),
                        Color.argb(30, 255, 255, 255),
                        Color.argb(70, Color.red(dominantColor), Color.green(dominantColor), Color.blue(dominantColor))
                    ),
                    null,
                    Shader.TileMode.CLAMP
                )
            }
            val strokeRect = RectF(1.5f, 1.5f, width - 1.5f, height - 1.5f)
            canvas.drawRoundRect(strokeRect, cornerRadius, cornerRadius, strokePaint)

            return bitmap
        }

        private fun extractDominantColorFromBitmap(filePath: String): Int {
            return try {
                val opts = BitmapFactory.Options().apply { inSampleSize = 8 }
                val bmp = BitmapFactory.decodeFile(filePath, opts) ?: return Color.parseColor("#FF5722")
                val width = bmp.width
                val height = bmp.height
                var redSum = 0L
                var greenSum = 0L
                var blueSum = 0L
                var count = 0L
                for (x in width / 4 until (3 * width / 4) step 4) {
                    for (y in height / 4 until (3 * height / 4) step 4) {
                        val p = bmp.getPixel(x, y)
                        redSum += Color.red(p)
                        greenSum += Color.green(p)
                        blueSum += Color.blue(p)
                        count++
                    }
                }
                if (count == 0L) Color.parseColor("#FF5722")
                else Color.rgb((redSum / count).toInt(), (greenSum / count).toInt(), (blueSum / count).toInt())
            } catch (_: Exception) {
                Color.parseColor("#FF5722")
            }
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
