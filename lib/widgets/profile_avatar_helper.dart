import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Safely resolves a cross-platform ImageProvider for user profile avatars.
/// Supports both file paths on mobile/desktop and base64 data URIs on Web/PWA.
ImageProvider? getProfileImageProvider(String? imagePath) {
  if (imagePath == null || imagePath.isEmpty) return null;
  if (imagePath.startsWith('data:image/') || imagePath.startsWith('base64:')) {
    final commaIndex = imagePath.indexOf(',');
    final base64Data = commaIndex != -1
        ? imagePath.substring(commaIndex + 1)
        : imagePath;
    try {
      final bytes = base64Decode(base64Data);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }
  if (!kIsWeb) {
    try {
      final file = File(imagePath);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Checks whether a valid custom profile image is available on this platform.
bool hasProfileImage(String? imagePath) {
  if (imagePath == null || imagePath.isEmpty) return false;
  if (imagePath.startsWith('data:image/') || imagePath.startsWith('base64:')) {
    return true;
  }
  if (!kIsWeb) {
    try {
      return File(imagePath).existsSync();
    } catch (_) {
      return false;
    }
  }
  return false;
}
