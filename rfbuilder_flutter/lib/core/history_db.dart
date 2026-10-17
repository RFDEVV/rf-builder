import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Riwayat build yang disimpan di HP (SQLite). Bentuk item = sama dengan
/// item di /api/apk/history supaya halaman Histori di web tampil tanpa diubah.
class HistoryDb {
  static Database? _db;

  static Future<Database> _open() async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'rfbuilder_history.db');
    _db = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute('CREATE TABLE builds('
          'id TEXT PRIMARY KEY, userId TEXT, createdAt TEXT, json TEXT)');
      await db.execute('CREATE INDEX idx_user ON builds(userId, createdAt)');
    });
    return _db!;
  }

  static Future<void> save(Map<String, dynamic> item) async {
    final db = await _open();
    item['id'] ??= 'local-${DateTime.now().microsecondsSinceEpoch}';
    item['createdAt'] ??= DateTime.now().toUtc().toIso8601String();
    await db.insert(
      'builds',
      {
        'id': item['id'].toString(),
        'userId': (item['userId'] ?? '').toString(),
        'createdAt': item['createdAt'].toString(),
        'json': jsonEncode(item),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> list(String userId) async {
    final db = await _open();
    final rows = await db.query('builds',
        where: 'userId = ?', whereArgs: [userId], orderBy: 'createdAt DESC', limit: 200);
    return rows
        .map((r) => jsonDecode(r['json'] as String) as Map<String, dynamic>)
        .toList();
  }
}
