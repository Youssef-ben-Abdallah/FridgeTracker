import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

class MinimumStockScreen extends StatefulWidget {
  const MinimumStockScreen({super.key});

  @override
  State<MinimumStockScreen> createState() => _MinimumStockScreenState();
}

class _MinimumStockScreenState extends State<MinimumStockScreen> {
  late Future<List<Product>> _productsFuture;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    _productsFuture = dbService.getAllProducts();
  }

  Future<void> _updateMinimumStock(Product product, int minimumStock) async {
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.updateProductMinimumStock(product.barcode, minimumStock);

      // Update the product in the list
      setState(() {
        product.defaultExpirationDays = minimumStock;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} minimum stock updated to $minimumStock')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildProductRow(Product product) {
    final controller = _controllers[product.barcode] ??= TextEditingController(
      text: (product.defaultExpirationDays ?? 1).toString(),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppConstants.categoryColors[product.category]?.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          product.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppConstants.categoryColors[product.category] ?? Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Barcode: ${product.barcode}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Minimum stock input
            SizedBox(
              width: 100,
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Min Stock',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8),
                ),
                keyboardType: TextInputType.number,
                onSubmitted: (value) {
                  final minStock = int.tryParse(value);
                  if (minStock != null && minStock > 0) {
                    _updateMinimumStock(product, minStock);
                  }
                },
              ),
            ),

            // Update button
            IconButton(
              icon: const Icon(Icons.check, color: Colors.green),
              onPressed: () {
                final minStock = int.tryParse(controller.text);
                if (minStock != null && minStock > 0) {
                  _updateMinimumStock(product, minStock);
                }
              },
              tooltip: 'Update minimum stock',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setAllToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Default Minimum Stock'),
        content: const Text('Set minimum stock to category defaults for all products?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Set Defaults'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final products = await dbService.getAllProducts();

      int updatedCount = 0;
      for (final product in products) {
        final defaultMinStock = AppConstants.defaultMinimumStock[product.category] ?? 1;
        await dbService.updateProductMinimumStock(product.barcode, defaultMinStock);
        updatedCount++;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated $updatedCount products to default minimum stock')),
      );

      _loadProducts();
    }
  }

  @override
  void dispose() {
    // Dispose all controllers
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minimum Stock Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.auto_fix_high),
            onPressed: _setAllToDefault,
            tooltip: 'Set All to Defaults',
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text(
                    'Error loading products',
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _loadProducts,
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          final products = snapshot.data ?? [];

          if (products.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2,
                    size: 80,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No products found',
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Add products first to set minimum stock levels',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Info card
              Card(
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Minimum Stock Levels',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Set minimum stock levels for each product. When inventory falls below this level, items will be suggested in the shopping list.',
                        style: TextStyle(color: Colors.blue),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: AppConstants.commonCategories.map((category) {
                          final defaultStock = AppConstants.defaultMinimumStock[category] ?? 1;
                          return Chip(
                            label: Text('$category: $defaultStock'),
                            backgroundColor: AppConstants.categoryColors[category]?.withOpacity(0.1),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Products list
              ...products.map((product) => _buildProductRow(product)),
            ],
          );
        },
      ),
    );
  }
}