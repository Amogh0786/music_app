import 'dart:async';
import 'dart:io' show InternetAddress, SocketException, Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../constants/app_theme_tokens.dart';

/// Non-intrusive persistent offline notification banner directing user to Downloads.
class OfflineIndicatorBanner extends StatefulWidget {
  final VoidCallback onGoToDownloads;

  const OfflineIndicatorBanner({super.key, required this.onGoToDownloads});

  @override
  State<OfflineIndicatorBanner> createState() => _OfflineIndicatorBannerState();
}

class _OfflineIndicatorBannerState extends State<OfflineIndicatorBanner> {
  bool _isOffline = false;
  bool _isDismissed = false;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    if (!kIsWeb && !Platform.environment.containsKey('FLUTTER_TEST')) {
      _checkTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        _checkConnectivity();
      });
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) {
      return;
    }

    try {
      final result = await InternetAddress.lookup(
        '1.1.1.1',
      ).timeout(const Duration(seconds: 2));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted && _isOffline == online) {
        setState(() {
          _isOffline = !online;
          if (online) _isDismissed = false;
        });
      }
    } on SocketException catch (_) {
      if (mounted && !_isOffline) {
        setState(() => _isOffline = true);
      }
    } on TimeoutException catch (_) {
      if (mounted && !_isOffline) {
        setState(() => _isOffline = true);
      }
    } catch (_) {
      // Keep previous state on transient lookup errors
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline || _isDismissed) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1711).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFFB74D).withValues(alpha: 0.35),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB74D).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFFFB74D),
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'You are offline',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      'Play downloaded songs without internet',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onGoToDownloads,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppThemeTokens.brandRuby,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Downloads',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  setState(() => _isDismissed = true);
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white10,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: Colors.white60,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
