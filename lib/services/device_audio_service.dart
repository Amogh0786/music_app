import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

/// Service managing device-stored audio indexing, metadata extraction,
/// and local file playback integration for DilSe Music.
class DeviceAudioService extends ChangeNotifier {
  static final DeviceAudioService _instance = DeviceAudioService._internal();
  factory DeviceAudioService() => _instance;
  DeviceAudioService._internal();

  List<Map<String, String>> _deviceSongs = [];
  bool _isScanning = false;
  String _scanStatusMessage = '';

  List<Map<String, String>> get deviceSongs => _deviceSongs;
  bool get isScanning => _isScanning;
  String get scanStatusMessage => _scanStatusMessage;

  static const Set<String> _supportedExtensions = {
    'mp3',
    'm4a',
    'flac',
    'wav',
    'aac',
    'opus',
    'ogg',
  };

  /// Generates an 11-character alphanumeric ID compatible with [VideoId] pattern.
  static String generateLocalId(String filePath) {
    final hashStr = (filePath.hashCode.toUnsigned(
      32,
    )).toRadixString(36).padLeft(7, '0').toLowerCase();
    final lenStr = (filePath.length.toUnsigned(
      16,
    )).toRadixString(36).padLeft(3, '0').toLowerCase();
    // 1 char 'L' + 7 chars hash + 3 chars length = 11 valid chars [a-zA-Z0-9]
    return 'L$hashStr$lenStr';
  }

  /// Loads cached device songs from local storage.
  Future<void> loadDeviceSongs() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/device_songs.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        final loaded = <Map<String, String>>[];
        for (final item in jsonList) {
          final map = Map<String, String>.from(item as Map);
          final path = map['localPath'];
          if (path != null && File(path).existsSync()) {
            loaded.add(map);
          }
        }
        _deviceSongs = loaded;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[DeviceAudioService] Error loading device songs: $e');
    }
  }

  /// Persists device songs catalog to disk.
  Future<void> saveDeviceSongs() async {
    if (kIsWeb) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/device_songs.json');
      await file.writeAsString(json.encode(_deviceSongs));
    } catch (e) {
      debugPrint('[DeviceAudioService] Error saving device songs: $e');
    }
  }

  /// Retrieves a device song by its synthetic 11-char ID.
  Map<String, String>? getSongById(String id) {
    for (final song in _deviceSongs) {
      if (song['id'] == id) return song;
    }
    return null;
  }

  /// Requests permissions and scans standard device music directories.
  Future<int> scanDeviceStorage() async {
    if (kIsWeb) return 0;
    if (_isScanning) return 0;

    _isScanning = true;
    _scanStatusMessage = 'Requesting storage permission...';
    notifyListeners();

    try {
      if (Platform.isAndroid) {
        var audioStatus = await Permission.audio.status;
        if (!audioStatus.isGranted) {
          audioStatus = await Permission.audio.request();
        }
        if (!audioStatus.isGranted) {
          var storageStatus = await Permission.storage.status;
          if (!storageStatus.isGranted) {
            storageStatus = await Permission.storage.request();
          }
          if (!storageStatus.isGranted) {
            _scanStatusMessage = 'Storage permission denied.';
            _isScanning = false;
            notifyListeners();
            return 0;
          }
        }
      }

      _scanStatusMessage = 'Scanning device storage for music files...';
      notifyListeners();

      final directoriesToScan = <Directory>[];

      if (Platform.isAndroid) {
        final musicDir = Directory('/storage/emulated/0/Music');
        final downloadDir = Directory('/storage/emulated/0/Download');
        final audiobooksDir = Directory('/storage/emulated/0/Audiobooks');
        final podcastsDir = Directory('/storage/emulated/0/Podcasts');

        if (musicDir.existsSync()) directoriesToScan.add(musicDir);
        if (downloadDir.existsSync()) directoriesToScan.add(downloadDir);
        if (audiobooksDir.existsSync()) directoriesToScan.add(audiobooksDir);
        if (podcastsDir.existsSync()) directoriesToScan.add(podcastsDir);

        try {
          final externalDirs = await getExternalStorageDirectories();
          if (externalDirs != null) {
            for (final d in externalDirs) {
              if (d.existsSync()) directoriesToScan.add(d);
            }
          }
        } catch (_) {}
      } else {
        try {
          final docDir = await getApplicationDocumentsDirectory();
          directoriesToScan.add(docDir);
        } catch (_) {}
      }

      final foundFiles = <File>[];
      for (final dir in directoriesToScan) {
        _scanStatusMessage = 'Scanning ${dir.path}...';
        notifyListeners();
        await _collectAudioFiles(dir, foundFiles, maxDepth: 4);
      }

      int newSongsCount = 0;
      final existingPaths = _deviceSongs.map((s) => s['localPath']).toSet();

      for (int i = 0; i < foundFiles.length; i++) {
        final file = foundFiles[i];
        if (existingPaths.contains(file.path)) continue;

        _scanStatusMessage =
            'Indexing track ${i + 1}/${foundFiles.length}: ${file.uri.pathSegments.last}';
        notifyListeners();

        final songEntry = await _parseAudioFile(file);
        if (songEntry != null) {
          _deviceSongs.add(songEntry);
          existingPaths.add(file.path);
          newSongsCount++;
        }
      }

      _deviceSongs.sort(
        (a, b) => (a['title'] ?? '').toLowerCase().compareTo(
          (b['title'] ?? '').toLowerCase(),
        ),
      );
      await saveDeviceSongs();

      _scanStatusMessage = newSongsCount > 0
          ? 'Found $newSongsCount new tracks!'
          : 'Scan complete. All tracks up to date.';
      return newSongsCount;
    } catch (e) {
      debugPrint('[DeviceAudioService] Storage scan exception: $e');
      _scanStatusMessage = 'Error during scan: $e';
      return 0;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Lets the user manually pick one or more audio files via system file picker.
  Future<int> pickAudioFiles() async {
    if (kIsWeb) return 0;
    try {
      final pickedFiles = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _supportedExtensions.toList(),
      );

      if (pickedFiles.isEmpty) return 0;

      int addedCount = 0;
      final existingPaths = _deviceSongs.map((s) => s['localPath']).toSet();

      for (final pickedFile in pickedFiles) {
        final path = pickedFile.path;
        if (path == null) continue;
        final file = File(path);
        if (!file.existsSync() || existingPaths.contains(path)) continue;

        final songEntry = await _parseAudioFile(file);
        if (songEntry != null) {
          _deviceSongs.add(songEntry);
          existingPaths.add(path);
          addedCount++;
        }
      }

      if (addedCount > 0) {
        _deviceSongs.sort(
          (a, b) => (a['title'] ?? '').toLowerCase().compareTo(
            (b['title'] ?? '').toLowerCase(),
          ),
        );
        await saveDeviceSongs();
        notifyListeners();
      }
      return addedCount;
    } catch (e) {
      debugPrint('[DeviceAudioService] pickAudioFiles error: $e');
      return 0;
    }
  }

  /// Lets the user pick an entire folder and recursively indexes all audio files.
  Future<int> pickDirectory() async {
    if (kIsWeb) return 0;
    try {
      final dirPath = await FilePicker.getDirectoryPath();
      if (dirPath == null) return 0;

      final directory = Directory(dirPath);
      if (!directory.existsSync()) return 0;

      _isScanning = true;
      _scanStatusMessage = 'Scanning selected folder...';
      notifyListeners();

      final foundFiles = <File>[];
      await _collectAudioFiles(directory, foundFiles, maxDepth: 4);

      int addedCount = 0;
      final existingPaths = _deviceSongs.map((s) => s['localPath']).toSet();

      for (final file in foundFiles) {
        if (existingPaths.contains(file.path)) continue;
        final songEntry = await _parseAudioFile(file);
        if (songEntry != null) {
          _deviceSongs.add(songEntry);
          existingPaths.add(file.path);
          addedCount++;
        }
      }

      if (addedCount > 0) {
        _deviceSongs.sort(
          (a, b) => (a['title'] ?? '').toLowerCase().compareTo(
            (b['title'] ?? '').toLowerCase(),
          ),
        );
        await saveDeviceSongs();
      }

      _scanStatusMessage = 'Imported $addedCount tracks from folder.';
      return addedCount;
    } catch (e) {
      debugPrint('[DeviceAudioService] pickDirectory error: $e');
      return 0;
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Removes a song from the indexed catalog.
  Future<void> removeSong(String id) async {
    _deviceSongs.removeWhere((s) => s['id'] == id);
    await saveDeviceSongs();
    notifyListeners();
  }

  /// Clears all indexed device songs.
  Future<void> clearAll() async {
    _deviceSongs.clear();
    await saveDeviceSongs();
    notifyListeners();
  }

  /// Recursively traverses directory collecting supported audio files.
  Future<void> _collectAudioFiles(
    Directory dir,
    List<File> files, {
    int currentDepth = 0,
    int maxDepth = 4,
  }) async {
    if (currentDepth > maxDepth) return;
    try {
      final entities = dir.listSync(followLinks: false);
      for (final entity in entities) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last.toLowerCase();
          if (name.startsWith('.')) continue; // skip hidden
          final extIndex = name.lastIndexOf('.');
          if (extIndex != -1) {
            final ext = name.substring(extIndex + 1);
            if (_supportedExtensions.contains(ext)) {
              // Ignore sound clips < 150KB
              try {
                if (entity.lengthSync() > 150 * 1024) {
                  files.add(entity);
                }
              } catch (_) {}
            }
          }
        } else if (entity is Directory) {
          final dirName = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments[entity.uri.pathSegments.length - 2]
                    .toLowerCase()
              : '';
          // Skip hidden directories or caches
          if (!dirName.startsWith('.') &&
              !dirName.contains('android') &&
              !dirName.contains('cache')) {
            await _collectAudioFiles(
              entity,
              files,
              currentDepth: currentDepth + 1,
              maxDepth: maxDepth,
            );
          }
        }
      }
    } catch (_) {}
  }

  /// Reads file headers and metadata to construct a standardized catalog entry.
  Future<Map<String, String>?> _parseAudioFile(File file) async {
    try {
      final path = file.path;
      final fileName = file.uri.pathSegments.last;
      final ext = fileName.contains('.')
          ? fileName.substring(fileName.lastIndexOf('.') + 1).toUpperCase()
          : 'AUDIO';

      final id = generateLocalId(path);
      final fileSize = file.lengthSync().toString();

      final parsed = await AudioTagParser.parseFile(file, id);

      return {
        'id': id,
        'title': parsed.title.isNotEmpty ? parsed.title : _cleanName(fileName),
        'author': parsed.artist.isNotEmpty
            ? parsed.artist
            : 'Device Audio Track',
        'album': parsed.album.isNotEmpty
            ? parsed.album
            : 'Local Device Storage',
        'duration': parsed.durationSec > 0
            ? parsed.durationSec.toString()
            : '0',
        'localPath': path,
        'fileSize': fileSize,
        'format': ext,
        'thumbnail': parsed.thumbnailUri ?? '',
        'dateAdded': DateTime.now().millisecondsSinceEpoch.toString(),
      };
    } catch (e) {
      debugPrint('[DeviceAudioService] Parse error on ${file.path}: $e');
      return null;
    }
  }

  static String _cleanName(String raw) {
    var name = raw;
    final dot = name.lastIndexOf('.');
    if (dot != -1) name = name.substring(0, dot);
    return name.replaceAll(RegExp(r'[_-]'), ' ').trim();
  }
}

/// Lightweight pure-Dart audio tag extractor supporting ID3v2, ID3v1, MP4 metadata,
/// and filename heuristics with zero external native dependency risks.
class AudioTagParser {
  final String title;
  final String artist;
  final String album;
  final int durationSec;
  final String? thumbnailUri;

  const AudioTagParser({
    required this.title,
    required this.artist,
    required this.album,
    this.durationSec = 0,
    this.thumbnailUri,
  });

  static Future<AudioTagParser> parseFile(File file, String songId) async {
    final fileName = file.uri.pathSegments.last;
    final dot = fileName.lastIndexOf('.');
    final ext = dot != -1 ? fileName.substring(dot + 1).toLowerCase() : '';

    String parsedTitle = '';
    String parsedArtist = '';
    String parsedAlbum = '';
    int durationSec = 0;
    String? thumbUri;

    try {
      final raf = await file.open(mode: FileMode.read);
      try {
        final length = await raf.length();

        if (ext == 'mp3') {
          // Check ID3v2 at the beginning
          final header = await raf.read(10);
          if (header.length >= 10 &&
              header[0] == 0x49 &&
              header[1] == 0x44 &&
              header[2] == 0x33) {
            // ID3v2 detected
            final version = header[3];
            final tagSize = _readSyncSafeInt(header, 6);
            if (tagSize > 0 && tagSize < 5 * 1024 * 1024) {
              final tagBytes = await raf.read(tagSize);
              final frames = _parseId3v2Frames(tagBytes, version);
              parsedTitle = frames['TIT2'] ?? '';
              parsedArtist = frames['TPE1'] ?? '';
              parsedAlbum = frames['TALB'] ?? '';
              if (frames.containsKey('TLEN')) {
                final ms = int.tryParse(frames['TLEN'] ?? '') ?? 0;
                durationSec = ms ~/ 1000;
              }

              // Save artwork if present
              final apicBytes = frames['__APIC_BYTES__'];
              if (apicBytes is Uint8List && apicBytes.isNotEmpty) {
                thumbUri = await _saveCachedArtwork(songId, apicBytes);
              }
            }
          }

          // Fallback to ID3v1 if still missing
          if (parsedTitle.isEmpty && length >= 128) {
            await raf.setPosition(length - 128);
            final v1Bytes = await raf.read(128);
            if (v1Bytes.length == 128 &&
                v1Bytes[0] == 0x54 &&
                v1Bytes[1] == 0x41 &&
                v1Bytes[2] == 0x47) {
              parsedTitle = _readAscii(v1Bytes, 3, 30).trim();
              parsedArtist = _readAscii(v1Bytes, 33, 30).trim();
              parsedAlbum = _readAscii(v1Bytes, 63, 30).trim();
            }
          }
        } else if (ext == 'm4a' || ext == 'aac' || ext == 'mp4') {
          // Parse basic MP4 atom metadata up to 512KB
          final sampleBytes = await raf.read(
            length < 512 * 1024 ? length : 512 * 1024,
          );
          final meta = _parseMp4Metadata(sampleBytes);
          parsedTitle = meta['title'] ?? '';
          parsedArtist = meta['artist'] ?? '';
          parsedAlbum = meta['album'] ?? '';
        }
      } finally {
        await raf.close();
      }
    } catch (_) {}

    // Filename heuristic fallback if tags not found
    if (parsedTitle.isEmpty || parsedArtist.isEmpty) {
      final baseName = dot != -1 ? fileName.substring(0, dot) : fileName;
      if (baseName.contains(' - ')) {
        final parts = baseName.split(' - ');
        if (parts.length >= 2) {
          if (parsedArtist.isEmpty) {
            parsedArtist = _cleanString(parts[0]);
          }
          if (parsedTitle.isEmpty) {
            parsedTitle = _cleanString(parts.sublist(1).join(' - '));
          }
        }
      } else {
        if (parsedTitle.isEmpty) parsedTitle = _cleanString(baseName);
        if (parsedArtist.isEmpty) parsedArtist = 'Device Audio';
      }
    }

    if (parsedAlbum.isEmpty) parsedAlbum = 'Local Storage';

    return AudioTagParser(
      title: parsedTitle,
      artist: parsedArtist,
      album: parsedAlbum,
      durationSec: durationSec,
      thumbnailUri: thumbUri,
    );
  }

  static Future<String?> _saveCachedArtwork(
    String songId,
    Uint8List bytes,
  ) async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final artFile = File('${cacheDir.path}/device_art_$songId.jpg');
      await artFile.writeAsBytes(bytes);
      return 'file://${artFile.path}';
    } catch (_) {
      return null;
    }
  }

  static int _readSyncSafeInt(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return 0;
    return ((bytes[offset] & 0x7F) << 21) |
        ((bytes[offset + 1] & 0x7F) << 14) |
        ((bytes[offset + 2] & 0x7F) << 7) |
        (bytes[offset + 3] & 0x7F);
  }

  static String _readAscii(Uint8List bytes, int offset, int length) {
    final end = (offset + length <= bytes.length)
        ? offset + length
        : bytes.length;
    final slice = bytes.sublist(offset, end);
    return String.fromCharCodes(slice.takeWhile((c) => c != 0));
  }

  static Map<String, dynamic> _parseId3v2Frames(Uint8List bytes, int version) {
    final result = <String, dynamic>{};
    int pos = 0;

    while (pos + 10 <= bytes.length) {
      final frameId = String.fromCharCodes(bytes.sublist(pos, pos + 4));
      if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(frameId)) break;

      final frameSize = version == 4
          ? _readSyncSafeInt(bytes, pos + 4)
          : ((bytes[pos + 4] << 24) |
                (bytes[pos + 5] << 16) |
                (bytes[pos + 6] << 8) |
                bytes[pos + 7]);

      pos += 10;
      if (frameSize <= 0 || pos + frameSize > bytes.length) break;

      final frameData = bytes.sublist(pos, pos + frameSize);
      pos += frameSize;

      if (frameId.startsWith('T') && frameId != 'TXXX') {
        // Text frame
        result[frameId] = _decodeTextFrame(frameData);
      } else if (frameId == 'APIC') {
        // Picture frame
        final picBytes = _extractApicImageBytes(frameData);
        if (picBytes != null) {
          result['__APIC_BYTES__'] = picBytes;
        }
      }
    }
    return result;
  }

  static String _decodeTextFrame(Uint8List data) {
    if (data.isEmpty) return '';
    final encoding = data[0];
    final payload = data.sublist(1);
    try {
      if (encoding == 0) {
        // ISO-8859-1 / Latin1
        return latin1.decode(payload).replaceAll('\u0000', '').trim();
      } else if (encoding == 3) {
        // UTF-8
        return utf8
            .decode(payload, allowMalformed: true)
            .replaceAll('\u0000', '')
            .trim();
      } else if (encoding == 1 || encoding == 2) {
        // UTF-16
        return _decodeUtf16(payload).replaceAll('\u0000', '').trim();
      }
    } catch (_) {}
    return latin1
        .decode(payload, allowInvalid: true)
        .replaceAll('\u0000', '')
        .trim();
  }

  static String _decodeUtf16(Uint8List bytes) {
    if (bytes.length < 2) return '';
    final codeUnits = <int>[];
    bool isLittleEndian = true;
    int start = 0;

    // Check BOM
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      isLittleEndian = true;
      start = 2;
    } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      isLittleEndian = false;
      start = 2;
    }

    for (int i = start; i + 1 < bytes.length; i += 2) {
      final unit = isLittleEndian
          ? (bytes[i] | (bytes[i + 1] << 8))
          : ((bytes[i] << 8) | bytes[i + 1]);
      if (unit == 0) break;
      codeUnits.add(unit);
    }
    return String.fromCharCodes(codeUnits);
  }

  static Uint8List? _extractApicImageBytes(Uint8List data) {
    if (data.length < 10) return null;
    int pos = 1; // skip encoding byte
    // Find mime type null terminator
    while (pos < data.length && data[pos] != 0) {
      pos++;
    }
    pos++; // skip null
    if (pos >= data.length) return null;
    pos++; // skip picture type
    // Find description null terminator
    while (pos < data.length && data[pos] != 0) {
      pos++;
    }
    pos++; // skip null
    if (pos < data.length) {
      return data.sublist(pos);
    }
    return null;
  }

  static Map<String, String> _parseMp4Metadata(Uint8List bytes) {
    final result = <String, String>{};
    final asString = latin1.decode(bytes, allowInvalid: true);

    // Look for ©nam, ©ART, ©alb markers
    void extractField(String marker, String key) {
      final index = asString.indexOf(marker);
      if (index != -1 && index + 24 < bytes.length) {
        // Read data atom payload after marker
        final dataStart = index + 8; // skip atom header
        if (dataStart + 16 < bytes.length) {
          final payload = bytes.sublist(
            dataStart + 8,
            (dataStart + 80 <= bytes.length) ? dataStart + 80 : bytes.length,
          );
          final text = utf8.decode(payload, allowMalformed: true);
          final cleaned = text.replaceAll(RegExp(r'[\x00-\x1F]'), '').trim();
          if (cleaned.isNotEmpty) result[key] = cleaned;
        }
      }
    }

    extractField('©nam', 'title');
    extractField('©ART', 'artist');
    extractField('©alb', 'album');

    return result;
  }

  static String _cleanString(String s) {
    return s.replaceAll(RegExp(r'^\d+[\s._-]+'), '').trim();
  }
}
