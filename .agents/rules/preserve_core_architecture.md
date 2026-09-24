# Core Architecture Preservation Rule

> **CRITICAL INVARIANT**: NEVER break or compromise the core audio playback, multi-tier search, or metadata integrity of the application. If any PR, branch, or refactor threatens or breaks these core systems, DO NOT ACCEPT IT.

## 1. Zero-Regression PR / Code Review Rule
Before accepting, merging, or proposing any changes or pull requests:
1. **Test Suite Must Pass**: Always run `flutter test` and `flutter analyze`. If any test fails or analyzer warnings appear, reject/fix before proceeding.
2. **Zero Blind Overwrites**: Never assign streams or thumbnails blindly using `item[0]` or `indexOf(item) == 0`. Every stream and artwork association must be strictly validated for title and artist consistency via `CanonicalSongDedup.areDuplicateSongs`.
3. **No Cover / Karaoke Hijacking**: Reject any code that allows covers, karaoke versions, or tribute tracks to replace original studio master tracks or overwrite saved user playlists/liked songs.

## 2. Audio Playback Dual-Engine Invariants
- **Web / PWA**:
  - Primary: Native HTML5 `<audio>` streaming 320kbps AAC from JioSaavn CDN (`aac.saavncdn.com`). Enables 100% continuous background audio playback on iOS Safari / PWA when iPhone screen is locked.
  - Secondary Safety Net: Invisible YouTube IFrame Player (`web/dilse_web_player.js`) with silent background audio keeper (`bgAudio`). Ensures zero playback failures if a track is not on JioSaavn or network drops.
  - Never stream YouTube raw audio directly on the web browser (prevents 403 Forbidden and IP bans).
- **Mobile (Android / iOS)**:
  - Direct 320kbps JioSaavn CDN stream via `just_audio` hardware pipeline.
  - Fallback to on-device YouTube audio extraction and Render proxy if needed.
  - Full background service integration with `audio_service` and Android notification channel `com.example.music_app.channel.audio_playback_v3`.

## 3. Search Engine Hierarchy
- **Tier 1 (Studio Priority)**: JioSaavn mobile API (`&cc=in&api_version=4&ctx=android` with `User-Agent: SaavnAndroid/9.0.0`) for pristine 320kbps releases with zero geo-fencing.
- **Tier 2 (Official Studio Fallback)**: YouTube Music InnerTube (`YouTubeMusicClient`) for official studio tracks.
- **Tier 3 (Safety Net Fallback)**: YouTube Standard backend via Render (`/search`) only if Tier 1 + Tier 2 yield fewer than 8 genuine songs.
- **Canonical Deduplication**: Cross-engine results must always pass through `CanonicalSongDedup` to eliminate duplicates and filter non-music noise.
