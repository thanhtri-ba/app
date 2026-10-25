import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

import '../scanner/receipt_text.dart';

/// On-device text recognition (ML Kit, Latin script: English + Vietnamese) used to confirm
/// which "document-like" photos really contain receipt / document text. Nothing is uploaded.
class OcrService {
  OcrService._();

  /// Returns the ids of [assets] whose text looks like a receipt or document.
  static Future<Set<String>> receiptIds(
    List<AssetEntity> assets, {
    void Function(int done, int total)? onProgress,
    bool Function()? cancelled,
  }) async {
    final keep = <String>{};
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final dir = await getTemporaryDirectory();
    final tmp = File('${dir.path}/ocr_tmp.jpg');
    try {
      for (var i = 0; i < assets.length; i++) {
        if (cancelled != null && cancelled()) break;
        try {
          final bytes =
              await assets[i].thumbnailDataWithSize(const ThumbnailSize(1280, 1280), quality: 85);
          if (bytes != null) {
            await tmp.writeAsBytes(bytes, flush: true);
            final res = await recognizer.processImage(InputImage.fromFilePath(tmp.path));
            if (looksLikeReceiptText(res.text)) keep.add(assets[i].id);
          }
        } catch (e) {
          debugPrint('ocr failed for one photo: $e');
        }
        onProgress?.call(i + 1, assets.length);
      }
    } finally {
      await recognizer.close();
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
    return keep;
  }
}
