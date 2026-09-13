import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/preferences_service.dart';
import '../services/music_service.dart';
import '../services/update_service.dart';
import '../services/notification_permission_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  final _prefs = PreferencesService();
  final _musicService = MusicService();

  String _appVersion = '';
  String _buildNumber = '';
  bool _isCheckingUpdate = false;
  bool _notificationGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPackageInfo();
    _checkNotificationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationStatus();
    }
  }

  Future<void> _checkNotificationStatus() async {
    final granted = await NotificationPermissionService.isPermissionGranted();
    if (mounted) {
      setState(() => _notificationGranted = granted);
    }
  }

  Future<void> _loadPackageInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (_) {}
  }

  final List<Color> _availableColors = [
    const Color(0xFFFA2D48), // Apple Red
    const Color(0xFF1DB954), // Spotify Green
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF2196F3), // Blue
    const Color(0xFFFF9800), // Orange
  ];

  void _showSleepTimerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24).withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.white38,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.bedtime, color: Color(0xFFFA2D48), size: 22),
                        SizedBox(width: 10),
                        Text(
                          'Sleep Timer',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_musicService.isSleepTimerActive)
                      Text(
                        _musicService.sleepTimerLabel,
                        style: const TextStyle(color: Color(0xFFFA2D48), fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_musicService.isSleepTimerActive)
                  ListTile(
                    leading: const Icon(Icons.timer_off_outlined, color: Colors.redAccent),
                    title: const Text('Turn Off Timer', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    subtitle: Text('Active: ${_musicService.sleepTimerLabel}', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    onTap: () {
                      _musicService.cancelSleepTimer();
                      Navigator.pop(context);
                      setState(() {});
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.white),
                  title: const Text('15 Minutes', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _musicService.startSleepTimer(const Duration(minutes: 15));
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.white),
                  title: const Text('30 Minutes', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _musicService.startSleepTimer(const Duration(minutes: 30));
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.white),
                  title: const Text('45 Minutes', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _musicService.startSleepTimer(const Duration(minutes: 45));
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: Colors.white),
                  title: const Text('1 Hour', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _musicService.startSleepTimer(const Duration(hours: 1));
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.music_note_outlined, color: Colors.white),
                  title: const Text('End of Current Track', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    _musicService.setStopAtEndOfTrack(true);
                    Navigator.pop(context);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_prefs, _musicService]),
      builder: (context, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          appBar: AppBar(
            backgroundColor: const Color(0xFF121212),
            title: const Text('Settings'),
            elevation: 0,
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSectionTitle('Audio Preferences'),
              SwitchListTile(
                title: const Text('Crossfade Tracks', style: TextStyle(color: Colors.white)),
                subtitle: Text('Smooth transition between songs', style: TextStyle(color: Colors.grey[400])),
                activeThumbColor: _prefs.themeColor,
                value: _prefs.crossfadeEnabled,
                onChanged: (val) {
                  _prefs.setCrossfade(val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Crossfade set to ${val ? "On" : "Off"}'), backgroundColor: _prefs.themeColor),
                  );
                },
              ),
              ListTile(
                title: const Text('Sleep Timer', style: TextStyle(color: Colors.white)),
                subtitle: Text(
                  _musicService.isSleepTimerActive
                      ? 'Active: ${_musicService.sleepTimerLabel}'
                      : 'Automatically stop playback after set duration',
                  style: TextStyle(color: _musicService.isSleepTimerActive ? _prefs.themeColor : Colors.grey[400]),
                ),
                trailing: Icon(
                  _musicService.isSleepTimerActive ? Icons.bedtime : Icons.bedtime_outlined,
                  color: _musicService.isSleepTimerActive ? _prefs.themeColor : Colors.white70,
                ),
                onTap: () => _showSleepTimerSheet(context),
              ),
              const Divider(color: Colors.white24, height: 32),

              _buildSectionTitle('Lock Screen & Notification Controls'),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (_notificationGranted ? Colors.green : _prefs.themeColor).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _notificationGranted ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                    color: _notificationGranted ? Colors.greenAccent : _prefs.themeColor,
                    size: 22,
                  ),
                ),
                title: const Text('Lock Screen Player Controls', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: Text(
                  _notificationGranted
                      ? 'Active • Playback controls appear on lock screen and notification shade'
                      : 'Disabled • Tap to enable lock screen media controls & album artwork',
                  style: TextStyle(color: _notificationGranted ? Colors.white60 : Colors.amberAccent, fontSize: 12),
                ),
                trailing: _notificationGranted
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                            SizedBox(width: 4),
                            Text('Active', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    : ElevatedButton(
                        onPressed: () async {
                          await NotificationPermissionService.requestNotificationPermission(context);
                          _checkNotificationStatus();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _prefs.themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Enable', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                onTap: () async {
                  await NotificationPermissionService.requestNotificationPermission(context);
                  _checkNotificationStatus();
                },
              ),
              const Divider(color: Colors.white24, height: 32),

              _buildSectionTitle('Storage & Cache'),
              ListTile(
                title: const Text('Maximum Cache Size', style: TextStyle(color: Colors.white)),
                subtitle: Text('${_prefs.cacheSizeMB.toInt()} MB limit for downloaded tracks', style: TextStyle(color: Colors.grey[400])),
              ),
              Slider(
                activeColor: _prefs.themeColor,
                inactiveColor: Colors.white24,
                value: _prefs.cacheSizeMB,
                min: 100,
                max: 2000,
                divisions: 19,
                label: '${_prefs.cacheSizeMB.toInt()} MB',
                onChanged: (val) => _prefs.setCacheSize(val),
              ),
              const Divider(color: Colors.white24, height: 32),

              _buildSectionTitle('Appearance & Theme'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('Select Accent Color', style: TextStyle(color: Colors.grey[400])),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _availableColors.map((color) {
                    final isSelected = _prefs.themeColor.toARGB32() == color.toARGB32();
                    return GestureDetector(
                      onTap: () => _prefs.setThemeColor(color),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(color: Colors.white24, height: 32),

              _buildSectionTitle('Search Data'),
              ListTile(
                title: const Text('Clear Search History', style: TextStyle(color: Colors.white)),
                trailing: Icon(Icons.delete_outline, color: Theme.of(context).primaryColor),
                onTap: () {
                  _prefs.clearSearchHistory();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: const Text('Search history cleared'), backgroundColor: _prefs.themeColor),
                  );
                },
              ),
              const Divider(color: Colors.white24, height: 32),

              _buildSectionTitle('App Updates & Version'),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _prefs.themeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.system_update_alt_rounded, color: _prefs.themeColor, size: 22),
                ),
                title: Text(
                  _appVersion.isEmpty
                      ? 'Music App'
                      : 'Music App v$_appVersion (${_buildNumber.isEmpty ? "release" : "Build $_buildNumber"})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _isCheckingUpdate
                      ? 'Checking GitHub for new releases…'
                      : 'Tap to check for updates',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                trailing: _isCheckingUpdate
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _prefs.themeColor,
                        ),
                      )
                    : Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey[500], size: 14),
                onTap: _isCheckingUpdate ? null : _handleCheckForUpdates,
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }
    );
  }

  Future<void> _handleCheckForUpdates() async {
    if (_isCheckingUpdate) return;
    setState(() => _isCheckingUpdate = true);

    try {
      final updateInfo = await UpdateService().checkForUpdate();
      if (!mounted) return;

      if (updateInfo == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reach GitHub Releases. Please check your internet connection.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } else if (!updateInfo.hasUpdate) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You're on the latest version (${updateInfo.tagName})! 🎉",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1DB954),
          ),
        );
      } else {
        _showUpdateSheet(context, updateInfo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Update check failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  void _showUpdateSheet(BuildContext context, AppUpdateInfo info) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UpdateModalSheet(
        info: info,
        themeColor: _prefs.themeColor,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: _prefs.themeColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _UpdateModalSheet extends StatefulWidget {
  final AppUpdateInfo info;
  final Color themeColor;

  const _UpdateModalSheet({required this.info, required this.themeColor});

  @override
  State<_UpdateModalSheet> createState() => _UpdateModalSheetState();
}

class _UpdateModalSheetState extends State<_UpdateModalSheet> {
  bool _isDownloading = false;
  int _downloadProgress = 0;
  String _statusText = '';
  String? _errorMessage;

  Future<void> _startUpdate() async {
    if (Platform.isAndroid) {
      final status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        final result = await Permission.requestInstallPackages.request();
        if (!result.isGranted) {
          setState(() {
            _errorMessage =
                'Permission needed to install packages. Please enable "Install unknown apps" for this app in Settings.';
          });
          return;
        }
      }
    }

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _statusText = 'Connecting to download server…';
      _errorMessage = null;
    });

    try {
      UpdateService().startOtaUpdate(widget.info.downloadUrl).listen(
        (OtaEvent event) {
          if (!mounted) return;
          setState(() {
            switch (event.status) {
              case OtaStatus.DOWNLOADING:
                final parsed = int.tryParse(event.value ?? '0');
                if (parsed != null) _downloadProgress = parsed;
                _statusText = 'Downloading update… $_downloadProgress%';
                break;
              case OtaStatus.INSTALLING:
                _downloadProgress = 100;
                _statusText = 'Launching installer…';
                break;
              case OtaStatus.ALREADY_RUNNING_ERROR:
                _errorMessage = 'An update download is already in progress.';
                _isDownloading = false;
                break;
              case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                _errorMessage =
                    'Permission needed to install packages. Please allow "Install unknown apps" in Android settings.';
                _isDownloading = false;
                break;
              case OtaStatus.INTERNAL_ERROR:
                _errorMessage = 'Download failed: ${event.value ?? "Unknown error"}.';
                _isDownloading = false;
                break;
              default:
                break;
            }
          });
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Download error: $e';
              _isDownloading = false;
            });
          }
        },
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not start download: $e';
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E24).withValues(alpha: 0.96),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white12),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.themeColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.rocket_launch_rounded, color: widget.themeColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Update Available!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.info.tagName} • ${widget.info.formattedSize}',
                          style: TextStyle(
                            color: widget.themeColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                "What's New:",
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    widget.info.changelog,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.45),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_isDownloading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _statusText,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          '$_downloadProgress%',
                          style: TextStyle(color: widget.themeColor, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress / 100.0 : null,
                        minHeight: 8,
                        backgroundColor: Colors.white12,
                        valueColor: AlwaysStoppedAnimation<Color>(widget.themeColor),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text(
                        'Keep music_app open until installation starts',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Later', style: TextStyle(color: Colors.white60, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _startUpdate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.themeColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.download_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Update Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
