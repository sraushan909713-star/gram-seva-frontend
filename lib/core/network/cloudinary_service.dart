// lib/core/network/cloudinary_service.dart
// ──────────────────────────────────────────────────────────────────
// Cloudinary upload service for Gram Seva.
//
// Used for uploading evidence photos in Gram Awaaz and Vikas Prastav.
// Uses Cloudinary's unsigned upload API — no secret key needed.
// Returns the secure URL of the uploaded image.
//
// Cloud name:    dyrwmghe2
// Upload preset: ml_default (Unsigned)
// ──────────────────────────────────────────────────────────────────

import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CloudinaryService {

  // — Cloudinary config ─────────────────────────────────────────
  static const String _cloudName    = 'dyrwmghe2';
  static const String _uploadPreset = 'ml_default';
  static const String _uploadUrl    =
      'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  // ──────────────────────────────────────────────────────────────
  // Upload a single image file to Cloudinary.
  // Returns the secure HTTPS URL of the uploaded image.
  // Throws an Exception if upload fails.
  //
  // Cloudinary automatically:
  //   - Compresses the image for fast loading on slow connections
  //   - Serves optimized format (WebP on Android)
  //   - CDN delivery worldwide
  // ──────────────────────────────────────────────────────────────
  static Future<String> uploadImage(File imageFile) async {
    try {
      // ✅ Read image as bytes and convert to base64
      final bytes  = await imageFile.readAsBytes();
      final base64 = base64Encode(bytes);

      // ✅ Determine file extension for media type
      final ext       = imageFile.path.split('.').last.toLowerCase();
      final mediaType = ext == 'png' ? 'image/png' : 'image/jpeg';

      // ✅ POST to Cloudinary unsigned upload endpoint
      final response = await http.post(
        Uri.parse(_uploadUrl),
        body: {
          'file':          'data:$mediaType;base64,$base64',
          'upload_preset': _uploadPreset,
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception(
            'Upload timed out. Check your internet connection.'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // ✅ Return secure_url — always HTTPS, CDN-delivered
        return data['secure_url'] as String;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
          'Cloudinary upload failed: ${error['error']?['message'] ?? response.statusCode}');
      }
    } catch (e) {
      throw Exception('Photo upload failed: $e');
    }
  }
}
