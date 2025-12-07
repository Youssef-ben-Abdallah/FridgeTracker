import 'package:flutter/material.dart';
import 'package:fridgetracker/screens/products_screen.dart';
import 'package:fridgetracker/screens/scan_product_screen.dart';
import 'package:provider/provider.dart';

import '../models/inventory_item.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/expiration_indicator.dart';
import 'add_inventory_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late Future<List<InventoryItem>> _inventoryFuture;
  List<InventoryItem> _filteredItems = [];
  String _selectedFilter = 'all';
  String _searchQuery = '';

  final List<Map<String, dynamic>> _filterOptions = [
    {'value': 'all', 'label': 'All Items'},
    {'value': 'expiring', 'label': 'Expiring Soon'},
    {'value': 'expired', 'label': 'Expired'},
    {'value': 'category', 'label': 'By Category'},
  ];

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  void _loadInventory() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    _inventoryFuture = dbService.getInventoryItems();
  }

  Future<void> _refreshInventory() async {
    setState(() {
      _loadInventory();
    });
  }

  Future<void> _markAsConsumed(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark as Consumed'),
        content: Text('Mark ${item.name} as consumed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Mark'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.markAsConsumed(item.id!);
      _refreshInventory();
      Helpers.showSnackBar(context, '${item.name} marked as consumed');
    }
  }

  Future<void> _deleteItem(InventoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Are you sure you want to delete ${item.name} from your pantry?'),
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
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.deleteInventoryItem(item.id!);
      _refreshInventory();
      Helpers.showSnackBar(context, '${item.name} deleted', isError: true);
    }
  }

  void _showItemDetails(InventoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ExpirationIndicator(daysUntilExpiry: item.daysUntilExpiry),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Category
              Row(
                children: [
                  Icon(Icons.category, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Text(
                    item.category,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppConstants.categoryColors[item.category] ?? Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      item.category,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quantity
              Row(
                children: [
                  Icon(Icons.format_list_numbered, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Text(
                    'Quantity: ${item.quantity} ${item.unit ?? ''}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Added Date
              Row(
                children: [
                  Icon(Icons.calendar_today, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Added Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(item.formattedAddedDate, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Expiry Date
              Row(
                children: [
                  Icon(Icons.event_busy, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Expiry Date', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(item.formattedExpiryDate, style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Status
              Row(
                children: [
                  Icon(
                    item.isExpired ? Icons.error : Icons.warning,
                    color: item.isExpired ? Colors.red : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.expiryMessage,
                      style: TextStyle(
                        fontSize: 16,
                        color: item.isExpired ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  'Notes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(item.notes!),
              ],

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _markAsConsumed(item);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Mark as Consumed'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyFilters(List<InventoryItem> items) {
    List<InventoryItem> filtered = List.from(items);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) =>
      item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item.notes ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Apply status filter
    switch (_selectedFilter) {
      case 'expiring':
        filtered = filtered.where((item) => item.isExpiringSoon).toList();
        break;
      case 'expired':
        filtered = filtered.where((item) => item.isExpired).toList();
        break;
      case 'category':
      // Group by category
        _showCategoryFilter(filtered);
        return;
    }

    _filteredItems = filtered;
  }

  void _showCategoryFilter(List<InventoryItem> items) {
    final categories = items.map((item) => item.category).toSet().toList();
    categories.sort();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Category'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final count = items.where((item) => item.category == category).length;

              return ListTile(
                leading: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppConstants.categoryColors[category] ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(category),
                trailing: Text('$count items'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _filteredItems = items
                        .where((item) => item.category == category)
                        .toList();
                    _selectedFilter = 'category:$category';
                  });
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    return FilterChip(
      label: Text(label),
      selected: _selectedFilter == value,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = selected ? value : 'all';
        });
      },
      selectedColor: AppConstants.primaryColor.withOpacity(0.2),
      checkmarkColor: AppConstants.primaryColor,
    );
  }

  Widget _buildInventoryItem(InventoryItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: InkWell(
        onTap: () => _showItemDetails(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Expiration indicator
              ExpirationIndicator(daysUntilExpiry: item.daysUntilExpiry),
              const SizedBox(width: 12),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppConstants.categoryColors[item.category]?.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.category,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppConstants.categoryColors[item.category] ?? Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.quantity} ${item.unit ?? ''}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Expiry info and actions
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    item.formattedExpiryDate,
                    style: TextStyle(
                      fontSize: 12,
                      color: item.isExpired ? Colors.red : Colors.grey,
                      fontWeight: item.isExpiringSoon ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, size: 20),
                        color: Colors.green,
                        onPressed: () => _markAsConsumed(item),
                        tooltip: 'Mark as consumed',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 20),
                        color: Colors.red,
                        onPressed: () => _deleteItem(item),
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pantry'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshInventory,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search items...',
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
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: _filterOptions.map((option) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildFilterChip(
                    option['value'],
                    option['label'],
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          // Inventory list
          Expanded(
            child: FutureBuilder<List<InventoryItem>>(
              future: _inventoryFuture,
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
                          'Error loading inventory',
                          style: TextStyle(fontSize: 18, color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _refreshInventory,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
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
                          'No items in pantry',
                          style: TextStyle(fontSize: 20, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add items by scanning barcodes',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                // Apply filters
                _applyFilters(items);

                return RefreshIndicator(
                  onRefresh: _refreshInventory,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return _buildInventoryItem(item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddInventoryDialog();
        },
        backgroundColor: AppConstants.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddInventoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add to Inventory'),
        content: const Text('How would you like to add an item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToProductSelection();
            },
            child: const Text('Select from Products'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToScanScreen();
            },
            child: const Text('Scan Barcode'),
          ),
        ],
      ),
    );
  }

  void _navigateToProductSelection() async {
    final selectedProduct = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductsScreen(
          //isSelectionMode: true,
        ),
      ),
    );

    if (selectedProduct != null && selectedProduct is Product) {
      // Navigate to add inventory screen
      final added = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddInventoryScreen(product: selectedProduct),
        ),
      );

      if (added == true) {
        _refreshInventory();
      }
    }
  }

  void _navigateToScanScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanProductScreen(),
      ),
    ).then((_) {
      // Refresh inventory when returning
      _refreshInventory();
    });
  }
}