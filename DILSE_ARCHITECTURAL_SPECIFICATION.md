# DILSE MUSIC — LEAD ARCHITECTURAL SPECIFICATION & SYSTEM SYNCHRONIZATION
================================================================================
Repository: charanteja-k/music_app
Target Architecture: Cross-Platform Edge-Distributed High-Fidelity Audio Engine
Document Version: 3.5.0-PROD
Export Timestamp: 2026-09-29T12:50:00+05:30
Classification: Operational & Technical Specification
================================================================================

1. REPOSITORY METADATA AND LOCAL VERSION STATE
--------------------------------------------------------------------------------
1.1 Active Git State
- Current Active Commit SHA: 8e04b9e1eef72c48994c69ddd8e0db9904c2c652
- Current Active Branch: main
- Working Tree Status: Clean (0 uncommitted diffs; fully synchronized with remote origin/main)
- Upstream Remote URL: https://github.com/charanteja-k/music_app.git

1.2 Application Versioning
- Semantic Version: 3.5.0
- Build Number: 18
- Canonical Version String (pubspec.yaml): 3.5.0+18
- Flutter SDK Constraint: ^3.12.2
- Target Operating Environments: Android (API 24 to 34+), iOS (14.0+), Web PWA (Modern Chromium, Safari WebKit, Firefox Gecko)

1.3 Technical Documentation & Active Design Draft Locations
- lockscreen_and_notification_design.md:
  * Location: /Users/charanteja/Desktop/College_Related/my_projects/music_app/lockscreen_and_notification_design.md
  * Status: Active Architecture Draft. Specifies Android 13+ POST_NOTIFICATIONS runtime permission flow, just_audio_background notification configuration, media button wiring (skipToNext / skipToPrevious), and ic_stat_music monochrome asset integration.
- ui_overhaul_design.md:
  * Location: /Users/charanteja/Desktop/College_Related/my_projects/music_app/ui_overhaul_design.md
  * Status: Design Master Blueprint (v2.0.0-UI / v3.5.0). Governs floating frosted glass island navigation dock (sigma 30 blur), dynamic ambient aura mesh glow, PlayerArtworkStyle dual engine (Squircle 3D card vs. 60 FPS spinning vinyl turntable canvas), capsule waveform scrubber, and Apple-style grouped settings.
- CLOUDFLARE_EDGE_ARCHITECTURE.md:
  * Location: /Users/charanteja/Desktop/College_Related/my_projects/music_app/CLOUDFLARE_EDGE_ARCHITECTURE.md
  * Status: Production Edge Infrastructure Reference. Details migration from exhausted PaaS containers (Render free tier) to Cloudflare Edge Workers (dilse-edge-stream), zero cold-start latency (<5ms), 320kbps JioSaavn CDN streaming, DES-ECB edge media URL decryption, and passive failover topology.
- Additional Governance Documents:
  * .agents/rules/preserve_core_architecture.md: Non-negotiable architectural guardrails.
  * .agents/rules/release_notes.md: Semantic version changelog and release history.


2. OWNER AND GENAI OPERATIONAL PROTOCOL
--------------------------------------------------------------------------------
2.1 Assistant Role & Engineering Persona
The assistant acts with absolute technical ownership as the Lead Software Architect and Repository Owner of DilSe Music. Communication must be dense, technically precise, and free of conversational filler, sycophancy, or superficial summaries. Every recommendation must cite exact file paths, class names, data structures, and architectural trade-offs.

2.2 Task Execution Discipline
To maintain zero regressions across mission-critical audio pipelines and stateful Flutter UI trees, AI engineering agents must strictly enforce a 4-phase execution boundary:
- Phase 1: Idea Exploration & Technical Feasibility
  * Investigate existing abstractions before introducing new classes.
  * Validate package dependencies in pubspec.yaml; do not add bloatware.
- Phase 2: Design Consensus & User Approval
  * Under no circumstances may production code or refactors be committed during an exploratory or architectural phase.
  * Structural UI, data model, or audio pipeline changes require explicit user sign-off.
- Phase 3: Concrete Technical Specification & Diff Review
  * Formulate comprehensive diffs with exact line ranges.
  * Verify that stateful widgets handle mounted lifecycle checks, stream subscription cancellation, and ChangeNotifier notifications safely.
- Phase 4: Implementation, Verification, & Hot Reload
  * Apply atomic edits using dedicated replace tools.
  * Proactively execute hot_reload or hot_restart via Dart Tooling Daemon (DTD).

2.3 Verification, Testing, and Git Standards
- Formatting: All Dart files must pass `dart format lib/ test/` strictly.
- Static Analysis: `flutter analyze lib/` must return 0 errors, 0 warnings, and 0 infos. The project strictly enforces `analysis_options.yaml` (including curly_braces_in_flow_control_structures, prefer_const_constructors, avoid_unused_constructor_parameters).
- Automated Test Suite: All 106+ unit and widget tests must pass cleanly before any code is approved (`flutter test`). Specific coverage targets:
  * Canonical deduplication algorithms (`CanonicalSongDedup` in lib/services/canonical_song_dedup.dart)
  * Multi-artist token parsing (`PlaylistArtistFilter` in lib/services/playlist_artist_filter.dart)
  * Dual-deck crossfade volume math and cancellation flags (`MusicService` in lib/services/music_service.dart)
  * Client-side CSV and playlist parsing (`SpotifyImportService` in lib/services/spotify_import_service.dart)
- Commit Conventions: Conventional Commits standard strictly enforced (`feat:`, `fix:`, `chore:`, `docs:`, `test:`, `refactor:`).

2.4 Non-Negotiable Architectural Guardrails
- Zero Server-Side Audio Proxying & Bandwidth Costs: The app must NEVER stream, transcode, or proxy audio bytes through central servers. All audio streams must be decoded directly on the client device via residential IP using youtube_explode_dart or fetched directly from official CDN edges (JioSaavn 320kbps AAC).
- 100% Free & Open-Source Compliance: Licensed under MIT. Free of paid APIs, proprietary SDKs, or paywalled dependencies.
- Zero Third-Party Telemetry & Tracking: No Google Analytics, Firebase Analytics, Crashlytics, Facebook SDK, or ad trackers. Client logging is local or routed exclusively to user-controlled self-hosted backends.
- Absolute Local Offline Capability: SQLite storage (`sqflite`), persistent preferences (`shared_preferences`), downloaded audio files stored in application documents directory, and full offline playback without internet connectivity.
- Fail-Safe Stream Resolution: If an edge source or YouTube client fails, the engine must silently cascade through fallback candidates without hard-crashing or breaking the active queue.


3. CONCRETE UI AND UX DESIGN SYSTEM TOKENS
--------------------------------------------------------------------------------
3.1 Color Palette & Surface Tokens
- Background:
  * Deep Obsidian Canvas: #0B0B0F (Color(0xFF0B0B0F))
  * Pure Pitch Black: #000000 (Color(0xFF000000)) for fullscreen contrast sheets
- Surfaces & Elevations:
  * Surface Elevation 0 (Base Container): #121217 (Color(0xFF121217))
  * Surface Elevation 1 (Cards, ListTiles): #14141B (Color(0xFF14141B)) with stroke opacity Color(0xFFFFFFFF).withValues(alpha: 0.06)
  * Surface Elevation 2 (Modals, Bottom Sheets, Insets): #1E1E24 (Color(0xFF1E1E24)) / #1A1A22 (Color(0xFF1A1A22))
  * Card Border Stroke: Colors.white.withValues(alpha: 0.08) to Colors.white.withValues(alpha: 0.12)
- Accent Tokens:
  * Fallback Dynamic Accent: Apple Music Red #FA2D48 (Color(0xFFFA2D48))
  * Primary Dynamic Accent Range: Extracted via PaletteGenerator from song artwork (_dominantColor and _vibrantColor)
  * Live Accent Presets: Electric Crimson (#FA2D48), Royal Violet (#8E2DE2), Neon Emerald (#00E676), Cyber Cyan (#00E5FF), Amber Gold (#FFD600)
- Text Contrast & Opacities:
  * Primary Text: Colors.white (100% opacity, #FFFFFF)
  * Secondary Text: Colors.white.withValues(alpha: 0.70)
  * Tertiary Text / Captions: Colors.white.withValues(alpha: 0.40) or Colors.grey[400]
  * Quaternary / Inactive Icons: Colors.white24 (24% opacity)

3.2 Materials, Geometry & Physics Tokens
- Border Radii:
  * Standard Cards: BorderRadius.circular(16)
  * Large Carousel Cards / Hero Spotlight: BorderRadius.circular(20) to BorderRadius.circular(24)
  * Bottom Sheet Top Corners: BorderRadius.vertical(top: Radius.circular(28))
  * Chip / Pill Radii: BorderRadius.circular(24) or StadiumBorder()
  * Thumbnail Squircle Radii: BorderRadius.circular(8) (lists) to BorderRadius.circular(24) (Now Playing hero)
- Blur & Glassmorphism:
  * Floating Nav Dock: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0)
  * Mini-Player Background: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0)
  * Modal & Glass Overlays: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0)
- Stroke & Border Geometry:
  * Hairline Borders: 0.8dp to 1.2dp width with Colors.white.withValues(alpha: 0.10)
  * Active Gradient Progress Line: 2.5dp height with LinearGradient [dominantColor, vibrantColor]

3.3 Typography, Animation & Haptic Tokens
- Typography:
  * Primary Typeface: Inter / System Native (San Francisco on iOS, Roboto on Android)
  * Header 1 (Now Playing Title): 22sp, FontWeight.w800, letterSpacing: -0.5
  * Header 2 (Section Title): 18sp to 20sp, FontWeight.w700, letterSpacing: -0.3
  * Monospace Timestamps: FontFeature.tabularFigures() applied to all duration/position counters (TextStyle(fontFeatures: [FontFeature.tabularFigures()])) to prevent character jitter during playback scrubbing.
- Animation Curves:
  * Spring & Elastic Expansion: Curves.easeOutCubic, Curves.fastLinearToSlowEaseIn
  * Crossfade Duration: Configurable 1s to 12s (default 3s; smart dynamic tempo matching)
  * Vinyl Turntable Rotation: Continuous 60 FPS AnimationController (20s per 360-degree rotation)
- Tactile Haptics:
  * HapticFeedback.selectionClick(): Scrubbing waveform, dragging sliders, micro-interactions
  * HapticFeedback.lightImpact(): Tab switching, track skip triggers, quick filters
  * HapticFeedback.mediumImpact(): Like/unlike toggles, custom playlist creations

3.4 Complete Component Tree Specifications
- Global Navigation (FloatingNavDock in lib/widgets/floating_nav_dock.dart):
  * Floats 24dp above screen bottom with 24dp horizontal margin.
  * Height: 64dp. ClipRRect with BackdropFilter(sigma: 30), border stroke white 12% alpha.
  * Nav items: Listen Now (Home), Search, Library, Profile. Smooth icon color transition to active accent.
- Mini-Player (MiniPlayer in lib/widgets/mini_player.dart):
  * Docked directly above FloatingNavDock (bottom offset ~96dp).
  * Gestures: Horizontal drag (onHorizontalDragEnd) detecting swipe velocity > 200 or delta > 40px: Swipe Left -> nextSong(); Swipe Right -> previousSong(). Vertical drag up (onVerticalDragEnd) -> Navigator.push to PlayerScreen.
  * Bottom progress line: 2.5dp linear gradient connected to positionStream.
  * Embedded AnimatedEqualizer (lib/widgets/animated_equalizer.dart): 3-bar jumping equalizer pulsing dynamically when isPlaying is true.
- Now Playing Screen (PlayerScreen in lib/screens/player_screen.dart):
  * Ambient Mesh Glow: Rotating radial gradients centered behind artwork, blending dominantColor, vibrantColor, and pitch black.
  * PlayerArtworkStyle Selector: Switch between (A) Squircle 3D Card with ambient colored drop-shadow, and (B) 60 FPS spinning vinyl turntable canvas (VinylRecordPlayer in lib/widgets/vinyl_record_player.dart) featuring central spindle hole, concentric micro-grooves, dynamic highlight glare, and stylus tonearm.
  * Waveform Scrubber (WaveformScrubber in lib/widgets/waveform_scrubber.dart): Capsule waveform visualization with seekable scrub gestures, elapsed/remaining tabular counters.
  * Lyrics Drawer (AnimatedLyrics in lib/widgets/animated_lyrics.dart): Synchronized karaoke-style auto-scroll, smooth line highlighting, Romanized / English transliteration toggle (Telugu/Devanagari scripts), and ScreenWakeService wakelock retention.
  * Reorderable Queue Bottom Sheet: ReorderableListView with drag handles for on-the-fly track reordering, swipe-to-dismiss deletion, and add-to-playlist shortcuts.
- Discovery and Home Screen (HomeScreen in lib/screens/home_screen.dart):
  * Circadian personalized greeting ("Good Morning", "Late Night Vibes") with current user profile avatar.
  * Hero Spotlight Carousel (SpotlightBillboard in lib/widgets/spotlight_billboard.dart): Auto-paging banner spotlighting chartbusters and trending anthems.
  * Interactive Activity & Mood Chips: Horizontal filter row (Energetic, Chill, Focus, Workout, Sleep) with zero emojis; dynamically filters the catalog.
  * Horizontal Content Carousels: "Daily Mixes", "Top Charts", and "Made For You" (horizontal sliding multi-item card grid matching Spotify Daily Mix layout).
  * Dark Shimmer Skeleton Loaders (ShimmerLoading in lib/widgets/shimmer_loading.dart): Elegant pulsating dark grey skeletons for seamless async data loading.
- Search and Explore (SearchScreen in lib/screens/search_screen.dart):
  * Debounce Controller: 250ms Timer on search text changes to prevent excessive API load.
  * 2-Column Genre Grid: CategoryCard widgets with angled gradient tiles and high-contrast badges.
  * Search domain filter chips and recent search history with dismissible chips.
  * Search Results: Connected via playPlaylist(_searchResults, index) to ensure uninterrupted search queue playback, active song highlighting, and animated equalizer indicators.
- Library and Storage (LibraryScreen in lib/screens/library_screen.dart):
  * Storage Meter: Displays allocated MBs vs total available storage for offline downloads.
  * Tabbed Segments: Downloads, Liked Songs, Imported Playlists, and History.
  * Batch management: Multi-track selection for bulk downloading, queueing, or deletion.
- Profile Screen (ProfileScreen in lib/screens/profile_screen.dart):
  * Profile picture customizer with persistent image storage via PreferencesService.
  * "TOP STREAMED ARTISTS": Ranked artist listening statistics with Play All and Shuffle buttons, play count badges, and real-time jumping equalizers.
- Settings and Theme Studio (SettingsScreen in lib/screens/settings_screen.dart):
  * Apple-style inset grouped containers (#1E1E24).
  * Interactive Live Accent Studio with instant palette switching.
  * Audio Quality Selector: Data Saver (64 kbps), Normal (128 kbps), High Fidelity AAC (160+ kbps), and Studio Master (320 kbps).


4. AUDIO ENGINE PIPELINE AND EDGE ROUTING INFRASTRUCTURE
--------------------------------------------------------------------------------
4.1 Dual-Deck Audio Pipeline
- Architecture: Implemented in lib/services/music_service.dart using two distinct just_audio `AudioPlayer` instances: `_playerA` and `_playerB`.
- Role Swapping: One instance acts as `_activePlayer` while the second acts as `_standbyPlayer`. Upon crossfading or track transition, their roles invert.
- Equal-Power Crossfade Curve:
  * Formula:
    V_out(t) = cos(0.5 * pi * (t / T))
    V_in(t)  = sin(0.5 * pi * (t / T))
    where t is elapsed fade time and T is total crossfade duration (PreferencesService().crossfadeSeconds).
  * Acoustic Property: V_out^2 + V_in^2 = 1.0 at all points in time, eliminating the perceived volume drop (dip) inherent in linear volume ramps.
- Session Management & Cancellation:
  * Each crossfade generates an incremented `_fadeSessionId`.
  * If a user manually taps Next, Previous, or scrubs during an active fade, `_cancelActiveFade()` is invoked immediately, cancelling active timers, clamping target volumes to 1.0, and pausing the retired deck.

4.2 Format Hierarchy and Stream Resolution
- Multi-Source 3-Tier Resolution:
  * Tier 1 (Studio Master): Direct JioSaavn 320kbps MP4 AAC stream (streamUrl from edge search). Extracted directly from saavncdn edges, bypassing YouTube entirely.
  * Tier 2 (On-Device YouTubeExplode Resolution):
    - Format 18 (muxed MP4 AAC, 360p stereo): Highest priority for native ExoPlayer / AVPlayer hardware decoders. Eliminates DASH single-segment parser errors.
    - WebM Opus (itag 251, 160kbps Opus): High-fidelity secondary candidate for Android ExoPlayer Matroska demuxer.
    - AudioOnly MP4 (itag 140, 128kbps AAC): Tertiary candidate.
  * Tier 3 (YouTube Music InnerTube WEB_REMIX): Direct studio release tracks queried via YouTubeMusicClient().
- Elimination of Datacenter IP Blocks:
  * Audio streams are resolved entirely client-side using the user's residential mobile carrier or Wi-Fi IP address. Central servers never touch audio bytes, preventing Google/YouTube datacenter IP bans and reducing central hosting bandwidth costs to $0.00.

4.3 Web Audio Limiter and Studio Gain
- Implementation: web/dilse_web_player.js
- Signal Flow:
  `<audio>` Deck Element -> MediaElementAudioSourceNode -> BiquadFilterNode (5-Band Graphic Equalizer) -> DynamicsCompressorNode (Brickwall Limiter) -> GainNode (Studio Makeup Gain) -> AudioDestinationNode.
- Brickwall Limiter Calibration:
  * Threshold: -0.5 dB
  * Knee: 4.0 dB
  * Ratio: 12.0:1
  * Attack: 0.003s
  * Release: 0.250s
- Makeup Gain:
  * Value: +3.5 dB (linear multiplier ~1.48)
  * Purpose: Prevents clipping distortion when bass bands (+6dB to +12dB) are boosted, while elevating low-bitrate streams to broadcast studio loudness.

4.4 Cloudflare Edge Worker Configuration
- Deployed Worker Base URL:
  https://dilse-edge-stream.charanteja-kondakalla030206.workers.dev
  (Configured in lib/services/api_config.dart as defaultCloudflareWorkerUrl).
- Routing Map & Endpoint Specifications:
  * GET /jio/search?q={query}&limit={n}:
    Queries JioSaavn search API, decrypts payload media URLs, parses 320kbps streams, demotes compilation albums via COMPILATION_REGEX, filters covers/karaoke, and returns normalized JSON arrays.
  * GET /jio/suggestions?q={query}:
    Provides sub-50ms autocomplete suggestions for the search interface.
  * GET /jio/recommendations?id={songId}&limit={n}:
    Fetches algorithmic radio recommendations based on seed track ID.
  * GET /jio?title={title}&artist={artist}:
    Single track exact resolver. Matches title and artist against JioSaavn's catalog to upgrade third-party or YouTube tracks to 320kbps studio audio.
  * GET /lyrics?title={title}&artist={artist}&lang={lang}&duration={sec}:
    Multi-provider lyrics engine. Queries LRCLIB, JioSaavn, and Musixmatch fallbacks.
  * GET /stream?v={videoId}:
    Edge stream routing descriptor and fallback proxy.
- Edge Decryption of JioSaavn Payloads:
  * JioSaavn media URLs are encrypted with DES-ECB using static key: 38346585 (ASCII bytes [0x33, 0x38, 0x33, 0x34, 0x36, 0x35, 0x38, 0x35]).
  * Worker uses CryptoJS.DES.decrypt(cipherText, key, { mode: CryptoJS.mode.ECB, padding: CryptoJS.pad.Pkcs7 }) to extract raw audio URLs (e.g. https://aac.saavncdn.com/..._320.mp4).
- Deduplication & Scraper Filtering Rules:
  * COMPILATION_REGEX Demotion: Demotes tracks matching "best of", "greatest hits", "top \d+", "collection", "compilation", "party mix", "jukebox", "hits of", "evergreen", "all time hits" in favor of genuine original motion picture soundtracks.
  * Genuine Song Filtering (CanonicalSongDedup.isGenuineSong): Rejects YouTube videos containing "trailer", "teaser", "promo", "reaction", "interview", "review", "short", "status", "bgm ringtone", or non-music commentary.
  * Lyrics Scoring: LRCLIB responses containing synced LRC timestamps receive a +350 confidence score over plain unsynced text.

4.5 Passive Failover Architecture
- Secondary Backend: FastAPI container deployed at https://music-backend-4kel.onrender.com (ApiConfig._defaultRenderUrl).
- Status & Failover: Used strictly as passive secondary fallback if Cloudflare Workers exceed daily free limits or user configures a custom self-hosted server URL in Settings.


5. NATIVE PLATFORM INTEGRATION AND BACKGROUND MEDIA SESSIONS
--------------------------------------------------------------------------------
5.1 Lock Screen & Notification Shade Architecture
- Background Service: Powered by `just_audio_background: ^0.0.1-beta.17`.
- Initialization (lib/main.dart):
  ```dart
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.charan.music_app.channel.audio',
    androidNotificationChannelName: 'DilSe Audio Playback',
    androidNotificationOngoing: false,
    androidStopForegroundOnPause: false,
    androidNotificationIcon: 'drawable/ic_stat_music',
  );
  ```
- MediaItem Metadata Mapping:
  * ID: song.id.value
  * Title: song.title
  * Artist: song.author
  * Album: 'DilSe'
  * ArtUri: Uri.parse(MusicService.getHdThumbnail(song.id.value))
  * Duration: song.duration
- Action Button Layout:
  Standard music navigation: [⏮️ Previous Track] [⏯️ Play / Pause] [⏭️ Next Track].
- Custom Notification Icon:
  Monochrome vector drawable located at android/app/src/main/res/drawable/ic_stat_music.xml (required for crisp rendering on Android 10–14 status bars).

5.2 Android 13+ (API 33+) POST_NOTIFICATIONS Runtime Flow
- Orchestration: `NotificationPermissionService` in lib/services/notification_permission_service.dart.
- Contextual Triggering: Permission is NEVER requested on cold application launch. It is triggered contextually when the user taps play on their first song.
- Modal Copy: Clearly informs the user that notification access is required for lock screen media controls, background playback, and headphone button integration.
- Recovery Logic: If denied, the app continues audio playback in foreground without crashing and offers a deep-link to app notification settings in SettingsScreen.

5.3 Foreground Service Lifecycle Flags
- `androidNotificationOngoing: false`:
  Allows the notification to be dismissed by the user when playback is paused.
- `androidStopForegroundOnPause: false`:
  Prevents the Android OS from terminating the audio background service immediately when paused, enabling resumption from lockscreen after extended idle periods.
- `android:stopWithTask="true"` (AndroidManifest.xml):
  Terminates background audio tasks when the user clears the app from Android's Recent Tasks switcher.

5.4 Queue Boundary & Headphone Button Handling
- Media Button Interception: `AudioHandler` in lib/services/audio_handler.dart wires `skipToNext()` and `skipToPrevious()` directly to the `MusicService` singleton.
- Infinite Auto-Chaining: When fewer than 5 songs remain in the queue, `_checkAndPreloadNextQueue()` triggers `_fetchNextRecommendations()`, querying similar tracks across active playlist artists to create an infinite, uninterrupted radio stream.

5.5 iOS and Web Background Sessions
- iOS Integration: Configured with `AVAudioSessionCategoryPlayback` via `just_audio`. Connects to `MPNowPlayingInfoCenter` and remote command center (Next, Prev, Play, Pause, Seek).
- iOS Safari Background Loop: `startBgAudio()` in web/dilse_web_player.js maintains an invisible, looped silent audio element to prevent mobile Safari WebKit from suspending the JavaScript execution context when switching tabs or locking screen.
- Web MediaSession API: `navigator.mediaSession.setActionHandler` wired for play, pause, previoustrack, nexttrack, and seekto.


6. KNOWN EDGE CASES, ARCHITECTURAL DEBT AND ROADMAP
--------------------------------------------------------------------------------
6.1 Active Edge Cases & Vulnerabilities
- Mobile Network Cell Handoffs:
  Switching from LTE to 5G or Wi-Fi causes transient socket disconnects in ExoPlayer's `HttpDataSource`, leading to momentary buffering pauses. Mitigated by `LockCachingAudioSource` caching upcoming blocks to temp storage.
- Aggressive OEM Battery Killers:
  Aggressive task managers on Xiaomi (MIUI), Samsung (OneUI), and OnePlus (OxygenOS) can kill background services after ~15–30 minutes of screen-off playback unless the app is manually whitelisted in "Battery Optimization -> Unrestricted".
- Rapid Next-Track Spam:
  Rapidly hammering the Next button can initiate multiple overlapping crossfade cancellations. Mitigated by `_cancelActiveFade()` and incrementing `_fadeSessionId`.
- Web PWA Memory Accumulation:
  Multi-hour playback on Flutter Web can retain detached media elements. Addressed by clean DOM element recreation in `recreateCleanAudioDecks()`.

6.2 Contribution Targets & Modularization Roadmap
- Service Provider Interfaces (SPI):
  Decouple monolithic scraping logic from `MusicService` into clean interfaces:
  * `IMetadataProvider`: Abstract contract for JioSaavn, YouTube Music, and Spotify import metadata.
  * `ILyricsProvider`: Pluggable lyrics provider interface (LRCLIB, Musixmatch, JioSaavn).
  * `IStreamResolver`: Pluggable audio candidate resolution pipeline.
- Provider Unit Testing:
  Construct offline recorded mock fixtures in `test/providers/` for deterministic CI test validation without internet requirements.
- Good First Issues:
  * Transliteration cache persistence in SQLite database.
  * Dynamic visual sleep timer countdown ring.
  * Manual drag reorder handles in mini-player queue drawer.
================================================================================
END OF SPECIFICATION
