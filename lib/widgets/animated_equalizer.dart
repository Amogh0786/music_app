import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lightweight, smooth animated equalizer with 3-4 jumping bars.
/// When [isPlaying] is true, bars animate dynamically.
/// When paused, bars rest at a low baseline.
class AnimatedEqualizer extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double size;
  final int barCount;

  const AnimatedEqualizer({
    super.key,
    required this.isPlaying,
    this.color = Colors.white,
    this.size = 20,
    this.barCount = 4,
  });

  @override
  State<AnimatedEqualizer> createState() => _AnimatedEqualizerState();
}

class _AnimatedEqualizerState extends State<AnimatedEqualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.isPlaying) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedEqualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying != oldWidget.isPlaying) {
      if (widget.isPlaying) {
        if (!_controller.isAnimating) {
          _controller.repeat(reverse: true);
        }
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = (widget.size / (widget.barCount * 1.8)).clamp(2.0, 3.5);
    final maxHeight = widget.size;

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(widget.barCount, (i) {
                double fraction;
                if (!widget.isPlaying) {
                  fraction = 0.25;
                } else {
                  // Stagger phase per bar using sine offsets
                  final phase = (i / widget.barCount) * math.pi;
                  fraction =
                      0.25 +
                      0.70 * ((math.sin(t * math.pi * 2 + phase) + 1) / 2);
                }

                return Container(
                  width: barWidth,
                  height: (fraction * maxHeight).clamp(barWidth, maxHeight),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(barWidth / 2),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
