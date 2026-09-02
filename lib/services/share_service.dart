import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareService {
  /// Cattura il widget associato a [key] (RepaintBoundary) come PNG e lo condivide.
  static Future<void> shareWidgetAsImage(
    GlobalKey key, {
    String text = 'My PipLock AI Stats 📊',
  }) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/piplock_stats.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: text,
      );
    } catch (_) {
      // Fallback al testo se la cattura immagine fallisce
      await shareText(text);
    }
  }

  /// Condivide testo semplice.
  static Future<void> shareText(String text) async {
    await Share.share(text);
  }

  /// Genera un testo statistiche da condividere (stringhe già localizzate dal caller).
  static String generateStatsText({
    required int ksEvents,
    required int cleanDays,
    required int totalTrades,
    required String title,
    required String ksLabel,
    required String cleanDaysLabel,
    required String tradesLabel,
    required String tagline,
  }) {
    return '''$title

$ksLabel
$cleanDaysLabel
$tradesLabel

$tagline
#PipLockAI #PropFirm #TradingDiscipline''';
  }
}
