# DilSe Music — Core Architecture Preservation Rules

> **CRITICAL INVARIANT**: NEVER break or compromise the core audio playback, multi-tier search, personalized recommendation engine, or metadata integrity of the application.

---

## 1. Zero-Regression Quality Gate
Before proposing, committing, or merging any changes:
1. `dart format lib/ test/` must yield 0 changed files.
2. `flutter analyze lib/` must yield 0 errors, 0 warnings, 0 infos.
3. `flutter test` must pass all tests across the test suite (currently 219/219 tests).
4. Transient platform files (`linux/`, `macos/`, `windows/`) must be restored via `git checkout -- linux/ macos/ windows/`.

---

## 2. Audio Playback Dual-Engine Invariants
- **Web / PWA**:
  - Primary: Native HTML5 `<audio>` streaming 320kbps AAC from JioSaavn CDN (`aac.saavncdn.com`). Enables continuous background audio on iOS Safari / PWA when locked.
  - Secondary Safety Net: Hidden YouTube IFrame Player (`web/dilse_web_player.js`) with silent background audio keeper (`bgAudio`) and Cloudflare `/stream?v=` CORS bypass proxy on YouTube Error 150.
  - Never stream raw YouTube audio directly on the web browser without CORS negotiation.
- **Mobile (Android / iOS)**:
  - Stream Cascade: JioSaavn 320k AAC $\to$ Format 18 MP4 AAC $\to$ WebM Opus 251 $\to$ AudioOnly 140 $\to$ YTM InnerTube.
  - Dual-Deck Crossfade (`_playerA`, `_playerB`): 3.5s volumetric crossfade. When crossfade completes, always release ExoPlayer hardware decoders by clearing audio source (`setAudioSource(null)`).
  - Track Completion Watchdog: Relax strict duration comparisons to an 8-second VBR drift tolerance to prevent EOF race condition deadlocks.
  - Full background service integration with `audio_service` and notification channel `com.example.music_app.channel.audio_playback_v3`.

---

## 3. Search & Metadata Integrity
- **Tier 1 (Studio Priority)**: JioSaavn mobile API (`&cc=in&api_version=4&ctx=android` with `User-Agent: SaavnAndroid/9.0.0`) for pristine 320kbps releases with zero geo-fencing.
- **Tier 2 (Official Studio Fallback)**: YouTube Music InnerTube (`YouTubeMusicClient`) for official studio tracks.
- **Tier 3 (Safety Net Fallback)**: YouTube Standard backend via Render (`/search`) only if Tier 1 + Tier 2 yield fewer than 8 genuine songs.
- **Canonical Deduplication (`CanonicalSongDedup`)**:
  - Unicode diacritics stripping, noise token stripping (`(official)`, `(video)`, `ft.`, `feat.`, `lyrical`).
  - Levenshtein title similarity threshold ($\ge 0.82$).
  - Never assign streams or thumbnails blindly using `item[0]` without title/artist match validation.
  - Reject covers, karaoke versions, or tribute tracks replacing studio masters or saved user playlists.

---

## 4. Recommendation & Personalization Engine
- **On-Device Scoring (`TasteMatrixScorer`)**:
  - Personalized scoring incorporating artist affinity, language preference, and liked song boost.
  - **Artist Fatigue Filter**: Enforce maximum of 2 songs per artist in any sliding window of 4 consecutive tracks.
- **Queue Pipeline**:
  - YTM seed radio candidates $\to$ `TasteMatrixScorer` on-device ranking $\to$ `CanonicalSongDedup` $\to$ JioSaavn 1:1 square artwork enrichment $\to$ JioSaavn 320k stream pre-warming.

---

## 5. Offline & Data Protection Strategy
- **Local Media**: `DeviceAudioService` scans device storage for `.mp3`, `.m4a`, `.flac`, `.wav`, `.aac`, `.ogg` and plays directly via `FileAudioSource(Uri.file(path))`.
- **Zero-Loss Data Backup (`DataSnapshotService`)**: 3-tier snapshot protection (Document Directory, App Support Directory, Temp Directory) for version rollbacks and upgrades.
- **Session Persistence**: App pause triggers `persistPlaybackSession()` saving song ID, metadata, and exact timestamp to `SharedPreferences` for Home screen Quick Resume.
