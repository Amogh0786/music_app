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
