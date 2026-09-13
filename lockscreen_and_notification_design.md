# Lock Screen & Notification Media Controls Design Document

> **Status**: In Discussion / Architecture Phase  
> **Rule**: No production code modifications until design decisions are finalized and approved.

---

## 1. Overview & Goals

The goal is to deliver a seamless, native Lock Screen and Notification Shade media playback experience on Android (Android 11–15 `MediaSession`) and iOS (`MPNowPlayingInfoCenter`).

When a song plays:
1. Android's **Notification Shade / Quick Settings** should render an interactive Media Player card with live waveform seekbar, album art, title, artist, and playback control buttons.
2. The **Lock Screen** should display the media carousel without waking or unlocking the device.
3. Controlling playback from notifications (e.g. Next, Previous, Pause) must sync instantaneously with the app's internal queue and UI state.

---

## 2. Technical Audit: Current Codebase State

| Component | Current State | Required Action |
| :--- | :--- | :--- |
| **`pubspec.yaml`** | `just_audio_background: ^0.0.1-beta.17` installed. | Ready. |
| **`MainActivity.kt`** | Extends `AudioServiceActivity()`. | Ready. |
| **`AndroidManifest.xml`** | `POST_NOTIFICATIONS` and `FOREGROUND_SERVICE_MEDIA_PLAYBACK` declared. | Ready. |
| **`MediaItem` Tagging** | `MusicService` creates `MediaItem` with title, artist, album art. | Needs action mapping (prev/next). |
| **Android 13+ Runtime Permission** | Declared in manifest, but **not requested at runtime**. | **Needs runtime prompt/request.** |
| **`JustAudioBackground.init`** | Basic initialization without custom actions or notification icons. | Needs fine-tuning for controls & persistence. |
| **Queue Callbacks** | Next/Previous media button intents are not yet bound to `MusicService.playNext()` / `playPrevious()`. | Must wire `skipToNext` and `skipToPrevious`. |

---

## 3. Key Discussion Points & Design Decisions

### Decision 1: Action Button Layout in Notification Shade
What buttons should be rendered next to the Play/Pause button?

- **Option A: Track Navigation (Recommended for Music Apps)**
  - Controls: `[⏮️ Previous Track] [⏯️ Play / Pause] [⏭️ Next Track]`
  - Behavior: Tapping Next/Previous skips to the next/previous song in the playlist.
- **Option B: Seek Navigation (Recommended for Podcasts)**
  - Controls: `[⏪ Seek -10s] [⏯️ Play / Pause] [⏩ Seek +10s]`
  - Behavior: Skips forward or backward within the current track.
- **Option C: Extended Controls (Compact vs Expanded)**
  - Compact view: `[⏮️ Prev] [⏯️ Play/Pause] [⏭️ Next]`
  - Expanded view: Adds `[🔁 Loop / Shuffle]` or `[❤️ Like Song]`.

---

### Decision 2: Notification Persistence When Paused
How should the notification behave when the user pauses music?

- **Option A: Sticky / Persistent (`androidNotificationOngoing: true`)**
  - Stays docked in the notification shade even when paused.
  - Advantage: The user can easily tap **Play** 30 minutes later from the lock screen without reopening the app.
  - Dismissal: Dismisses only when the user swipes away the player or closes the app.
- **Option B: Auto-Dismiss on Pause (`androidStopForegroundOnPause: true`)**
  - As soon as the user pauses, the notification can be swiped away immediately.
  - Advantage: Doesn't clutter the notification shade if the user stops listening.

---

### Decision 3: Android 13+ Runtime Permission Strategy
Android 13+ (API 33+) requires the user to explicitly grant notification permission. Without it, Android suppresses all media player tiles.

- **Option A: Contextual Prompt on First Song Play (Recommended)**
  - When the user taps their first song, check if notification permission is granted. If not, show a clean dialog:  
    *"Enable lock screen controls to manage playback without opening the app."* -> System permission dialog appears.
- **Option B: App Startup Prompt**
  - Prompt for notification permission right as the app opens for the first time.
- **Option C: Settings Toggle**
  - An explicit switch in Settings: *"Enable Lock Screen Controls"*.

---

### Decision 4: Status Bar & Notification Icon
Android requires a monochrome (white silhouette on transparent background) icon for the top status bar.

- **Option A: Default App Icon (`mipmap/ic_launcher`)**
  - Quickest, but might show as a white square or silhouette on some Android devices if the icon has non-transparent backgrounds.
- **Option B: Dedicated Monochrome Vector (`drawable/ic_stat_music`)**
  - A clean musical note vector strictly complying with Android Material status bar guidelines.

---

### Decision 5: Next / Previous Queue Linking
How should the background service communicate with the playlist queue?

- Since our app uses `MusicService` as a singleton with `_playlist` and `_currentIndex`:
  - When Android fires `skipToNext()` from lock screen: It must invoke `MusicService().playNext()`.
  - When Android fires `skipToPrevious()` from lock screen: It must invoke `MusicService().playPrevious()`.
  - Disable Next/Previous buttons if there is no next/previous song, or loop if loop mode is active.

---

## 4. Final Decisions Log

*(We will update this section as we discuss and finalize each point)*

| Decision Item | Chosen Approach | Notes / Technical Implementation |
| :--- | :--- | :--- |
| **1. Action Layout** | **Option A**: `[⏮️ Prev] [⏯️ Play/Pause] [⏭️ Next]` | Standard 3-action media session layout with native seekable waveform scrubber. |
| **2. Pause Persistence** | **App Lifecycle Bound**: Persistent while app is open/recent, dismissed on app kill | Set `androidNotificationOngoing: false`, `androidStopForegroundOnPause: false`, and ensure `stopWithTask: true` so the notification stays while app is alive (even when paused), but cleanly dismisses when swiped away from Android recent apps. |
| **3. Permission Prompt** | **Option A**: Contextual prompt on first song play | Clean, modern dialog explaining value ("Control your playback from the lock screen") before invoking the system Android 13+ `POST_NOTIFICATIONS` prompt. |
| **4. Notification Icon** | **Option B**: Dedicated monochrome vector (`drawable/ic_stat_music`) | Create a crisp, transparent-backed white musical note vector drawable adhering strictly to Android Material status bar guidelines (avoids gray/white block artifact). |
| **5. End of Queue Sync** | **Option A**: Infinite Radio (Auto-fetch next 20 songs) | When `skipToNext` is triggered on the last song in the playlist, silently fetch recommendations and append them to `_playlist` so playback never abruptly terminates. |

---

## 5. Technical Implementation Specification

### Step 1: Android Notification Icon
- Create `android/app/src/main/res/drawable/ic_stat_music.xml` (monochrome vector drawable with white fill on transparent canvas).
- Reference `'drawable/ic_stat_music'` in `JustAudioBackground.init(androidNotificationIcon: ...)`.

### Step 2: Android 13+ Runtime Permission Flow
- When user plays a track:
  - Check if permission has already been prompted (via `SharedPreferences`).
  - If not prompted yet and on Android 13+ (SDK 33+), display a bottom sheet / dialog:  
    *Title*: "Enable Lock Screen Controls"  
    *Body*: "Allow notifications so you can pause, skip, and see album art from your lock screen without opening the app."  
    *Buttons*: `[ Not Now ]` & `[ Enable Controls ]`.
  - Request permission using native platform channel / `permission_handler`.

### Step 3: Notification & MediaSession Configuration
In `lib/main.dart` (`JustAudioBackground.init`):
```dart
await JustAudioBackground.init(
  androidNotificationChannelId: 'com.example.music_app.channel.audio',
  androidNotificationChannelName: 'Music Playback',
  androidNotificationChannelDescription: 'Music playback controls and lock screen notification',
  androidNotificationIcon: 'drawable/ic_stat_music',
  androidNotificationOngoing: false,
  androidStopForegroundOnPause: false,
);
```

### Step 4: Wire Media Button Callbacks in `MusicService`
In `lib/services/music_service.dart`:
- Create custom `MediaAction` controls for `MediaItem`:
  - `MediaAction.skipToPrevious` -> calls `playPrevious()`.
  - `MediaAction.play` / `MediaAction.pause` -> calls `audioPlayer.play()` / `audioPlayer.pause()`.
  - `MediaAction.skipToNext` -> calls `playNext()`.
  - When `playNext()` reaches the end of the playlist, auto-trigger `_fetchNextRecommendations()` so music continues playing uninterrupted.

### Step 5: Clean Dismissal on Task Kill
- Configure Android `AudioService` service manifest options (`android:stopWithTask="true"`) to ensure that swiping the app out of Recent Apps clears the foreground notification.

---

## 6. Sign-off

- [x] Decisions finalized with user.
- [ ] User approval granted to start coding.

