import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:project/main.dart';
// ignore: unnecessary_import
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class StorageService {
  Future<String> uploadImage(XFile img) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${img.name}';

    if (kIsWeb) {
      final bytes = await img.readAsBytes();

      final compressed = await FlutterImageCompress.compressWithList(
        bytes,
        quality: 70,
      );

      await supabase.storage.from('items').uploadBinary(fileName, compressed);
    } else {
      final file = File(img.path);

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        '${file.parent.path}/temp_$fileName.jpg',
        quality: 70,
      );

      await supabase.storage
          .from('items')
          .upload(fileName, File(compressedFile!.path));
    }

    return supabase.storage.from('items').getPublicUrl(fileName);
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      final marker = '/object/public/items/';
      final idx = imageUrl.indexOf(marker);
      if (idx == -1) return;
      final filePath = imageUrl.substring(idx + marker.length);
      await supabase.storage.from('items').remove([filePath]);
    } catch (e) {
      debugPrint("Error deleting image: $e");
    }
  }
}
