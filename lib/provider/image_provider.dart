import 'package:flutter/material.dart';
import 'dart:typed_data';

class ImageProviderData extends ChangeNotifier {
  String? _imageFileName;
  Uint8List? _imageBytes;

  String? get imageFileName => _imageFileName;
  Uint8List? get imageBytes => _imageBytes;

  void setImageData(String fileName, Uint8List bytes) {
    _imageFileName = fileName;
    _imageBytes = bytes;
    notifyListeners(); // Notifikasi perubahan
  }

  void clearImageData() {
    _imageFileName = null;
    _imageBytes = null;
    notifyListeners();
  }
}
