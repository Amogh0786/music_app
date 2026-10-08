import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../layouts/desktop_layout_state.dart';
import '../../screens/dilse_capsule_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/profile_screen.dart';

/// Spotify-grade 64px Desktop Top Global Navigation Bar (#global-nav-bar).
///
/// Features:
/// 1. Leading: DilSe Logo vector + branding with instant Home navigation.
/// 2. Center: Centered pill search bar with `Ctrl+Shift+L` keyboard focus accelerator.
/// 3. Trailing: DilSe Capsule listening journey trigger, Profile avatar, and Settings.
class DesktopTopNavBar extends StatefulWidget {
  const DesktopTopNavBar({super.key});

  @override
  State<DesktopTopNavBar> createState() => _DesktopTopNavBarState();
}

class _DesktopTopNavBarState extends State<DesktopTopNavBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _searchController.text = DesktopLayoutState.globalSearchQuery.value;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _focusSearch() {
    _searchFocusNode.requestFocus();
    if (DesktopLayoutState.activeNavTab.value != DesktopNavTab.search) {
      DesktopLayoutState.setNavTab(DesktopNavTab.search);
    }
  }

  void _onSearchChanged(String query) {
    DesktopLayoutState.globalSearchQuery.value = query.trim();
    if (query.trim().isNotEmpty &&
        DesktopLayoutState.activeNavTab.value != DesktopNavTab.search) {
      DesktopLayoutState.setNavTab(DesktopNavTab.search);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.keyL,
          control: true,
          shift: true,
        ): _focusSearch,
        const SingleActivator(LogicalKeyboardKey.keyL, meta: true, shift: true):
            _focusSearch,
      },
      child: Container(
        height: 64.0,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        decoration: BoxDecoration(
          color: const Color(0xFF0B0B0F),
          border: Border(
            bottom: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
        ),
        child: Row(
          children: [
            // 1. LEADING: BRAND LOGO + HOME NAV
            InkWell(
              borderRadius: BorderRadius.circular(8.0),
              onTap: () {
                _searchController.clear();
                DesktopLayoutState.globalSearchQuery.value = '';
                DesktopLayoutState.setNavTab(DesktopNavTab.home);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 4.0,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36.0,
                      height: 36.0,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFA2D48), Color(0xFFFF6B81)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    const Text(
                      'DilSe Music',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // 2. CENTER: PILL SEARCH CONTAINER (480px)
            Container(
              height: 44.0,
              width: 480.0,
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              decoration: BoxDecoration(
                color: const Color(0xFF16161E),
                borderRadius: BorderRadius.circular(22.0),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: Icon(
                      Icons.search_rounded,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 20.0,
                    ),
                    onPressed: _focusSearch,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'What do you want to play?',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13.5,
                        ),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (query) {
                        _onSearchChanged(query);
                        DesktopLayoutState.setNavTab(DesktopNavTab.search);
                      },
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white.withValues(alpha: 0.5),
                          size: 16.0,
                        ),
                      ),
                    ),
                  // Accelerator Badge (Ctrl+Shift+L)
                  InkWell(
                    onTap: _focusSearch,
                    borderRadius: BorderRadius.circular(5.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7.0,
                        vertical: 3.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(5.0),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Text(
                        'Ctrl+Shift+L',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // 3. TRAILING: CAPSULE TRIGGER, SETTINGS, & PROFILE AVATAR
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // DilSe Capsule Button
                IconButton(
                  tooltip: 'DilSe Capsule',
                  icon: Container(
                    padding: const EdgeInsets.all(5.0),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFA2D48), Color(0xFFFF6B81)],
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 16.0,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const DilSeCapsuleScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(width: 4.0),

                // Settings Gear Button
                IconButton(
                  tooltip: 'Settings',
                  icon: Icon(
                    Icons.settings_outlined,
                    color: Colors.white.withValues(alpha: 0.75),
                    size: 20.0,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    );
                  },
                ),

                const SizedBox(width: 4.0),

                // Right Panel Toggle
                IconButton(
                  tooltip: 'Toggle Right Panel',
                  icon: Icon(
                    Icons.view_sidebar_rounded,
                    color: Colors.white.withValues(alpha: 0.75),
                    size: 20.0,
                  ),
                  onPressed: () => DesktopLayoutState.toggleRightPanel(),
                ),

                const SizedBox(width: 8.0),

                // User Profile Avatar
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  child: Container(
                    width: 34.0,
                    height: 34.0,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E2C),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.0,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
