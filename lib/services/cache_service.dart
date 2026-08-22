import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CacheService {
  static Future<Directory> _getCacheDir() async {
    final dir = await getApplicationCacheDirectory();
    final cacheDir = Directory('${dir.path}/piplock_cache');
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }
    return cacheDir;
  }

  static File _getFile(Directory dir, String key) {
    final safeKey = key.replaceAll(RegExp(r'[^\w]'), '_');
    return File('${dir.path}/$safeKey.json');
  }

  /// Scrive un valore nella cache con TTL in ore (default: 1 ora).
  static Future<void> write(String key, dynamic data, {int ttlHours = 1}) async {
    try {
      final dir = await _getCacheDir();
      final file = _getFile(dir, key);
      final expires =
          DateTime.now().add(Duration(hours: ttlHours)).millisecondsSinceEpoch;
      final payload = jsonEncode({'data': data, 'expires': expires});
      await file.writeAsString(payload);
    } catch (_) {
      // Ignora errori di scrittura cache
    }
  }

  /// Legge un valore dalla cache. Restituisce null se assente o scaduto.
  static Future<dynamic> read(String key) async {
    try {
      final dir = await _getCacheDir();
      final file = _getFile(dir, key);
      if (!file.existsSync()) return null;
      final content = await file.readAsString();
      final payload = jsonDecode(content) as Map<String, dynamic>;
      final expires = payload['expires'] as int;
      if (DateTime.now().millisecondsSinceEpoch > expires) {
        await file.delete();
        return null;
      }
      return payload['data'];
    } catch (_) {
      return null;
    }
  }

  /// Elimina una voce dalla cache.
  static Future<void> delete(String key) async {
    try {
      final dir = await _getCacheDir();
      final file = _getFile(dir, key);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  /// Svuota tutta la cache.
  static Future<void> clearAll() async {
    try {
      final dir = await _getCacheDir();
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
    } catch (_) {}
  }
}
