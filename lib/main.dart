import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fridgetracker/screens/home_screen.dart';
import 'package:fridgetracker/services/database_service.dart';
import 'package:fridgetracker/services/notification_service.dart';
import 'package:provider/provider.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  Future<void> debugDumpDatabase() async {
    final svc = DatabaseService();
    svc.setDebug(true);

    try {
      final db = await svc.database;
      print('[DB DEBUG] DB path: ${db.path}');

      final productCountRow = await db.rawQuery('SELECT COUNT(*) as c FROM products');
      final productCount = productCountRow.isNotEmpty ? productCountRow.first['c'] : 0;
      print('[DB DEBUG] products count = $productCount');

      final inventoryCountRow = await db.rawQuery('SELECT COUNT(*) as c FROM inventory');
      final inventoryCount = inventoryCountRow.isNotEmpty ? inventoryCountRow.first['c'] : 0;
      print('[DB DEBUG] inventory count = $inventoryCount');

      final products = await db.rawQuery('SELECT * FROM products ORDER BY name LIMIT 10');
      print('[DB DEBUG] sample products (${products.length}):');
      for (final p in products) print('  $p');

      final inventory = await db.rawQuery('SELECT * FROM inventory ORDER BY id DESC LIMIT 10');
      print('[DB DEBUG] sample inventory (${inventory.length}):');
      for (final i in inventory) print('  $i');

    } catch (e, st) {
      print('[DB DEBUG] exception: $e\n$st');
    }
  }
  debugDumpDatabase();
  // Initialize services
  final databaseService = DatabaseService();
  await databaseService.database; // Initialize database
  await NotificationService().init();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(MyApp(databaseService: databaseService));
  });
}

class MyApp extends StatelessWidget {
  final DatabaseService databaseService;

  const MyApp({super.key, required this.databaseService});

  @override
  Widget build(BuildContext context) {
    return Provider<DatabaseService>.value(
      value: databaseService,
      child: MaterialApp(
        title: 'Pantry Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          fontFamily: 'Inter',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}