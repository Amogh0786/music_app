import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = PreferencesService();

  final List<Color> _availableColors = [
    const Color(0xFFFA2D48), // Apple Red
    const Color(0xFF1DB954), // Spotify Green
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF2196F3), // Blue
    const Color(0xFFFF9800), // Orange
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _prefs,
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
                activeColor: _prefs.themeColor,
                value: _prefs.crossfadeEnabled,
                onChanged: (val) {
                  _prefs.setCrossfade(val);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Crossfade set to ${val ? "On" : "Off"}'), backgroundColor: _prefs.themeColor),
                  );
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
                    final isSelected = _prefs.themeColor.value == color.value;
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
