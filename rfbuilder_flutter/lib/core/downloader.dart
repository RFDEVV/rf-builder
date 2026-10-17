import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class Downloader {
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 10),
  ));

  static String _safeName(String name) =>
      name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  /// Simpan ke folder app (tanpa izin storage), mengembalikan path file.
  static Future<String> download(String url,
      {String? suggestedName, void Function(double)? onProgress}) async {
    final base = (await getExternalStorageDirectory()) ??
        await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'RFBuilder'));
    if (!await dir.exists()) await dir.create(recursive: true);
    var name = (suggestedName ?? '').isNotEmpty
        ? suggestedName!
        : Uri.parse(url).pathSegments.where((s) => s.isNotEmpty).lastOrNull ?? 'download';
    name = _safeName(Uri.decodeComponent(name));
    final target = p.join(dir.path, name);
    await _dio.download(url, target, onReceiveProgress: (r, t) {
      if (t > 0) onProgress?.call(r / t);
    });
    return target;
  }
}
