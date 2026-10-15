import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class LocalStore {
  LocalStore(this.db);
  final Database db;
  static Future<LocalStore> open() async {
    final db = await openDatabase(
      '${await getDatabasesPath()}/lumen.sqlite',
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE documents (id TEXT PRIMARY KEY, body TEXT NOT NULL)',
        );
        await db.execute(
          'CREATE TABLE drafts (id TEXT PRIMARY KEY, body TEXT NOT NULL)',
        );
      },
    );
    return LocalStore(db);
  }

  Future<List<SavedDocument>> documents() async =>
      (await db.query('documents'))
          .map(
            (r) => SavedDocument(
              Map<String, dynamic>.from(jsonDecode(r['body'] as String) as Map),
            ),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
  Future<void> saveDocument(SavedDocument doc) => db
      .insert('documents', {
        'id': doc.id,
        'body': jsonEncode(doc.data),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<void> removeDocument(String id) =>
      db.delete('documents', where: 'id=?', whereArgs: [id]).then((_) {});
  Future<void> saveDraft(Draft d) => db
      .insert('drafts', {
        'id': d.id,
        'body': jsonEncode(d.toJson()),
      }, conflictAlgorithm: ConflictAlgorithm.replace)
      .then((_) {});
  Future<Draft?> draft() async {
    final rows = await db.query('drafts');
    if (rows.isEmpty) return null;
    return Draft.fromJson(
      Map<String, dynamic>.from(jsonDecode(rows.last['body'] as String) as Map),
    );
  }

  Future<void> clearDraft(String id) =>
      db.delete('drafts', where: 'id=?', whereArgs: [id]).then((_) {});
}
