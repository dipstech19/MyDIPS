import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';

class StorageService {
  static FirebaseStorage? _storage;
  
  static FirebaseStorage get storage {
    _storage ??= FirebaseStorage.instance;
    return _storage!;
  }
  
  static bool get isAvailable {
    final available = Firebase.apps.isNotEmpty;
    debugPrint('StorageService: Firebase available = $available');
    return available;
  }
  
  /// Upload employee photo
  static Future<String?> uploadEmployeePhoto({
    required String employeeId,
    required Uint8List bytes,
    required String extension,
  }) async {
    debugPrint('StorageService: Uploading photo for employee $employeeId (${bytes.length} bytes)');
    
    if (!isAvailable) {
      debugPrint('StorageService: Firebase not available, skipping upload');
      return null;
    }
    
    try {
      final path = 'employees/$employeeId/photo.$extension';
      debugPrint('StorageService: Uploading to path: $path');
      
      final ref = storage.ref().child(path);
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$extension'),
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('StorageService: Photo uploaded successfully, URL: $downloadUrl');
      return downloadUrl;
    } catch (e, stack) {
      debugPrint('StorageService: Error uploading photo: $e');
      debugPrint('StorageService: Stack trace: $stack');
      return null;
    }
  }
  
  /// Upload employee document
  static Future<String?> uploadEmployeeDocument({
    required String employeeId,
    required String documentId,
    required Uint8List bytes,
    required String fileName,
    required String extension,
  }) async {
    debugPrint('StorageService: Uploading document $fileName for employee $employeeId');
    
    if (!isAvailable) {
      debugPrint('StorageService: Firebase not available, skipping document upload');
      return null;
    }
    
    try {
      String contentType = 'application/octet-stream';
      if (extension == 'pdf') {
        contentType = 'application/pdf';
      } else if (['jpg', 'jpeg', 'png'].contains(extension.toLowerCase())) {
        contentType = 'image/$extension';
      } else if (['doc', 'docx'].contains(extension.toLowerCase())) {
        contentType = 'application/msword';
      }
      
      final path = 'employees/$employeeId/documents/$documentId.$extension';
      debugPrint('StorageService: Uploading document to path: $path');
      
      final ref = storage.ref().child(path);
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      debugPrint('StorageService: Document uploaded successfully, URL: $downloadUrl');
      return downloadUrl;
    } catch (e, stack) {
      debugPrint('StorageService: Error uploading document: $e');
      debugPrint('StorageService: Stack trace: $stack');
      return null;
    }
  }
  
  /// Delete file from storage
  static Future<void> deleteFile(String path) async {
    if (!isAvailable) return;
    
    try {
      await storage.ref(path).delete();
      debugPrint('StorageService: Deleted file at $path');
    } catch (e) {
      debugPrint('StorageService: Error deleting file: $e');
    }
  }
  
  /// Delete employee folder
  static Future<void> deleteEmployeeFolder(String employeeId) async {
    if (!isAvailable) return;
    
    try {
      final ref = storage.ref().child('employees/$employeeId');
      final result = await ref.listAll();
      for (final item in result.items) {
        await item.delete();
      }
      for (final prefix in result.prefixes) {
        final subResult = await prefix.listAll();
        for (final item in subResult.items) {
          await item.delete();
        }
      }
      debugPrint('StorageService: Deleted employee folder for $employeeId');
    } catch (e) {
      debugPrint('StorageService: Error deleting employee folder: $e');
    }
  }
}
