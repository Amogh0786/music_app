  # 🎵 Cross-Platform Mobile Music App (Spotify UI + YouTube Audio Engine)

## 📌 Project Overview
A Spotify-inspired mobile music streaming application for **iOS and Android** that streams high-quality, ad-free audio directly from YouTube. 

- **Online Streaming (Default)**: Streams audio in memory without saving files or wasting device storage.
- **On-Demand Downloads**: Downloads MP3/M4A audio to local phone storage **only when explicitly requested** by the user for offline listening.

---

## 🎨 UI & UX Design Requirements
- **Theme**: Dark mode aesthetic (Spotify style: `#121212` background with `#1DB954` green accents).
- **Navigation & Layout**:
  - **Home Screen**: Recently played, top trending tracks, custom playlists.
  - **Search Screen**: Real-time search bar for songs, artists, and albums.
  - **Library Screen**: Saved songs, user playlists, and **Downloaded Songs** tab.
  - **Player Bar (Bottom Bar / Full Screen)**: Album cover, song title, artist name, Play/Pause, Seek bar, Volume control, ⬇️ Download button.

---

## 🛠️ Architecture & Tech Stack

```text
┌─────────────────────────────────────────────────────────────┐
│                 MOBILE FRONTEND (iOS & Android)             │
│  - Framework : Flutter (Dart) OR React Native (Expo)        │
│  - Audio Player: just_audio + audio_service (Flutter)       │
│  - State Mgmt: Provider / Riverpod (Flutter) or Zustand     │
└──────────────────────────────┬──────────────────────────────┘
                               │ (REST API / HTTPS)
                               ▼
┌─────────────────────────────────────────────────────────────┐
│                 BACKEND API (Python / Cloud)                │
│  - Framework  : FastAPI / Flask                             │
│  - Audio Engine: yt-dlp (in 'bestaudio/best' mode)          │
│  - Functions  : 1. Search YouTube metadata                  │
│                 2. Extract direct audio stream HTTPS URLs   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Dual-Mode Audio Playback Logic

### Mode A: Online Streaming (Default)
1. User searches for a track and taps **Play**.
2. App requests direct HTTPS audio stream URL from the Python backend API (`yt-dlp`).
3. Mobile audio player streams audio chunks directly into RAM memory.
4. **Result**: Immediate playback, ad-free, **0 MB stored on phone disk**.

### Mode B: Offline Download (On-Demand)
1. User taps the **⬇️ Download** button next to a track or playlist.
2. App downloads high-quality audio file (`.mp4` / `.m4a` / `.mp3`) to device storage (`/Documents/Downloaded_Songs/`).
3. Track is tagged with an **Offline Badge** and can be played anytime without internet access.

---

## 📱 Mobile Native Requirements
1. **Background Audio**: Music continues playing when the screen is locked or when switching apps.
2. **Lock Screen Controls**: Shows Album Art, Track Title, Play/Pause, and Seek Bar on iOS Control Center & Android Media Notification.
3. **Headphone & Bluetooth Controls**: Supports Play/Pause/Next from AirPods, Bluetooth headsets, Apple CarPlay, and Android Auto.
4. **Audio Focus**: Automatically pauses when receiving phone calls or audio notifications and resumes afterward.

---

## 🪲 Planned Feature Specification: SentryLens (Bug Intelligence and Shake-to-Report)

### 1. Overview and Vision
SentryLens is an integrated diagnostics and issue-reporting system designed for open-source users across Android, iOS, and Web PWA. It enables listeners to capture and report reproduction context instantly through a dedicated UI icon or a physical 3-shake motion gesture, without requiring a GitHub account.

An edge AI agent automatically triages, deduplicates, and structures each report before routing an actionable developer summary with compressed visual evidence directly to the project maintainer (`charanteja.kondakalla030206@gmail.com`).

---

### 2. User Experience and Trigger Flow

#### Trigger Vectors:
- **Physical motion:** 3 distinct shakes within a 1.2-second window using device accelerometer data. Confirmed via light haptic feedback (`HapticFeedback.mediumImpact`).
- **UI Entry Point:** A dedicated beetle, spider, or cyber-bug icon styled directly to match the app visual identity, avoiding generic Material buttons or unstyled floating action buttons.

#### UI Design Specifications for the Trigger Button:
- **Base container background:** Surface Elevation 1 (`#16161E`) with an 8 percent white border stroke (`rgba(255, 255, 255, 0.08)`).
- **Active or highlighted state:** Dynamic Accent (`#FA2D48` Apple Red) or dynamic tint derived from palette_generator (`_dominantColor` or `_vibrantColor`).
- **Icon silhouette:** A minimalist vector bug or spider glyph (Lucide bug, Phosphor beetle, or custom vector silhouette) using Text Primary (`#FFFFFF`) or Text Secondary (`rgba(255, 255, 255, 0.65)`).

#### Placement Options:
- **Option 1 inside SettingsScreen:**
  - Located inside an Apple-style inset grouped container (`#1E1E24`) labeled Diagnostics and Feedback.
  - Displays the bug glyph in a squircle container (radius 10px) with the label Report a Bug, showing a subtle right chevron.
- **Option 2 inside App Bar or Player Screen header:**
  - A minimalist circular or squircle icon button (36x36 dp, radius 10px) positioned in the top-right action row next to the settings gear.
  - Uses `BackdropFilter(sigma: 15)` with an 8 percent white border so content scrolls seamlessly behind it.

#### Micro-interactions:
- **Rest state:** Subtle dark translucent surface with the spider or bug glyph.
- **Tap state:** Scale compression (0.92x spring physics) with a light haptic tick (`HapticFeedback.selectionClick`).
- **Action:** Triggers the root `RepaintBoundary` viewport capture, packages audio telemetry, and slides up the `BugReportSheet` modal.

#### Modal Interface (`BugReportSheet`):
- Renders as a modal bottom sheet matching design tokens: Surface Elevation 2 (`#1F1F2B`), 28px top corner radius, and subtle 8 percent white border stroke.
- Displays an interactive preview thumbnail of the captured screenshot with a Blur or Exclude Screenshot toggle for privacy.
- Contains a structured text field with an enforced character/word gate: minimum 10 words required before the Submit action activates.
- Clear confirmation toast upon submission: *"Report analyzed and routed directly to Charan Teja. Thank you for improving DilSe!"*

---

### 3. Architecture and Edge Routing
The feature uses a 3-tier architecture to preserve app performance and prevent exposing developer secrets in client binaries:
```text
Client App (Flutter) -> POST multipart (Payload and PNG) -> Cloudflare Edge (/report_bug) -> SMTP or Transactional API -> Maintainer Inbox (charanteja.kondakalla030206@gmail.com).
```

#### Client-side telemetry collector (`lib/services/bug_report_service.dart`):
- Captures device OS release, app version and build (3.5.0+18), network status (Wi-Fi, 4G/5G, Offline), current route, and active audio deck (`_playerA` vs `_playerB`).
- Extracts current track ID, title, artist, audio stream URL type (Format 18 MP4 AAC vs JioSaavn 320k vs cached offline file), playback state, and crossfade progress.
- Captures the last 20 log events from the internal `/client_log` diagnostics ring buffer.

#### Edge AI triage layer (`cloudflare/worker_source.js`):
- **Endpoint:** `POST /report_bug`.
- Protected by Cloudflare IP rate-limiting (maximum 1 submission per device/IP every 3 minutes).
- The edge agent ingests the error payload, stack trace, and user text, then formats a structured triage card:
  - **Categorization:** Tags the issue (`AUDIO_PIPELINE`, `UI_LAYOUT`, `DES_DECRYPT`, `OFFLINE_CACHE`, `METADATA`).
  - **Severity:** Assigns priority (`P1 - Playback Breaking`, `P2 - Intermittent Glitch`, `P3 - Cosmetic/UI`).
  - **Triage brief:** Formats a clean plain-text digest summarizing the likely failure point and reproduction steps.
- Sends the digest with the attached screenshot directly to `charanteja.kondakalla030206@gmail.com`.

---

### 4. Technical Constraints and Non-Negotiables
- **Zero audio interference:** Screenshot rendering and log compression must execute on a background isolate (`compute()`) or idle tick to prevent audio buffer underruns on the active deck.
- **Privacy by default:** Telemetry must never harvest personal user identities, search history, or location coordinates. The screenshot preview must allow one-tap exclusion.
- **No hardcoded tokens:** Email delivery credentials or GitHub personal access tokens must reside strictly in Cloudflare Worker environment variables, never inside the compiled APK or IPA.

---

### 5. Roadmap and Contributor Opportunities
- **Phase 1 (v3.6.0):** Themed spider/bug reporting icon in Settings and header, bottom-sheet modal, and Cloudflare `/report_bug` email relay.
- **Phase 2 (v3.7.0):** Shake gesture detection via accelerometer streams and automated screenshot capture.
- **Phase 3 (v4.0.0):** Automatic GitHub issue creation with labeled categorization (`bug`, `triage-needed`) using the Cloudflare AI triage summary.

