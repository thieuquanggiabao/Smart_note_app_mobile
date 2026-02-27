import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'main.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 4,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE notes (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  images TEXT,
  signatures TEXT,
  createdAt TEXT NOT NULL,
  updatedAt TEXT NOT NULL
)
''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 4) {
      await db.execute('DROP TABLE IF EXISTS notes');
      await _createDB(db, newVersion);
    }
  }

  Future<int> create(Note note) async {
    final db = await instance.database;
    return await db.insert('notes', {
      'id': note.id,
      'title': note.title,
      'content': note.content,
      'images': note.images.join(','),
      'signatures': note.signatures.join(','),
      'createdAt': note.createdAt.toIso8601String(),
      'updatedAt': note.updatedAt.toIso8601String(),
    });
  }

  Future<List<Note>> readAllNotes() async {
    final db = await instance.database;
    final result = await db.query('notes', orderBy: 'createdAt DESC');

    return result.map((json) {
      final imagesString = json['images'] as String?;
      final signaturesString = json['signatures'] as String?;
      
      return Note(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        images: imagesString != null && imagesString.isNotEmpty ? imagesString.split(',') : [],
        signatures: signaturesString != null && signaturesString.isNotEmpty ? signaturesString.split(',') : [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
    }).toList();
  }

  Future<int> update(Note note) async {
    final db = await instance.database;
    return db.update(
      'notes',
      {
        'title': note.title,
        'content': note.content,
        'images': note.images.join(','),
        'signatures': note.signatures.join(','),
        'updatedAt': note.updatedAt.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await instance.database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
