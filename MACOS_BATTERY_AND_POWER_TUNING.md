# macOS Battery & Power Management Tuning Guide

**Date Created:** October 13, 2026  
**System:** macOS 27.0.1 (Build 26A434) on Apple Silicon  
**Context:** Diagnostic investigation into unexpected standby battery drops when the laptop is idle / lid closed.

---

## 1. Executive Summary & Diagnostic Findings

### Hardware Health Baseline
* **Cycle Count:** 137 (very low wear).
* **Maximum Capacity:** 97%.
* **Condition:** Normal.
* **Conclusion:** The physical battery is in pristine condition. All drops are software/OS-induced sleep assertions and background dark wakes.

---

### Root Cause Analysis (What Caused the Overnight Drain)

During the forensic check using `pmset` and macOS unified log analysis (`/usr/bin/log`), two primary issues were uncovered:

#### 1. Rogue 9-Hour Audio Sleep Assertion (WhatsApp)
* **Log Evidence:**
  ```text
  PID 759(coreaudiod) Released PreventUserIdleSystemSleep "com.apple.audio.context362.preventuseridlesleep" 09:02:56
  HALB_PowerAssertion::Release: releasing power assertion ID 34996 on behalf of PID 1696
  ```
* **Culprit Process:** `PID 1696`:
  `/Applications/WhatsApp.app/Contents/PlugIns/ServiceExtension.appex`
* **Mechanism:** WhatsApp opened an audio context at ~11:11 PM (e.g., from a voice message or notification chime) and failed to release it for **9 hours and 2 minutes**. This kept `coreaudiod` active and prevented deep hardware sleep.

#### 2. Excessive Dark Wakes (45 Wakes in One Night)
* **Log Evidence:**
  ```text
  Sleep/Wakes since boot: 108 | Dark Wake Count in this sleep cycle: 45
  ```
* **Mechanism:** In macOS 27, Apple forces `powernap 1` and `tcpkeepalive 1` on battery by default. The system woke up every 10–15 minutes (~900 seconds) for:
  * `com.apple.dasd` (Duet Activity Scheduler) triggering `searchd.heartbeat` (Spotlight indexer).
  * `mDNSResponder:maintenance` (Network upkeep).
  * Mail, iCloud, and push notification syncs.

---

## 2. Tuning Strategy: "Option A"

The objective of **Option A** is to retain **Find My Mac** location tracking while eliminating unnecessary wakeups and preventing background apps from locking the CPU overnight.

### Settings Configuration Matrix

| Setting | Parameter | Option A Value | Purpose |
| :--- | :--- | :--- | :--- |
| **Power Nap (Battery)** | `powernap` | `0` (Disabled) | Stops Spotlight, Mail, and iCloud from waking the CPU while sleeping. |
| **TCP Keep-Alive (Battery)** | `tcpkeepalive` | `1` (Enabled) | **Keeps Find My Mac functioning** and network registration active for location pings. |
| **Low Power Mode** | `lowpowermode` | *Untouched* | Left as preferred by user. |

---

## 3. How to Apply Option A

Because `pmset` modifies system-wide power management configurations, run the following command in your Terminal:

```bash
sudo pmset -b powernap 0
```

*(Enter your Mac password when prompted. The `-b` flag ensures this applies specifically to **Battery Power**, leaving AC charger behavior unaffected).*

---

## 4. Verification Commands

To verify that the settings applied correctly:

```bash
# Check custom battery and AC profiles
pmset -g custom

# Verify that under "Battery Power", powernap is 0 and tcpkeepalive is 1:
# Battery Power:
#   powernap         0
#   tcpkeepalive     1
```

To check for any currently active sleep-preventing assertions at any time:
```bash
pmset -g assertions
```

---

## 5. How to Revert to macOS Defaults (If Ever Needed)

If you ever wish to return to macOS 27 factory defaults:

```bash
sudo pmset -b powernap 1
```

---

## 6. Future Troubleshooting Playbook

If you ever notice unexpected battery drops in the future, follow this 3-step diagnostic routine:

### Step 1: Check Active Sleep Assertions
```bash
pmset -g assertions
```
*Look for:* Any process listed under `PreventUserIdleSystemSleep` or `PreventSystemSleep`.

### Step 2: Check Recent Sleep/Wake Cycles & Dark Wakes
```bash
pmset -g log | grep -E "Sleep|Wake|DarkWake" | tail -n 25
```
*Look for:* Dark Wake counts higher than 5–10, or wake reasons showing repeating cron/dasd jobs.

### Step 3: Check for Stuck Audio Contexts
```bash
pmset -g log | grep "com.apple.audio" | tail -n 20
```
*If an app is holding `coreaudiod` open for hours:* Identify the PID and quit the offending app (e.g. WhatsApp, Spotify, or browser tabs).
