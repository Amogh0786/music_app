import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppUpdateInfo {
  final String tagName;
  final String releaseName;
  final String changelog;
  final String downloadUrl;
  final int apkSizeBytes;
  final String currentVersion;
  final String currentBuildNumber;
  final bool hasUpdate;

  AppUpdateInfo({
    required this.tagName,
    required this.releaseName,
    required this.changelog,
    required this.downloadUrl,
    required this.apkSizeBytes,
    required this.currentVersion,
    required this.currentBuildNumber,
    required this.hasUpdate,
  });

  String get formattedSize {
    if (apkSizeBytes <= 0) return 'Unknown size';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  static const String _githubRepoOwner = 'charanteja-k';
  static const String _githubRepoName = 'music_app';

  /// Queries GitHub Releases for the latest release and checks if it is newer
  /// than the currently installed app version.
  Future<AppUpdateInfo?> checkForUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final currentBuildNumber = packageInfo.buildNumber;

      final url = Uri.parse('https://api.github.com/repos/$_githubRepoOwner/$_githubRepoName/releases/latest');
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'MusicApp-Updater',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('[UpdateService] GitHub releases returned status: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').trim();
      final releaseName = (data['name'] as String? ?? tagName).trim();
      final changelog = (data['body'] as String? ?? 'Bug fixes and performance improvements.').trim();

      // Find APK asset in release
      final assets = (data['assets'] as List<dynamic>? ?? []);
      String? apkDownloadUrl;
      int apkSize = 0;

      for (final asset in assets) {
        final name = (asset['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkDownloadUrl = asset['browser_download_url'] as String?;
          apkSize = (asset['size'] as num? ?? 0).toInt();
          break;
        }
      }

      if (apkDownloadUrl == null || apkDownloadUrl.isEmpty) {
        debugPrint('[UpdateService] No APK asset found in latest GitHub release ($tagName)');
        return null;
      }

      final hasUpdate = _isRemoteNewer(
        remoteTag: tagName,
        currentVersion: currentVersion,
        currentBuild: currentBuildNumber,
      );

      return AppUpdateInfo(
        tagName: tagName,
        releaseName: releaseName,
        changelog: changelog,
        downloadUrl: apkDownloadUrl,
        apkSizeBytes: apkSize,
        currentVersion: currentVersion,
        currentBuildNumber: currentBuildNumber,
        hasUpdate: hasUpdate,
      );
    } catch (e) {
      debugPrint('[UpdateService] Error checking for updates: $e');
      return null;
    }
  }

  /// Compares remote tag (e.g. "v1.0.3") with local version (e.g. "1.0.2")
  static bool _isRemoteNewer({
    required String remoteTag,
    required String currentVersion,
    required String currentBuild,
  }) {
    final cleanRemote = remoteTag.replaceAll(RegExp(r'^[vV]'), '').trim();
    final cleanCurrent = currentVersion.replaceAll(RegExp(r'^[vV]'), '').trim();

    // Extract version part and build number
    final remoteParts = cleanRemote.split('+');
    final remoteSemver = remoteParts[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final remoteBuild = remoteParts.length > 1 ? (int.tryParse(remoteParts[1]) ?? 0) : 0;

    final currentSemver = cleanCurrent.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final localBuild = int.tryParse(currentBuild) ?? 0;

    // Pad to 3 components (major.minor.patch)
    while (remoteSemver.length < 3) {
      remoteSemver.add(0);
    }
    while (currentSemver.length < 3) {
      currentSemver.add(0);
    }

    for (int i = 0; i < 3; i++) {
      if (remoteSemver[i] > currentSemver[i]) return true;
      if (remoteSemver[i] < currentSemver[i]) return false;
    }

    // If semver is identical, compare build number if remote specified one
    if (remoteBuild > 0 && localBuild > 0) {
      return remoteBuild > localBuild;
    }

    return false;
  }

  /// Starts downloading the APK and triggers Android's package installer.
  Stream<OtaEvent> startOtaUpdate(String downloadUrl) {
    if (!Platform.isAndroid) {
      throw UnsupportedError('OTA updates via APK are only supported on Android.');
    }
    return OtaUpdate().execute(
      downloadUrl,
      destinationFilename: 'music_app_latest.apk',
    );
  }
}
