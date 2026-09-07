import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Result of a Cloudinary upload.
class UploadResult {
  const UploadResult({required this.url, required this.publicId});
  final String url;
  final String publicId;
}

/// Direct, client-side image uploads to Cloudinary (no Firebase Storage).
/// Pattern adapted from `.claude/picture_storage_services.dart`.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  // Cloudinary account (from the provided reference credentials).
  static const String cloudName = 'dfpfvhzp9';
  static const String apiKey = '733743675153321';
  static const String apiSecret = 'GSY6thiaqMZXR9wR8fGPxZ42dDs';
  static const String uploadPreset = 'profile_pictures_upload';

  /// Upload an image [file] into [folder]. When [pngOnly] is true (team
  /// badges), non-PNG files are rejected so the doc's "JPG not supported"
  /// rule is enforced. Returns null on failure.
  Future<UploadResult?> uploadImage(
    File file, {
    String folder = 'profile_pictures',
    bool pngOnly = false,
  }) async {
    final media = _mediaType(file);
    if (media.type != 'image') return null;
    if (pngOnly && media.subtype != 'png') {
      throw const FormatException(
          'Team badges must be PNG (JPG is not supported).');
    }

    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/upload');
    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..fields['folder'] = folder
        ..fields['api_key'] = apiKey
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: media,
        ));
      final response = await request.send();
      if (response.statusCode == 200) {
        final data =
            jsonDecode(await response.stream.bytesToString()) as Map;
        return UploadResult(
          url: data['secure_url'] as String,
          publicId: data['public_id'] as String,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Delete an uploaded image by its Cloudinary [publicId] — used to remove a
  /// user's OLD profile picture when they upload a new one, so orphaned images
  /// don't pile up. Signed with the bundled api_secret (Cloudinary's destroy
  /// endpoint has no unsigned mode). Best-effort: returns true on success or if
  /// the asset was already gone, false otherwise (never throws).
  ///
  /// ⚠️ The api_secret is bundled in the client, consistent with this
  /// prototype's other client-side keys — fine for now, but destroy should move
  /// server-side before a public launch.
  Future<bool> deleteImage(String publicId) async {
    if (publicId.isEmpty) return false;
    final ts = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    // Cloudinary signature = SHA1 of the alphabetically-sorted params to sign
    // (here just public_id + timestamp) with the api_secret appended.
    final signature = sha1
        .convert(utf8.encode('public_id=$publicId&timestamp=$ts$apiSecret'))
        .toString();
    final url =
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
    try {
      final resp = await http.post(url, body: {
        'public_id': publicId,
        'timestamp': ts,
        'api_key': apiKey,
        'signature': signature,
      });
      if (resp.statusCode != 200) return false;
      final data = jsonDecode(resp.body) as Map;
      final result = data['result'];
      return result == 'ok' || result == 'not found';
    } catch (_) {
      return false;
    }
  }

  MediaType _mediaType(File file) {
    switch (file.path.split('.').last.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}
