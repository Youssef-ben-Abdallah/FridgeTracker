import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import '../models/inventory_item.dart';
import '../models/product.dart';
import '../models/shopping_item.dart';
import '../utils/constants.dart';

class DatabaseService {
  static DatabaseService? _instance;
  Database? _database;

  /// Enable/disable debug logging at runtime
  bool _debug = true;

  DatabaseService._internal();

  factory DatabaseService() {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  /// Turn on/off debug logging
  void setDebug(bool enabled) {
    _debug = enabled;
    _log('Debug mode set to: $_debug', level: 800);
  }

  void _log(String message,
      {String name = 'DatabaseService', int level = 800, Object? error, StackTrace? stackTrace}) {
    if (!_debug && !const bool.fromEnvironment('dart.vm.product') == false) {
      // If debug is off and we're in release mode, suppress logs.
      // But allow logs in debug/profile builds when _debug is true.
      if (!_debug) return;
    }
    developer.log(message, name: name, level: level, error: error, stackTrace: stackTrace);
  }

  Future<Database> get database async {
    if (_database != null) {
      _log('database getter: returning cached DB instance', level: 700);
      return _database!;
    }
    _log('database getter: initializing DB', level: 700);
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, AppConstants.databaseName);
      _log('Initializing DB at path: $path', level: 800);

      final db = await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
        onConfigure: _onConfigure,
      );

      _log('Database opened successfully', level: 800);
      return db;
    } catch (e, st) {
      _log('Failed to initialize database: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _onConfigure(Database db) async {
    _log('_onConfigure: enabling foreign_keys pragma', level: 800);
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _createTables(Database db, int version) async {
    _log('_createTables: creating tables (version $version)', level: 800);
    try {
      // Products table
      await db.execute('''
      CREATE TABLE products(
        barcode TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        default_expiration_days INTEGER,
        image_path TEXT,
        created_at INTEGER NOT NULL,
        minimum_stock INTEGER DEFAULT 1
      )
    ''');

      await db.execute('CREATE INDEX idx_products_category ON products(category)');
      await db.execute('CREATE INDEX idx_products_name ON products(name)');

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

      // Inventory indexes
      await db.execute('CREATE INDEX idx_inventory_barcode ON inventory(barcode)');
      await db.execute('CREATE INDEX idx_inventory_expiry ON inventory(expiry_at)');
      await db.execute('CREATE INDEX idx_inventory_consumed ON inventory(is_consumed)');
      await db.execute('CREATE INDEX idx_inventory_category ON inventory(category)');

      // Shopping List table
      await db.execute('''
      CREATE TABLE shopping_list(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id TEXT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity_needed INTEGER DEFAULT 1,
        unit TEXT,
        priority INTEGER DEFAULT 1,
        is_purchased INTEGER DEFAULT 0,
        added_at INTEGER NOT NULL,
        purchased_at INTEGER,
        notes TEXT,
        suggested_by TEXT,
        estimated_price REAL,
        FOREIGN KEY (product_id) REFERENCES products(barcode) ON DELETE SET NULL
      )
    ''');

      // Shopping List indexes
      await db.execute('CREATE INDEX idx_shopping_purchased ON shopping_list(is_purchased)');
      await db.execute('CREATE INDEX idx_shopping_priority ON shopping_list(priority)');
      await db.execute('CREATE INDEX idx_shopping_category ON shopping_list(category)');

      // Insert default data
      await _insertDefaultData(db);

      _log('_createTables: tables & indexes created successfully', level: 800);
    } catch (e, st) {
      _log('_createTables failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _insertDefaultData(Database db) async {
    _log('_insertDefaultData: checking product count', level: 800);
    try {
      final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM products')) ?? 0;
      _log('_insertDefaultData: product count = $count', level: 800);

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
          _log('Inserted default product: ${product.name} (${product.barcode})', level: 800);
        }
      } else {
        _log('_insertDefaultData: skipping insertion (products already exist)', level: 700);
      }
    } catch (e, st) {
      _log('_insertDefaultData failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  // ========== PRODUCT OPERATIONS ==========

  Future<int> insertProduct(Product product) async {
    final stopwatch = Stopwatch()..start();
    try {
      final db = await database;
      _log('insertProduct: inserting ${product.barcode}', level: 800);
      final id = await db.insert('products', product.toMap());
      stopwatch.stop();
      _log('insertProduct: inserted ${product.barcode} in ${stopwatch.elapsedMilliseconds}ms', level: 800);
      return id;
    } catch (e, st) {
      _log('insertProduct failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    try {
      final db = await database;
      _log('getProductByBarcode: querying $barcode', level: 800);
      final maps = await db.query('products', where: 'barcode = ?', whereArgs: [barcode]);
      if (maps.isNotEmpty) {
        _log('getProductByBarcode: found ${maps.length} rows', level: 800);
        return Product.fromMap(maps.first);
      } else {
        _log('getProductByBarcode: not found', level: 700);
        return null;
      }
    } catch (e, st) {
      _log('getProductByBarcode failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Product>> searchProducts(String query) async {
    try {
      final db = await database;
      _log('searchProducts: query="$query"', level: 800);
      final maps = await db.query(
        'products',
        where: 'name LIKE ? OR barcode LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'name ASC',
      );
      _log('searchProducts: found ${maps.length} results', level: 800);
      return maps.map((map) => Product.fromMap(map)).toList();
    } catch (e, st) {
      _log('searchProducts failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<Product>> getAllProducts() async {
    try {
      final db = await database;
      _log('getAllProducts: querying all products', level: 800);
      final maps = await db.query('products', orderBy: 'name ASC');
      _log('getAllProducts: ${maps.length} products', level: 800);
      return maps.map((map) => Product.fromMap(map)).toList();
    } catch (e, st) {
      _log('getAllProducts failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<int> updateProduct(Product product) async {
    try {
      final db = await database;
      _log('updateProduct: updating ${product.barcode}', level: 800);
      final rows = await db.update(
        'products',
        product.toMap(),
        where: 'barcode = ?',
        whereArgs: [product.barcode],
      );
      _log('updateProduct: updated $rows rows', level: 800);
      return rows;
    } catch (e, st) {
      _log('updateProduct failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<int> deleteProduct(String barcode) async {
    try {
      final db = await database;
      _log('deleteProduct: deleting $barcode', level: 800);
      final rows = await db.delete('products', where: 'barcode = ?', whereArgs: [barcode]);
      _log('deleteProduct: deleted $rows rows', level: 800);
      return rows;
    } catch (e, st) {
      _log('deleteProduct failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<String>> getAllCategories() async {
    try {
      final db = await database;
      _log('getAllCategories: querying distinct categories', level: 800);
      final maps = await db.rawQuery('SELECT DISTINCT category FROM products ORDER BY category');
      final categories = maps.map((map) => map['category'] as String).toList();
      _log('getAllCategories: ${categories.length} categories', level: 800);
      return categories;
    } catch (e, st) {
      _log('getAllCategories failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  // ========== INVENTORY OPERATIONS ==========

  Future<int> insertInventoryItem(InventoryItem item) async {
    final stopwatch = Stopwatch()..start();
    try {
      final db = await database;
      _log('insertInventoryItem: inserting ${item.name}', level: 800);
      item.id = await db.insert('inventory', item.toMap());
      stopwatch.stop();
      _log('insertInventoryItem: id=${item.id} (${stopwatch.elapsedMilliseconds}ms)', level: 800);
      return item.id!;
    } catch (e, st) {
      _log('insertInventoryItem failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<InventoryItem>> getInventoryItems() async {
    try {
      final db = await database;
      _log('getInventoryItems: querying active inventory', level: 800);
      final maps = await db.query(
        'inventory',
        where: 'is_consumed = 0',
        orderBy: 'expiry_at ASC, name ASC',
      );
      _log('getInventoryItems: ${maps.length} items', level: 800);
      return maps.map((map) => InventoryItem.fromMap(map)).toList();
    } catch (e, st) {
      _log('getInventoryItems failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<InventoryItem>> getExpiringSoonItems() async {
    try {
      final db = await database;
      final now = DateTime.now();
      final threeDaysFromNow = now.add(const Duration(days: 3)).millisecondsSinceEpoch;
      _log('getExpiringSoonItems: threshold=$threeDaysFromNow', level: 800);

      final maps = await db.query(
        'inventory',
        where: 'expiry_at <= ? AND is_consumed = 0',
        whereArgs: [threeDaysFromNow],
        orderBy: 'expiry_at ASC',
      );
      _log('getExpiringSoonItems: ${maps.length} items', level: 800);
      return maps.map((map) => InventoryItem.fromMap(map)).toList();
    } catch (e, st) {
      _log('getExpiringSoonItems failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<List<InventoryItem>> getExpiredItems() async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      _log('getExpiredItems: now=$now', level: 800);

      final maps = await db.query(
        'inventory',
        where: 'expiry_at < ? AND is_consumed = 0',
        whereArgs: [now],
        orderBy: 'expiry_at ASC',
      );
      _log('getExpiredItems: ${maps.length} items', level: 800);
      return maps.map((map) => InventoryItem.fromMap(map)).toList();
    } catch (e, st) {
      _log('getExpiredItems failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<InventoryItem?> getInventoryItem(int id) async {
    try {
      final db = await database;
      _log('getInventoryItem: id=$id', level: 800);
      final maps = await db.query('inventory', where: 'id = ?', whereArgs: [id]);
      if (maps.isNotEmpty) {
        _log('getInventoryItem: found', level: 800);
        return InventoryItem.fromMap(maps.first);
      }
      _log('getInventoryItem: not found', level: 700);
      return null;
    } catch (e, st) {
      _log('getInventoryItem failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<int> updateInventoryItem(InventoryItem item) async {
    try {
      final db = await database;
      _log('updateInventoryItem: id=${item.id}', level: 800);
      final rows = await db.update('inventory', item.toMap(), where: 'id = ?', whereArgs: [item.id]);
      _log('updateInventoryItem: updated $rows rows', level: 800);
      return rows;
    } catch (e, st) {
      _log('updateInventoryItem failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<int> deleteInventoryItem(int id) async {
    try {
      final db = await database;
      _log('deleteInventoryItem: id=$id', level: 800);
      final rows = await db.delete('inventory', where: 'id = ?', whereArgs: [id]);
      _log('deleteInventoryItem: deleted $rows rows', level: 800);
      return rows;
    } catch (e, st) {
      _log('deleteInventoryItem failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<int> markAsConsumed(int id) async {
    try {
      final db = await database;
      _log('markAsConsumed: id=$id', level: 800);
      final rows = await db.update(
        'inventory',
        {'is_consumed': 1, 'expiry_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
      _log('markAsConsumed: updated $rows rows', level: 800);
      return rows;
    } catch (e, st) {
      _log('markAsConsumed failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<int> getInventoryCount() async {
    try {
      final db = await database;
      _log('getInventoryCount: querying count', level: 800);
      final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM inventory WHERE is_consumed = 0'));
      final result = count ?? 0;
      _log('getInventoryCount: $result', level: 800);
      return result;
    } catch (e, st) {
      _log('getInventoryCount failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<int> getExpiringSoonCount() async {
    try {
      final db = await database;
      final now = DateTime.now();
      final threeDaysFromNow = now.add(const Duration(days: 3)).millisecondsSinceEpoch;
      _log('getExpiringSoonCount: threshold=$threeDaysFromNow', level: 800);

      final count = Sqflite.firstIntValue(await db.rawQuery(
          'SELECT COUNT(*) FROM inventory WHERE expiry_at <= ? AND is_consumed = 0',
          [threeDaysFromNow]));
      final result = count ?? 0;
      _log('getExpiringSoonCount: $result', level: 800);
      return result;
    } catch (e, st) {
      _log('getExpiringSoonCount failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> clearConsumedItems() async {
    try {
      final db = await database;
      _log('clearConsumedItems: deleting consumed items', level: 800);
      await db.delete('inventory', where: 'is_consumed = 1');
      _log('clearConsumedItems: done', level: 800);
    } catch (e, st) {
      _log('clearConsumedItems failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteExpiredItems() async {
    try {
      final db = await database;
      final now = DateTime.now().millisecondsSinceEpoch;
      _log('deleteExpiredItems: deleting items older than $now', level: 800);
      await db.delete('inventory', where: 'expiry_at < ? AND is_consumed = 0', whereArgs: [now]);
      _log('deleteExpiredItems: done', level: 800);
    } catch (e, st) {
      _log('deleteExpiredItems failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  // ========== STATISTICS ==========

  Future<Map<String, dynamic>> getStatistics() async {
    try {
      final db = await database;
      _log('getStatistics: gathering stats', level: 800);

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

      _log('getStatistics: done', level: 800);

      return {
        'totalItems': totalItems,
        'expiringSoon': expiringSoon,
        'categories': categoryCounts,
        'soonestExpiry': soonestExpiry,
      };
    } catch (e, st) {
      _log('getStatistics failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> close() async {
    try {
      if (_database != null) {
        _log('close: closing database', level: 800);
        await _database!.close();
        _database = null;
        _log('close: DB closed', level: 800);
      } else {
        _log('close: DB already null', level: 700);
      }
    } catch (e, st) {
      _log('close failed: $e', level: 1000, error: e, stackTrace: st);
      rethrow;
    }
  }

  // Add these methods to DatabaseService class:

// ========== SHOPPING LIST OPERATIONS ==========

  Future<int> insertShoppingItem(ShoppingItem item) async {
    final db = await database;
    item.id = await db.insert('shopping_list', item.toMap());
    return item.id!;
  }

  Future<List<ShoppingItem>> getShoppingItems({bool includePurchased = false}) async {
    final db = await database;
    final where = includePurchased ? null : 'is_purchased = 0';
    final maps = await db.query(
      'shopping_list',
      where: where,
      orderBy: 'priority DESC, added_at ASC',
    );
    return maps.map((map) => ShoppingItem.fromMap(map)).toList();
  }

  Future<List<ShoppingItem>> getShoppingItemsByPriority(int priority) async {
    final db = await database;
    final maps = await db.query(
      'shopping_list',
      where: 'priority = ? AND is_purchased = 0',
      whereArgs: [priority],
      orderBy: 'added_at ASC',
    );
    return maps.map((map) => ShoppingItem.fromMap(map)).toList();
  }

  Future<List<ShoppingItem>> getHighPriorityShoppingItems() async {
    return await getShoppingItemsByPriority(3);
  }

  Future<ShoppingItem?> getShoppingItem(int id) async {
    final db = await database;
    final maps = await db.query(
      'shopping_list',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ShoppingItem.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateShoppingItem(ShoppingItem item) async {
    final db = await database;
    return await db.update(
      'shopping_list',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteShoppingItem(int id) async {
    final db = await database;
    return await db.delete(
      'shopping_list',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAsPurchased(int id) async {
    final db = await database;
    return await db.update(
      'shopping_list',
      {
        'is_purchased': 1,
        'purchased_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> markAsNotPurchased(int id) async {
    final db = await database;
    return await db.update(
      'shopping_list',
      {
        'is_purchased': 0,
        'purchased_at': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> clearPurchasedItems() async {
    final db = await database;
    return await db.delete(
      'shopping_list',
      where: 'is_purchased = 1',
    );
  }

  Future<int> getShoppingListCount({bool includePurchased = false}) async {
    final db = await database;
    final where = includePurchased ? null : 'is_purchased = 0';
    final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM shopping_list ${where != null ? 'WHERE $where' : ''}')
    );
    return count ?? 0;
  }

// ========== SMART SUGGESTIONS ==========

  Future<List<ShoppingItem>> getLowStockSuggestions() async {
    final db = await database;

    // Get products with their current inventory count
    final query = '''
    SELECT 
      p.barcode,
      p.name,
      p.category,
      p.minimum_stock,
      p.default_expiration_days,
      COALESCE(SUM(i.quantity), 0) as current_stock
    FROM products p
    LEFT JOIN inventory i ON p.barcode = i.barcode AND i.is_consumed = 0
    GROUP BY p.barcode, p.name, p.category, p.minimum_stock
    HAVING current_stock < p.minimum_stock OR current_stock = 0
    ORDER BY (p.minimum_stock - current_stock) DESC, p.name ASC
  ''';

    final results = await db.rawQuery(query);

    final List<ShoppingItem> suggestions = [];

    for (final row in results) {
      final currentStock = (row['current_stock'] as int?) ?? 0;
      final minimumStock = (row['minimum_stock'] as int?) ?? 1;
      final needed = minimumStock - currentStock;

      if (needed > 0) {
        // Calculate priority based on how low stock is
        final priority = _calculateStockPriority(currentStock, minimumStock);

        final suggestion = ShoppingItem(
          productId: row['barcode'] as String?,
          name: row['name'] as String,
          category: row['category'] as String,
          quantityNeeded: needed,
          unit: 'pcs', // Default unit
          priority: priority,
          addedAt: DateTime.now().millisecondsSinceEpoch,
          suggestedBy: 'low_stock',
        );

        suggestions.add(suggestion);
      }
    }

    return suggestions;
  }

  int _calculateStockPriority(int currentStock, int minimumStock) {
    final percentage = (currentStock / minimumStock) * 100;

    if (currentStock == 0) {
      return 3; // High priority - completely out of stock
    } else if (percentage <= 25) {
      return 3; // High priority - very low stock
    } else if (percentage <= 50) {
      return 2; // Medium priority - low stock
    } else {
      return 1; // Low priority - slightly low stock
    }
  }

// Check if item already exists in shopping list
  Future<bool> isItemInShoppingList(String productId) async {
    final db = await database;
    final count = Sqflite.firstIntValue(
        await db.rawQuery(
            'SELECT COUNT(*) FROM shopping_list WHERE product_id = ? AND is_purchased = 0',
            [productId]
        )
    );
    return (count ?? 0) > 0;
  }

// Get categories for shopping list grouping
  Future<Map<String, List<ShoppingItem>>> getShoppingListByCategory() async {
    final items = await getShoppingItems();
    final Map<String, List<ShoppingItem>> categorized = {};

    for (final item in items) {
      if (!categorized.containsKey(item.category)) {
        categorized[item.category] = [];
      }
      categorized[item.category]!.add(item);
    }

    return categorized;
  }

// Add multiple suggestions to shopping list
  Future<int> addSuggestionsToShoppingList(List<ShoppingItem> suggestions) async {
    int addedCount = 0;

    for (final suggestion in suggestions) {
      // Check if already in shopping list
      if (suggestion.productId != null) {
        final alreadyExists = await isItemInShoppingList(suggestion.productId!);
        if (alreadyExists) continue;
      }

      await insertShoppingItem(suggestion);
      addedCount++;
    }

    return addedCount;
  }

// Get shopping statistics
  Future<Map<String, dynamic>> getShoppingStatistics() async {
    final db = await database;

    final totalItems = await getShoppingListCount();
    final highPriority = (await getHighPriorityShoppingItems()).length;

    final categories = await db.rawQuery('''
    SELECT category, COUNT(*) as count 
    FROM shopping_list 
    WHERE is_purchased = 0 
    GROUP BY category 
    ORDER BY count DESC
  ''');

    final suggestedItems = await db.rawQuery('''
    SELECT suggested_by, COUNT(*) as count 
    FROM shopping_list 
    WHERE is_purchased = 0 
    GROUP BY suggested_by
  ''');

    return {
      'totalItems': totalItems,
      'highPriority': highPriority,
      'categories': categories,
      'suggestedBy': suggestedItems,
    };
  }

// Update product minimum stock
  Future<int> updateProductMinimumStock(String barcode, int minimumStock) async {
    final db = await database;
    return await db.update(
      'products',
      {'minimum_stock': minimumStock},
      where: 'barcode = ?',
      whereArgs: [barcode],
    );
  }

// Get products that need minimum stock setup
  Future<List<Product>> getProductsWithoutMinimumStock() async {
    final db = await database;
    final maps = await db.query(
      'products',
      where: 'minimum_stock IS NULL',
      orderBy: 'name ASC',
    );

    return maps.map((map) => Product.fromMap(map)).toList();
  }
}
