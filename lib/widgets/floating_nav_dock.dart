import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Floating Frosted Glass Bottom Navigation Dock
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
    final primaryColor = Theme.of(context).primaryColor;

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

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xEB161622),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
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
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primaryColor.withValues(alpha: 0.18)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isSelected
                                ? primaryColor.withValues(alpha: 0.35)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isSelected ? tab.activeIcon : tab.icon,
                              color: isSelected ? primaryColor : Colors.white60,
                              size: 22,
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  tab.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
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
