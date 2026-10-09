import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_theme_tokens.dart';

/// Apple-Style Glassmorphic Floating Bottom Navigation Dock with Sliding Indicator
class FloatingNavDock extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  const FloatingNavDock({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _NavTabItem(
        icon: Icons.play_circle_outline_rounded,
        activeIcon: Icons.play_circle_fill_rounded,
        label: 'Listen Now',
      ),
      _NavTabItem(
        icon: Icons.search_rounded,
        activeIcon: Icons.saved_search_rounded,
        label: 'Search',
      ),
      _NavTabItem(
        icon: Icons.library_music_outlined,
        activeIcon: Icons.library_music_rounded,
        label: 'Library',
      ),
    ];

    return RepaintBoundary(
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            top: 0,
            bottom: 8,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              decoration: BoxDecoration(
                color: AppThemeTokens.floatingDockSurface,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: AppThemeTokens.floatingDockBorder,
                  width: 0.75,
                ),
                boxShadow: AppThemeTokens.dockShadow,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final tabWidth = constraints.maxWidth / tabs.length;
                  return Stack(
                    children: [
                      // Smooth sliding translucent indicator pill
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        left: selectedIndex * tabWidth,
                        top: 0,
                        bottom: 0,
                        width: tabWidth,
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                      // Interactive tabs
                      Row(
                        children: List.generate(tabs.length, (index) {
                          final tab = tabs[index];
                          final isSelected = selectedIndex == index;

                          return Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                if (!isSelected) {
                                  HapticFeedback.lightImpact();
                                  onTabSelected(index);
                                }
                              },
                              child: Container(
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    AnimatedScale(
                                      scale: isSelected ? 1.08 : 1.0,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Icon(
                                        isSelected ? tab.activeIcon : tab.icon,
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white60,
                                        size: 22,
                                      ),
                                    ),
                                    AnimatedCrossFade(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      crossFadeState: isSelected
                                          ? CrossFadeState.showFirst
                                          : CrossFadeState.showSecond,
                                      firstChild: Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Text(
                                          tab.label,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                      secondChild: const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  _NavTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
