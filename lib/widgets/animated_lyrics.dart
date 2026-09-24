import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LyricLine {
  final Duration time;
  final String text;
  LyricLine(this.time, this.text);
}

class AnimatedLyrics extends StatefulWidget {
  final String rawLyrics;
  final Stream<Duration> positionStream;
  final void Function(Duration)? onSeek;

  const AnimatedLyrics({
    super.key,
    required this.rawLyrics,
    required this.positionStream,
    this.onSeek,
  });

  @override
  State<AnimatedLyrics> createState() => _AnimatedLyricsState();
}

class _AnimatedLyricsState extends State<AnimatedLyrics> {
  final ScrollController _scrollController = ScrollController();
  List<LyricLine> _lyrics = [];
  bool _isSynced = false;
  int _currentIndex = -1;

  // Auto-scroll control
  bool _isUserScrolling = false;
  Timer? _userScrollResumeTimer;

  @override
  void initState() {
    super.initState();
    _parseLyrics();
  }

  @override
  void didUpdateWidget(covariant AnimatedLyrics oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawLyrics != widget.rawLyrics) {
      setState(() {
        _currentIndex = -1;
        _parseLyrics();
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
    }
  }

  @override
  void dispose() {
    _userScrollResumeTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _parseLyrics() {
    _lyrics.clear();
    _isSynced = false;
    _currentIndex = -1;

    if (widget.rawLyrics.isEmpty) return;

    final lines = widget.rawLyrics.split('\n');
    // Flexible regex matching: [01:23.45], [1:23.456], [01:23:45], [01:23]
    final tagRegex = RegExp(r'\[(\d{1,2}):(\d{2})(?:[.:](\d{1,3}))?\]');

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      // Ignore LRC header metadata tags: [ar:...], [al:...], [ti:...], [length:...]
      if (RegExp(r'^\[[a-zA-Z]+:.*\]$').hasMatch(line)) continue;

      final matches = tagRegex.allMatches(line);
      if (matches.isNotEmpty) {
        _isSynced = true;
        // Text is everything remaining after stripping all timestamp brackets
        final text = line.replaceAll(tagRegex, '').trim();
        if (text.isEmpty) continue;

        for (final m in matches) {
          final minutes = int.parse(m.group(1)!);
          final seconds = int.parse(m.group(2)!);
          int milliseconds = 0;
          final msGroup = m.group(3);
          if (msGroup != null) {
            if (msGroup.length == 1) {
              milliseconds = int.parse(msGroup) * 100;
            } else if (msGroup.length == 2) {
              milliseconds = int.parse(msGroup) * 10;
            } else {
              milliseconds = int.parse(msGroup.substring(0, 3));
            }
          }

          final duration = Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          );
          _lyrics.add(LyricLine(duration, text));
        }
      }
    }

    if (_isSynced && _lyrics.isNotEmpty) {
      // Sort strictly by timestamp in ascending order
      _lyrics.sort((a, b) => a.time.compareTo(b.time));
    } else {
      _isSynced = false;
      final cleanRegex = RegExp(r'\[\d+:\d+(?:[.:]\d+)?\]');
      final cleaned = lines
          .map((l) => l.replaceAll(cleanRegex, '').trim())
          .where((l) => l.isNotEmpty && !RegExp(r'^\[[a-zA-Z]+:.*\]$').hasMatch(l))
          .toList();
      _lyrics = cleaned.map((l) => LyricLine(Duration.zero, l)).toList();
    }
  }

  void _scrollToActiveLine(int index) {
    if (_isUserScrolling || !_scrollController.hasClients || index < 0 || index >= _lyrics.length) return;

    // Approximate height per line with padding
    final screenH = MediaQuery.of(context).size.height;
    // Target position: center active lyric vertically
    final targetOffset = (index * 54.0) - (screenH * 0.18);
    final clampedOffset = targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_lyrics.isEmpty) {
      return const Center(
        child: Text(
          'No lyrics available.',
          style: TextStyle(color: Colors.white54, fontSize: 18),
        ),
      );
    }

    if (!_isSynced) {
      // Plain text fallback view
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8.0),
          child: Text(
            _lyrics.map((l) => l.text).join('\n\n'),
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              height: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<Duration>(
      stream: widget.positionStream,
      builder: (context, snapshot) {
        final position = snapshot.data ?? Duration.zero;

        // Binary search or linear scan for current active line
        int activeIndex = -1;
        for (int i = 0; i < _lyrics.length; i++) {
          if (position >= _lyrics[i].time) {
            activeIndex = i;
          } else {
            break;
          }
        }

        if (activeIndex != _currentIndex) {
          _currentIndex = activeIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToActiveLine(_currentIndex);
          });
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is UserScrollNotification) {
              _isUserScrolling = true;
              _userScrollResumeTimer?.cancel();
              _userScrollResumeTimer = Timer(const Duration(seconds: 3), () {
                if (mounted) {
                  _isUserScrolling = false;
                  _scrollToActiveLine(_currentIndex);
                }
              });
            }
            return false;
          },
          child: ListView.builder(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            itemCount: _lyrics.length,
            padding: EdgeInsets.symmetric(vertical: MediaQuery.of(context).size.height * 0.22),
            itemBuilder: (context, index) {
              final isCurrent = index == _currentIndex;
              final isPassed = index < _currentIndex;
              final item = _lyrics[index];

              final themeColor = Theme.of(context).primaryColor;

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.lightImpact();
                  widget.onSeek?.call(item.time);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      color: isCurrent
                          ? themeColor
                          : (isPassed ? Colors.white.withValues(alpha: 0.70) : Colors.white.withValues(alpha: 0.28)),
                      fontSize: isCurrent ? 24 : 19.5,
                      fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                      height: 1.45,
                      shadows: isCurrent
                          ? [
                              Shadow(
                                color: themeColor.withValues(alpha: 0.5),
                                blurRadius: 16,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(item.text),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
