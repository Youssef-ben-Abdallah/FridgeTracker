import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../models/shopping_item.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'add_product_screen.dart';

class ProductsScreen extends StatefulWidget {
  final bool isSelectionMode;
  final Function(Product)? onProductSelected;

  const ProductsScreen({
    super.key,
    this.isSelectionMode = false,
    this.onProductSelected,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late Future<List<Product>> _productsFuture;
  List<Product> _filteredProducts = [];
  String _searchQuery = '';
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  void _loadProducts() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    _productsFuture = dbService.getAllProducts();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final products = await dbService.getAllProducts();
    final categories = products.map((p) => p.category).toSet().toList();
    categories.sort();

    setState(() {
      _categories = categories;
    });
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _loadProducts();
    });
  }

  void _showProductOptions(Product product) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text('Edit Product'),
            onTap: () {
              Navigator.pop(context);
              _editProduct(product);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Product'),
            onTap: () {
              Navigator.pop(context);
              _deleteProduct(product);
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _editProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(initialProduct: product),
      ),
    ).then((_) {
      _refreshProducts();
    });
  }


  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product.name}"? This will also remove all inventory items for this product.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final dbService = Provider.of<DatabaseService>(context, listen: false);
        await dbService.deleteProduct(product.barcode);
        _refreshProducts();
        Helpers.showSnackBar(context, '${product.name} deleted', isError: true);
      } catch (e) {
        Helpers.showSnackBar(context, 'Error deleting product: $e', isError: true);
      }
    }
  }

  void _showAddProductDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Product'),
        content: const Text('How would you like to add a product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AddProductScreen(),
                ),
              ).then((_) => _refreshProducts());
            },
            child: const Text('Manually'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to scan screen
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => const ScanProductScreen(),
              //   ),
              // );
            },
            child: const Text('Scan Barcode'),
          ),
        ],
      ),
    );
  }

  void _applyFilters(List<Product> products) {
    List<Product> filtered = List.from(products);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((product) =>
      product.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          product.barcode.contains(_searchQuery)
      ).toList();
    }

    // Apply category filter
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered.where((product) => product.category == _selectedCategory).toList();
    }

    _filteredProducts = filtered;
  }

  Future<void> _addToShoppingList(Product product) async {
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      // Check if already in shopping list
      final shoppingItems = await dbService.getShoppingItems();
      final alreadyInList = shoppingItems.any((item) => item.productId == product.barcode && !item.isPurchased);

      if (alreadyInList) {
        Helpers.showSnackBar(context, '${product.name} is already in your shopping list');
        return;
      }

      final shoppingItem = ShoppingItem(
        productId: product.barcode,
        name: product.name,
        category: product.category,
        quantityNeeded: 1,
        unit: 'pcs',
        priority: 2,
        addedAt: DateTime.now().millisecondsSinceEpoch,
        suggestedBy: 'manual',
      );

      await dbService.insertShoppingItem(shoppingItem);
      Helpers.showSnackBar(context, '${product.name} added to shopping list');
    } catch (e) {
      Helpers.showSnackBar(context, 'Error: $e', isError: true);
    }
  }

  void _addNewProductForInventory() async {
    final newProduct = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddProductScreen(),
      ),
    );

    if (newProduct != null && newProduct is Product) {
      // Return the new product to the inventory screen
      if (widget.isSelectionMode && widget.onProductSelected != null) {
        widget.onProductSelected!(newProduct);
        Navigator.pop(context, newProduct);
      }
    }
  }

  Widget _buildProductCard(Product product) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          if (widget.isSelectionMode && widget.onProductSelected != null) {
            widget.onProductSelected!(product);
            Navigator.pop(context, product);
          } else {
            _showProductOptions(product);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Product icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppConstants.categoryColors[product.category]?.withOpacity(0.2) ?? Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getCategoryIcon(product.category),
                  color: AppConstants.categoryColors[product.category] ?? Colors.grey,
                ),
              ),

              const SizedBox(width: 12),

              // Product details
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Category badge
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

                        // Barcode
                        Text(
                          product.barcode,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),

                    // Expiration and stock info
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (product.defaultExpirationDays != null)
                          Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                '${product.defaultExpirationDays} days',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(width: 12),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Show selection button or options button
              if (widget.isSelectionMode)
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.green),
                  onPressed: () {
                    if (widget.onProductSelected != null) {
                      widget.onProductSelected!(product);
                      Navigator.pop(context, product);
                    }
                  },
                  tooltip: 'Select product',
                )
              else
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: () => _showProductOptions(product),
                  tooltip: 'Options',
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'dairy':
        return Icons.agriculture;
      case 'meat':
        return Icons.set_meal;
      case 'produce':
        return Icons.spa;
      case 'bakery':
        return Icons.bakery_dining;
      case 'canned':
        return Icons.inventory;
      case 'frozen':
        return Icons.ac_unit;
      case 'beverages':
        return Icons.local_drink;
      case 'snacks':
        return Icons.cookie;
      case 'condiments':
        return Icons.emoji_food_beverage;
      default:
        return Icons.shopping_bag;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProducts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filter bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),

                const SizedBox(height: 12),

                // Category filter
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Category',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    ..._categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppConstants.categoryColors[category] ?? Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(category),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
              ],
            ),
          ),

          // Products list
          Expanded(
            child: FutureBuilder<List<Product>>(
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
                          onPressed: _refreshProducts,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  );
                }

                final products = snapshot.data ?? [];
                _applyFilters(products);

                if (_filteredProducts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_bag,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No products found',
                          style: TextStyle(fontSize: 20, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        if (_searchQuery.isNotEmpty || _selectedCategory != null)
                          Text(
                            'Try changing your search or filter',
                            style: TextStyle(color: Colors.grey[600]),
                          )
                        else
                          const Text(
                            'Add your first product to get started',
                            style: TextStyle(color: Colors.grey),
                          ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: widget.isSelectionMode
                              ? _addNewProductForInventory
                              : _showAddProductDialog,
                          icon: const Icon(Icons.add),
                          label: Text(widget.isSelectionMode ? 'Add New Product' : 'Add Product'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _refreshProducts,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = _filteredProducts[index];
                      return _buildProductCard(product);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.isSelectionMode
          ? null // Don't show FAB in selection mode
          : FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        tooltip: 'Add new product',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}