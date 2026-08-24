import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class MediaService {
  final FirebaseStorage? _customStorage;
  final ImagePicker _picker;

  MediaService({
    FirebaseStorage? storage,
    ImagePicker? picker,
  })  : _customStorage = storage,
        _picker = picker ?? ImagePicker();

  FirebaseStorage get _storage => _customStorage ?? FirebaseStorage.instance;

  /// Picks an image from camera or gallery and applies client-side JPEG compression
  /// (max dimensions: 1024x1024, JPEG quality: 50) to minimize storage and bandwidth usage.
  Future<File?> pickAndCompressImage({
    required ImageSource source,
  }) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 50,
      );

      if (pickedFile == null) {
        return null;
      }

      final file = File(pickedFile.path);
      if (await file.exists()) {
        final length = await file.length();
        debugPrint('Image picked & compressed successfully. Size: ${(length / 1024).toStringAsFixed(1)} KB');
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Error picking image: $e');
      return null;
    }
  }

  /// Uploads a compressed JPEG image to Firebase Storage under `chat_media/$chatId/$filename`.
  /// Returns the public HTTPS download URL on success.
  Future<String?> uploadChatImage({
    required String chatId,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final String filename = '${DateTime.now().millisecondsSinceEpoch}_${UniqueKey().hashCode.abs()}.jpg';
      final Reference storageRef = _storage.ref().child('chat_media').child(chatId).child(filename);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'chatId': chatId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final UploadTask uploadTask = storageRef.putFile(file, metadata);

      if (onProgress != null) {
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          if (snapshot.totalBytes > 0) {
            final double progress = snapshot.bytesTransferred / snapshot.totalBytes;
            onProgress(progress.clamp(0.0, 1.0));
          }
        });
      }

      final TaskSnapshot completedSnapshot = await uploadTask;
      final String downloadUrl = await completedSnapshot.ref.getDownloadURL();
      debugPrint('Chat image uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading chat image to Storage: $e');
      return null;
    }
  }
}
