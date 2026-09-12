import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/preferences_service.dart';
import '../services/music_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = PreferencesService();
  final _musicService = MusicService();

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
            ],
          ),
        );
      }
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
