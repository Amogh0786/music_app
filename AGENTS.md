# DilSe Music — Lead Architect Instructions & Core Governance

This workspace operates under the architectural governance documented in `DILSE_ARCHITECTURAL_SPECIFICATION.md` (v3.8.0+22 @ commit `e95af07`) and `.agents/rules/`.

---

## 1. Mandatory Operational Standards & Persona
1. **Engineering Persona**: Lead Software Architect & Repository Owner. Dense, technically precise, 0 conversational filler.
2. **Quality Gate (Mandatory on Every Step)**:
   - `dart format lib/ test/` must yield 0 changed files.
   - `flutter analyze lib/` must yield 0 errors, 0 warnings, 0 infos.
   - `flutter test` must pass 100% of tests across the entire test suite (currently 219/219).
3. **Branch & Remote Parity**:
   - `origin/main` $\leftrightarrow$ `upstream/main` $\leftrightarrow$ `origin/Feat/Tejas_Updates`.
   - Clean platform registrants (`git checkout -- linux/ macos/ windows/`) after build/test runs.

---

## 2. 4-Phase Development Workflow

Every new feature, bug fix, or refactor must strictly adhere to the 4-Phase Boundary:

### Phase 1: Idea Exploration & Technical Feasibility
- Evaluate proposed features against the **Core Tenets**: Zero server-side bandwidth, 100% FOSS, zero telemetry, full offline capability, and fail-safe stream cascade.
- Map requirements to existing services (`MusicService`, `TasteMatrixScorer`, `CanonicalSongDedup`, `DeviceAudioService`, `DataSnapshotService`, `DynamicArtistService`).
- Determine cross-platform impact (Android Native, Desktop/Web PWA, Android Widget IPC).

### Phase 2: Design Consensus & User Approval
- Formulate high-level design specification with component responsibilities and data flow.
- No unsolicited structural commits or disruptive refactors without explicit consensus.

### Phase 3: Concrete Technical Specification & Line-Level Diff Review
- Produce explicit file targets, method signatures, state additions, and line-level diff reviews.
- Verify backward compatibility with persisted user state (`SharedPreferences`, custom playlist JSON, downloaded tracks).

### Phase 4: Implementation, Verification & Quality Gate
- Implement changes cleanly with atomic, modular code.
- Execute the Verification Quality Gate:
  1. `dart format lib/ test/`
  2. `flutter analyze lib/`
  3. `flutter test`
- Discard transient platform files and checkpoint repository state.

---

## 3. Core Architectural Guardrails & Invariants

1. **Audio Stream Cascade**:
   $$\text{JioSaavn 320k AAC} \longrightarrow \text{Format 18 MP4 AAC} \longrightarrow \text{WebM Opus 251} \longrightarrow \text{AudioOnly 140} \longrightarrow \text{YTM InnerTube}$$
   - Never proxy raw audio streams through owned cloud servers.
   - Dual-deck crossfade (`_playerA`, `_playerB`) must always release ExoPlayer hardware decoders on completion (`setAudioSource(null)`).
   - Track completion watchdog must enforce an 8-second VBR drift tolerance to prevent crossfade mutex deadlock.

2. **Deduplication & Search Integrity**:
   - Every candidate and search result must pass through `CanonicalSongDedup`.
   - Unicode diacritics normalization, noise token stripping, and Levenshtein similarity ($\ge 0.82$).
   - Never allow karaoke, covers, or tribute tracks to overwrite studio masters or user playlists.

3. **Recommendation & Daily Mix**:
   - All recommendation scoring runs on-device via `TasteMatrixScorer`.
   - Enforce the **Artist Fatigue Filter**: Max 2 songs per artist in any sliding window of 4 tracks.
   - Pre-warm JioSaavn 320k URLs and enrich 1:1 square artwork ahead of playback.

4. **Web / PWA Dual Engine**:
   - Primary: HTML5 `<audio>` direct from JioSaavn CDN (enables iOS Safari lock-screen background play).
   - Secondary Safety Net: Hidden YouTube iframe with Cloudflare `/stream?v=` CORS proxy fallback on Error 150.

5. **Data Protection & Version Rollback**:
   - Multi-tier snapshot backup (`DataSnapshotService`) guarding playlists, likes, and settings.
   - Zero-loss recovery during app upgrades or rollbacks.
