import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/material.dart';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;

  Future<Database> get database async {
    if (kIsWeb) { databaseFactory = databaseFactoryFfiWeb; }

    if (_database != null) return _database!;

    if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasePath = await getDatabasesPath();

    _database = await openDatabase(
      join(databasePath, 'equipment_checkout.db'),
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE equipment (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            condition TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE borrowers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            department TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE checkouts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            equipment_id INTEGER NOT NULL,
            borrower_id INTEGER NOT NULL,
            checkout_date TEXT NOT NULL,
            due_date TEXT NOT NULL,
            return_date TEXT,
            FOREIGN KEY (equipment_id)
              REFERENCES equipment(id) ON DELETE RESTRICT,
            FOREIGN KEY (borrower_id)
              REFERENCES borrowers(id) ON DELETE RESTRICT,
            CHECK (due_date > checkout_date),
            CHECK (
              return_date IS NULL OR
              return_date >= checkout_date
            )
          )
        ''');

        await db.execute('''
          CREATE UNIQUE INDEX one_active_checkout
          ON checkouts(equipment_id)
          WHERE return_date IS NULL
        ''');
      },
    );

    return _database!;
  }

  Future<List<Map<String, Object?>>> getEquipment() async {
    final db = await database;

    return db.rawQuery('''
      SELECT e.*,
        CASE WHEN EXISTS (
          SELECT 1 FROM checkouts c
          WHERE c.equipment_id = e.id
          AND c.return_date IS NULL
        ) THEN 'Checked Out'
        ELSE 'Available'
        END AS availability
      FROM equipment e
      ORDER BY e.name
    ''');
  }

  Future<int> addEquipment(Map<String, Object?> item) async {
    final db = await database;
    return db.insert('equipment', item);
  }

  Future<int> updateEquipment(
    int id,
    Map<String, Object?> item,
  ) async {
    final db = await database;
    return db.update(
      'equipment',
      item,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteEquipment(int id) async {
    final db = await database;

    return db.transaction((txn) async {
      final history = Sqflite.firstIntValue(
        await txn.rawQuery(
          'SELECT COUNT(*) FROM checkouts WHERE equipment_id = ?',
          [id],
        ),
      ) ?? 0;

      if (history > 0) {
        throw StateError(
          'Equipment with checkout history cannot be deleted.',
        );
      }

      return txn.delete(
        'equipment',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<List<Map<String, Object?>>> getBorrowers() async {
    final db = await database;

    return db.rawQuery('''
      SELECT b.*,
        (SELECT COUNT(*) FROM checkouts c
         WHERE c.borrower_id = b.id
         AND c.return_date IS NULL) AS active_count
      FROM borrowers b
      ORDER BY b.name
    ''');
  }

  Future<int> addBorrower(Map<String, Object?> borrower) async {
    final db = await database;
    return db.insert('borrowers', borrower);
  }

  Future<int> updateBorrower(
    int id,
    Map<String, Object?> borrower,
  ) async {
    final db = await database;
    return db.update(
      'borrowers',
      borrower,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteBorrower(int id) async {
    final db = await database;

    return db.transaction((txn) async {
      final history = Sqflite.firstIntValue(
        await txn.rawQuery(
          'SELECT COUNT(*) FROM checkouts WHERE borrower_id = ?',
          [id],
        ),
      ) ?? 0;

      if (history > 0) {
        throw StateError(
          'Borrowers with checkout history cannot be deleted.',
        );
      }

      return txn.delete(
        'borrowers',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<int> createCheckout({
    required int equipmentId,
    required int borrowerId,
    required DateTime checkoutDate,
    required DateTime dueDate,
  }) async {
    final start = DateUtils.dateOnly(checkoutDate);
    final due = DateUtils.dateOnly(dueDate);

    if (!due.isAfter(start)) {
      throw ArgumentError(
        'Due date must be later than checkout date.',
      );
    }

    final db = await database;

    return db.transaction((txn) async {
      final available = Sqflite.firstIntValue(
        await txn.rawQuery('''
          SELECT COUNT(*) FROM equipment
          WHERE id = ?
          AND NOT EXISTS (
            SELECT 1 FROM checkouts
            WHERE equipment_id = ?
            AND return_date IS NULL
          )
        ''', [equipmentId, equipmentId]),
      ) ?? 0;

      if (available == 0) {
        throw StateError('Equipment is not available.');
      }

      final borrowers = Sqflite.firstIntValue(
        await txn.rawQuery(
          'SELECT COUNT(*) FROM borrowers WHERE id = ?',
          [borrowerId],
        ),
      ) ?? 0;

      if (borrowers == 0) {
        throw StateError('Select a valid borrower.');
      }

      return txn.insert('checkouts', {
        'equipment_id': equipmentId,
        'borrower_id': borrowerId,
        'checkout_date': start.toIso8601String().substring(0, 10),
        'due_date': due.toIso8601String().substring(0, 10),
      });
    });
  }

  Future<int> returnEquipment(
    int checkoutId,
    DateTime returnDate,
  ) async {
    final db = await database;
    final date = DateUtils.dateOnly(returnDate)
        .toIso8601String()
        .substring(0, 10);

    return db.transaction((txn) async {
      final records = await txn.query(
        'checkouts',
        columns: ['checkout_date'],
        where: 'id = ? AND return_date IS NULL',
        whereArgs: [checkoutId],
      );

      if (records.isEmpty) {
        throw StateError('Checkout already returned or not found.');
      }

      if (date.compareTo(records.first['checkout_date'] as String) < 0) {
        throw ArgumentError(
          'Return date cannot be before checkout date.',
        );
      }

      return txn.update(
        'checkouts',
        {'return_date': date},
        where: 'id = ? AND return_date IS NULL',
        whereArgs: [checkoutId],
      );
    });
  }

  Future<List<Map<String, Object?>>> getCheckoutHistory() async {
    final db = await database;

    return db.rawQuery('''
      SELECT c.*,
        e.name AS equipment_name,
        b.name AS borrower_name,
        CASE
          WHEN c.return_date IS NOT NULL THEN 'Returned'
          WHEN c.due_date < date('now', 'localtime') THEN 'Overdue'
          ELSE 'Active'
        END AS status
      FROM checkouts c
      JOIN equipment e ON e.id = c.equipment_id
      JOIN borrowers b ON b.id = c.borrower_id
      ORDER BY c.checkout_date DESC, c.id DESC
    ''');
  }
}


