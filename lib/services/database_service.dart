import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../models/inventory_item.dart';
import '../models/product.dart';
import '../utils/constants.dart';

class DatabaseService {
  static DatabaseService? _instance;
  Database? _database;

  DatabaseService._internal();

  factory DatabaseService() {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createTables(Database db, int version) async {
    // Products table
    await db.execute('''
      CREATE TABLE products(
        barcode TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        default_expiration_days INTEGER,
        image_path TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for products
    await db.execute('''
      CREATE INDEX idx_products_category ON products(category)
    ''');

    await db.execute('''
      CREATE INDEX idx_products_name ON products(name)
    ''');

    // Inventory table
    await db.execute('''
      CREATE TABLE inventory(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity INTEGER DEFAULT 1,
        unit TEXT,
        added_at INTEGER NOT NULL,
        expiry_at INTEGER NOT NULL,
        photo_path TEXT,
        notes TEXT,
        is_consumed INTEGER DEFAULT 0,
        FOREIGN KEY (barcode) REFERENCES products(barcode) ON DELETE CASCADE
      )
    ''');

    // Create indexes for inventory
    await db.execute('''
      CREATE INDEX idx_inventory_barcode ON inventory(barcode)
    ''');

    await db.execute('''
      CREATE INDEX idx_inventory_expiry ON inventory(expiry_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_inventory_consumed ON inventory(is_consumed)
    ''');

    await db.execute('''
      CREATE INDEX idx_inventory_category ON inventory(category)
    ''');

    // Insert default categories
    await _insertDefaultData(db);
  }

  Future<void> _insertDefaultData(Database db) async {
    // Insert some sample products if the database is empty
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM products')
    );

    if (count == 0) {
      final sampleProducts = [
        Product(
          barcode: '5901234123457',
          name: 'Milk',
          category: 'Dairy',
          defaultExpirationDays: 7,
        ),
        Product(
          barcode: '5901234123458',
          name: 'Bread',
          category: 'Bakery',
          defaultExpirationDays: 3,
        ),
        Product(
          barcode: '5901234123459',
          name: 'Eggs',
          category: 'Dairy',
          defaultExpirationDays: 14,
        ),
        Product(
          barcode: '5901234123460',
          name: 'Chicken Breast',
          category: 'Meat',
          defaultExpirationDays: 3,
        ),
        Product(
          barcode: '5901234123461',
          name: 'Tomatoes',
          category: 'Produce',
          defaultExpirationDays: 5,
        ),
        Product(
          barcode: '5901234123462',
          name: 'Coca-Cola',
          category: 'Beverages',
          defaultExpirationDays: 90,
        ),
      ];

      for (var product in sampleProducts) {
        await db.insert('products', product.toMap());
      }
    }
  }

  // ========== PRODUCT OPERATIONS ==========

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert('products', product.toMap());
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );

    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Product>> searchProducts(String query) async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'name LIKE ? OR barcode LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final maps = await db.query('products', orderBy: 'name ASC');
    return maps.map((map) => Product.fromMap(map)).toList();
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      'products',
      product.toMap(),
      where: 'barcode = ?',
      whereArgs: [product.barcode],
    );
  }

  Future<int> deleteProduct(String barcode) async {
    final db = await database;
    return await db.delete(
      'products',
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
  }

  Future<List<String>> getAllCategories() async {
    final db = await database;
    final maps = await db.rawQuery('''
      SELECT DISTINCT category FROM products ORDER BY category
    ''');

    return maps.map((map) => map['category'] as String).toList();
  }

  // ========== INVENTORY OPERATIONS ==========

  Future<int> insertInventoryItem(InventoryItem item) async {
    final db = await database;
    item.id = await db.insert('inventory', item.toMap());
    return item.id!;
  }

  Future<List<InventoryItem>> getInventoryItems() async {
    final db = await database;
    final maps = await db.query(
      'inventory',
      where: 'is_consumed = 0',
      orderBy: 'expiry_at ASC, name ASC',
    );
    return maps.map((map) => InventoryItem.fromMap(map)).toList();
  }

  Future<List<InventoryItem>> getExpiringSoonItems() async {
    final db = await database;
    final now = DateTime.now();
    final threeDaysFromNow = now.add(const Duration(days: 3)).millisecondsSinceEpoch;

    final maps = await db.query(
      'inventory',
      where: 'expiry_at <= ? AND is_consumed = 0',
      whereArgs: [threeDaysFromNow],
      orderBy: 'expiry_at ASC',
    );
    return maps.map((map) => InventoryItem.fromMap(map)).toList();
  }

  Future<List<InventoryItem>> getExpiredItems() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    final maps = await db.query(
      'inventory',
      where: 'expiry_at < ? AND is_consumed = 0',
      whereArgs: [now],
      orderBy: 'expiry_at ASC',
    );
    return maps.map((map) => InventoryItem.fromMap(map)).toList();
  }

  Future<InventoryItem?> getInventoryItem(int id) async {
    final db = await database;
    final maps = await db.query(
      'inventory',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return InventoryItem.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateInventoryItem(InventoryItem item) async {
    final db = await database;
    return await db.update(
      'inventory',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteInventoryItem(int id) async {
    final db = await database;
    return await db.delete(
      'inventory',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAsConsumed(int id) async {
    final db = await database;
    return await db.update(
      'inventory',
      {'is_consumed': 1, 'expiry_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> getInventoryCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM inventory WHERE is_consumed = 0')
    );
    return count ?? 0;
  }

  Future<int> getExpiringSoonCount() async {
    final db = await database;
    final now = DateTime.now();
    final threeDaysFromNow = now.add(const Duration(days: 3)).millisecondsSinceEpoch;

    final count = Sqflite.firstIntValue(
        await db.rawQuery(
            'SELECT COUNT(*) FROM inventory WHERE expiry_at <= ? AND is_consumed = 0',
            [threeDaysFromNow]
        )
    );
    return count ?? 0;
  }

  Future<void> clearConsumedItems() async {
    final db = await database;
    await db.delete(
      'inventory',
      where: 'is_consumed = 1',
    );
  }

  Future<void> deleteExpiredItems() async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.delete(
      'inventory',
      where: 'expiry_at < ? AND is_consumed = 0',
      whereArgs: [now],
    );
  }

  // ========== STATISTICS ==========

  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;

    final totalItems = await getInventoryCount();
    final expiringSoon = await getExpiringSoonCount();

    final categoryCounts = await db.rawQuery('''
      SELECT category, COUNT(*) as count 
      FROM inventory 
      WHERE is_consumed = 0 
      GROUP BY category 
      ORDER BY count DESC
    ''');

    final soonestExpiry = await db.rawQuery('''
      SELECT name, expiry_at 
      FROM inventory 
      WHERE is_consumed = 0 
      ORDER BY expiry_at ASC 
      LIMIT 5
    ''');

    return {
      'totalItems': totalItems,
      'expiringSoon': expiringSoon,
      'categories': categoryCounts,
      'soonestExpiry': soonestExpiry,
    };
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}