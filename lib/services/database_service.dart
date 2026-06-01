import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../models/workout_record.dart';
import '../models/exercise_record.dart';
import '../models/workout_template.dart';
import '../models/template_exercise.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'fittimer.db');
    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Fix existing completed workouts where actual_reps/actual_weight were never saved.
      // Backfill from target values so stats show correct data.
      await db.execute('''
        UPDATE exercise_records
        SET actual_reps = target_reps,
            actual_weight = target_weight
        WHERE actual_reps IS NULL
          AND workout_id IN (
            SELECT id FROM workout_records WHERE is_completed = 1
          )
      ''');
    }
    if (oldVersion < 3) {
      // Add cardio support: exercise_type, duration, distance, speed, incline
      await db.execute("ALTER TABLE exercise_records ADD COLUMN exercise_type TEXT DEFAULT 'strength'");
      await db.execute('ALTER TABLE exercise_records ADD COLUMN duration_minutes INTEGER');
      await db.execute('ALTER TABLE exercise_records ADD COLUMN distance_km REAL');
      await db.execute('ALTER TABLE exercise_records ADD COLUMN speed REAL');
      await db.execute('ALTER TABLE exercise_records ADD COLUMN incline REAL');

      // Add cardio support to template_exercises too
      await db.execute("ALTER TABLE template_exercises ADD COLUMN exercise_type TEXT DEFAULT 'strength'");
      await db.execute('ALTER TABLE template_exercises ADD COLUMN duration_minutes INTEGER');
      await db.execute('ALTER TABLE template_exercises ADD COLUMN distance_km REAL');
      await db.execute('ALTER TABLE template_exercises ADD COLUMN speed REAL');
      await db.execute('ALTER TABLE template_exercises ADD COLUMN incline REAL');
    }
    if (oldVersion < 4) {
      // Add is_completed column to track set completion separately from actual values
      await db.execute("ALTER TABLE exercise_records ADD COLUMN is_completed INTEGER DEFAULT 0");
      // Backfill: sets that had actual_reps filled were previously considered completed
      await db.execute('UPDATE exercise_records SET is_completed = 1 WHERE actual_reps IS NOT NULL');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workout_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date INTEGER NOT NULL,
        sport_type TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        is_completed INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE exercise_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workout_id INTEGER NOT NULL,
        exercise_name TEXT NOT NULL,
        set_number INTEGER NOT NULL,
        target_reps INTEGER NOT NULL,
        actual_reps INTEGER,
        target_weight REAL NOT NULL,
        actual_weight REAL,
        rest_duration INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        exercise_type TEXT DEFAULT 'strength',
        duration_minutes INTEGER,
        distance_km REAL,
        speed REAL,
        incline REAL,
        is_completed INTEGER DEFAULT 0,
        FOREIGN KEY (workout_id) REFERENCES workout_records(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE workout_templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE template_exercises (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        template_id INTEGER NOT NULL,
        exercise_name TEXT NOT NULL,
        target_sets INTEGER NOT NULL,
        target_reps INTEGER NOT NULL,
        target_weight REAL NOT NULL,
        rest_duration INTEGER NOT NULL,
        sort_order INTEGER NOT NULL,
        exercise_type TEXT DEFAULT 'strength',
        duration_minutes INTEGER,
        distance_km REAL,
        speed REAL,
        incline REAL,
        FOREIGN KEY (template_id) REFERENCES workout_templates(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ==================== WorkoutRecord CRUD ====================

  Future<int> insertWorkoutRecord(WorkoutRecord record) async {
    final db = await database;
    return await db.insert('workout_records', record.toMap()..remove('id'));
  }

  Future<List<WorkoutRecord>> getWorkoutRecords() async {
    final db = await database;
    final maps = await db.query('workout_records', orderBy: 'date DESC');
    return maps.map((m) => WorkoutRecord.fromMap(m)).toList();
  }

  Future<WorkoutRecord?> getWorkoutRecordForDate(int startOfDay, int endOfDay) async {
    final db = await database;
    final maps = await db.query(
      'workout_records',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startOfDay, endOfDay],
      orderBy: 'date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WorkoutRecord.fromMap(maps.first);
  }

  Future<bool> hasCompletedWorkoutForDate(int startOfDay, int endOfDay) async {
    final db = await database;
    final maps = await db.query(
      'workout_records',
      where: 'date >= ? AND date <= ? AND is_completed = 1',
      whereArgs: [startOfDay, endOfDay],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<List<WorkoutRecord>> getWorkoutRecordsByDateRange(
      int startDate, int endDate) async {
    final db = await database;
    final maps = await db.query(
      'workout_records',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
      orderBy: 'date DESC',
    );
    return maps.map((m) => WorkoutRecord.fromMap(m)).toList();
  }

  Future<WorkoutRecord?> getWorkoutRecord(int id) async {
    final db = await database;
    final maps = await db.query(
      'workout_records',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return WorkoutRecord.fromMap(maps.first);
  }

  Future<int> updateWorkoutRecord(WorkoutRecord record) async {
    final db = await database;
    return await db.update(
      'workout_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteWorkoutRecord(int id) async {
    final db = await database;
    return await db.delete(
      'workout_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== ExerciseRecord CRUD ====================

  Future<int> insertExerciseRecord(ExerciseRecord record) async {
    final db = await database;
    return await db.insert('exercise_records', record.toMap()..remove('id'));
  }

  Future<List<ExerciseRecord>> getExerciseRecordsForWorkout(
      int workoutId) async {
    final db = await database;
    final maps = await db.query(
      'exercise_records',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
      orderBy: 'set_number ASC',
    );
    return maps.map((m) => ExerciseRecord.fromMap(m)).toList();
  }

  Future<int> updateExerciseRecord(ExerciseRecord record) async {
    final db = await database;
    return await db.update(
      'exercise_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<int> deleteExerciseRecord(int id) async {
    final db = await database;
    return await db.delete(
      'exercise_records',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteExerciseRecordsForWorkout(int workoutId) async {
    final db = await database;
    return await db.delete(
      'exercise_records',
      where: 'workout_id = ?',
      whereArgs: [workoutId],
    );
  }

  // ==================== WorkoutTemplate CRUD ====================

  Future<int> insertTemplate(WorkoutTemplate template) async {
    final db = await database;
    return await db.insert('workout_templates', template.toMap()..remove('id'));
  }

  Future<List<WorkoutTemplate>> getTemplates() async {
    final db = await database;
    final maps = await db.query('workout_templates', orderBy: 'created_at DESC');
    return maps.map((m) => WorkoutTemplate.fromMap(m)).toList();
  }

  Future<WorkoutTemplate?> getTemplate(int id) async {
    final db = await database;
    final maps = await db.query(
      'workout_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return WorkoutTemplate.fromMap(maps.first);
  }

  Future<int> updateTemplate(WorkoutTemplate template) async {
    final db = await database;
    return await db.update(
      'workout_templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }

  Future<int> deleteTemplate(int id) async {
    final db = await database;
    // Delete associated template exercises first
    await db.delete(
      'template_exercises',
      where: 'template_id = ?',
      whereArgs: [id],
    );
    return await db.delete(
      'workout_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ==================== TemplateExercise CRUD ====================

  Future<int> insertTemplateExercise(TemplateExercise exercise) async {
    final db = await database;
    return await db.insert(
        'template_exercises', exercise.toMap()..remove('id'));
  }

  Future<List<TemplateExercise>> getTemplateExercises(int templateId) async {
    final db = await database;
    final maps = await db.query(
      'template_exercises',
      where: 'template_id = ?',
      whereArgs: [templateId],
      orderBy: 'sort_order ASC',
    );
    return maps.map((m) => TemplateExercise.fromMap(m)).toList();
  }

  Future<int> updateTemplateExercise(TemplateExercise exercise) async {
    final db = await database;
    return await db.update(
      'template_exercises',
      exercise.toMap(),
      where: 'id = ?',
      whereArgs: [exercise.id],
    );
  }

  Future<int> deleteTemplateExercise(int id) async {
    final db = await database;
    return await db.delete(
      'template_exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteTemplateExercisesForTemplate(int templateId) async {
    final db = await database;
    return await db.delete(
      'template_exercises',
      where: 'template_id = ?',
      whereArgs: [templateId],
    );
  }

  // ==================== Settings ====================

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, String>> getAllSettings() async {
    final db = await database;
    final maps = await db.query('settings');
    return {for (var m in maps) m['key'] as String: m['value'] as String};
  }

  // ==================== Export / Import ====================

  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;

    final workoutMaps = await db.query('workout_records');
    final exerciseMaps = await db.query('exercise_records');
    final templateMaps = await db.query('workout_templates');
    final templateExerciseMaps = await db.query('template_exercises');
    final settingsMaps = await db.query('settings');

    return {
      'workout_records': workoutMaps,
      'exercise_records': exerciseMaps,
      'workout_templates': templateMaps,
      'template_exercises': templateExerciseMaps,
      'settings': settingsMaps,
      'exported_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  Future<void> importData(Map<String, dynamic> data) async {
    final db = await database;

    await db.transaction((txn) async {
      // Clear existing data
      await txn.delete('exercise_records');
      await txn.delete('workout_records');
      await txn.delete('template_exercises');
      await txn.delete('workout_templates');
      await txn.delete('settings');

      // Import workout records
      if (data['workout_records'] != null) {
        for (var record in data['workout_records'] as List) {
          await txn.insert('workout_records', Map<String, dynamic>.from(record as Map));
        }
      }

      // Import exercise records
      if (data['exercise_records'] != null) {
        for (var record in data['exercise_records'] as List) {
          await txn.insert('exercise_records', Map<String, dynamic>.from(record as Map));
        }
      }

      // Import workout templates
      if (data['workout_templates'] != null) {
        for (var record in data['workout_templates'] as List) {
          await txn.insert('workout_templates', Map<String, dynamic>.from(record as Map));
        }
      }

      // Import template exercises
      if (data['template_exercises'] != null) {
        for (var record in data['template_exercises'] as List) {
          await txn.insert('template_exercises', Map<String, dynamic>.from(record as Map));
        }
      }

      // Import settings
      if (data['settings'] != null) {
        for (var record in data['settings'] as List) {
          await txn.insert('settings', Map<String, dynamic>.from(record as Map));
        }
      }
    });
  }

  // ==================== Utility ====================

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<void> deleteDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'fittimer.db');
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    _database = null;
  }
}
