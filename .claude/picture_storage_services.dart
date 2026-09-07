import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http_parser/http_parser.dart';

class StorageServices {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cloudinary configuration
  final String cloudName = "dfpfvhzp9";
  final String apiKey = "733743675153321";
  final String apiSecret = "GSY6thiaqMZXR9wR8fGPxZ42dDs";

  // Upload product image or video to Cloudinary (product folder)
  Future<Map<String, dynamic>?> uploadProductMedia(File file) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/upload');

    try {
      // Validate that the file is an image before uploading
      final mediaType = _getMediaType(file);
      if (mediaType.type != 'image') {
        throw Exception('Only image files are allowed for product uploads.');
      }

      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'profile_pictures_upload'
        ..fields['folder'] = 'products'
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString()
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: mediaType,
        ));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return jsonDecode(responseData);
      } else {
        throw Exception('Failed to upload product media: ${response.statusCode}');
      }
    } catch (e) {
      print('Upload product media failed: $e');
      return null;
    }
  }


  // Upload a profile picture to Cloudinary
  Future<void> updateProfilePicture(File file) async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // Upload the file to Cloudinary
        final uploadResponse = await _uploadToCloudinary(file);
        if (uploadResponse != null) {
          final imageUrl = uploadResponse['secure_url'];
          final publicId = uploadResponse['public_id'];

          // Update Firestore and Firebase Auth with the new photo URL and public ID
          await _firestore.collection('Users').doc(user.uid).update({
            'photoURL': imageUrl,
            'publicId': publicId,
          });
          await user.updatePhotoURL(imageUrl);
        }
      } catch (e) {
        print('Failed to upload profile picture: $e');
      }
    }
  }

  // Delete a profile picture using the public ID
  Future<void> deleteProfilePicture() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        // Retrieve public ID from Firestore
        final userDoc = await _firestore.collection('Users').doc(user.uid).get();
        final publicId = userDoc.data()?['publicId'] ?? "";

        if (publicId.isNotEmpty) {
          final response = await _deleteFromCloudinary(publicId);
          if (response['result'] == 'ok') {
            // Update Firestore and Firebase Auth
            await _firestore.collection('Users').doc(user.uid).update({
              'photoURL': "",
              'publicId': "",
            });
            await user.updatePhotoURL("");
          }
        }
      } catch (e) {
        print('Failed to delete profile picture: $e');
      }
    }
  }

  // Helper method: Upload file to Cloudinary
  Future<Map<String, dynamic>?> _uploadToCloudinary(File file) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');

    try {
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'profile_pictures_upload'
        ..fields['folder'] = 'profile_pictures'
        ..fields['api_key'] = apiKey
        ..fields['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString()
        ..files.add(await http.MultipartFile.fromPath(
          'file',
          file.path,
          contentType: _getMediaType(file),
        ));

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        return jsonDecode(responseData);
      } else {
        throw Exception('Failed to upload image: ${response.statusCode}');
      }
    } catch (e) {
      print('Upload to Cloudinary failed: $e');
      return null;
    }
  }

  // Helper method: Delete file from Cloudinary
  Future<Map<String, dynamic>> _deleteFromCloudinary(String publicId) async {
    final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');

    try {
      final response = await http.post(
        url,
        body: {
          'public_id': publicId,
          'api_key': apiKey,
          'api_secret': apiSecret,
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to delete image: ${response.statusCode}');
      }
    } catch (e) {
      print('Delete from Cloudinary failed: $e');
      rethrow;
    }
  }

  // Helper method to determine the MIME type
  MediaType _getMediaType(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      default:
        return MediaType('application', 'octet-stream');
    }
  }
}
