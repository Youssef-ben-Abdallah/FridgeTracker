import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shopping_item.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late Future<List<ShoppingItem>> _shoppingListFuture;
  List<ShoppingItem> _shoppingItems = [];
  String _searchQuery = '';
  bool _showPurchased = false;
  String? _selectedCategory;
  List<String> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadShoppingList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCategories();
    });
  }

  void _loadShoppingList() {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    _shoppingListFuture = dbService.getShoppingItems(includePurchased: _showPurchased);
  }

  Future<void> _refreshShoppingList() async {
    setState(() {
      _loadShoppingList();
    });
    await _loadCategories();
  }

  Future<void> _generateOutOfStockSuggestions() async {
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final suggestions = await dbService.getLowStockSuggestions();

      if (suggestions.isEmpty) {
        Helpers.showSnackBar(context, 'All products are in stock!');
        return;
      }

      final addedCount = await dbService.addSuggestionsToShoppingList(suggestions);

      if (addedCount > 0) {
        Helpers.showSnackBar(context, 'Added $addedCount ${addedCount == 1 ? 'item' : 'items'} that are out of stock');
        _refreshShoppingList();
      } else {
        Helpers.showSnackBar(context, 'All out-of-stock items already in shopping list');
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Error generating suggestions: $e', isError: true);
    }
  }

  Future<void> _togglePurchasedStatus(ShoppingItem item) async {
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      if (item.isPurchased) {
        await dbService.markAsNotPurchased(item.id!);
        Helpers.showSnackBar(context, '${item.name} marked as not purchased');
      } else {
        await dbService.markAsPurchased(item.id!);
        Helpers.showSnackBar(context, '${item.name} marked as purchased');
      }

      _refreshShoppingList();
    } catch (e) {
      Helpers.showSnackBar(context, 'Error updating item: $e', isError: true);
    }
  }

  Future<void> _deleteItem(ShoppingItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: Text('Remove ${item.name} from shopping list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      await dbService.deleteShoppingItem(item.id!);
      _refreshShoppingList();
      Helpers.showSnackBar(context, '${item.name} removed', isError: true);
    }
  }

  Future<void> _loadCategories() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final shoppingItems = await dbService.getShoppingItems(includePurchased: _showPurchased);
    final categories = shoppingItems.map((item) => item.category).toSet().toList();
    categories.sort();

    setState(() {
      _categories = categories;
    });
  }

  Future<void> _updateQuantity(ShoppingItem item, int newQuantity) async {
    if (newQuantity <= 0) {
      await _deleteItem(item);
      return;
    }

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final updatedItem = item.copyWith(quantityNeeded: newQuantity);
      await dbService.updateShoppingItem(updatedItem);
      _refreshShoppingList();
    } catch (e) {
      Helpers.showSnackBar(context, 'Error updating quantity: $e', isError: true);
    }
  }

  Future<void> _generateLowStockSuggestions() async {
    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final suggestions = await dbService.getLowStockSuggestions();

      if (suggestions.isEmpty) {
        Helpers.showSnackBar(context, 'No low stock items found');
        return;
      }

      final addedCount = await dbService.addSuggestionsToShoppingList(suggestions);

      if (addedCount > 0) {
        Helpers.showSnackBar(context, 'Added ${addedCount == 1 ? ' suggestion' : ' suggestions'} from low stock items');
        _refreshShoppingList();
      } else {
        Helpers.showSnackBar(context, 'All suggestions already in shopping list');
      }
    } catch (e) {
      Helpers.showSnackBar(context, 'Error generating suggestions: $e', isError: true);
    }
  }

  Future<void> _showAddItemDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController quantityController = TextEditingController(text: '1');
    final TextEditingController categoryController = TextEditingController();
    String? selectedCategory;
    int selectedPriority = 1;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Item to Shopping List'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name',
                      hintText: 'e.g., Milk, Bread, Eggs',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      hintText: 'e.g., 2',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      hintText: 'Select category',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('Select category'),
                      ),
                      ...AppConstants.commonCategories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isEmpty) {
                    Helpers.showSnackBar(context, 'Please enter item name', isError: true);
                    return;
                  }

                  final dbService = Provider.of<DatabaseService>(context, listen: false);
                  final item = ShoppingItem(
                    name: nameController.text,
                    category: selectedCategory ?? 'Other',
                    quantityNeeded: int.tryParse(quantityController.text) ?? 1,
                    priority: selectedPriority,
                    addedAt: DateTime.now().millisecondsSinceEpoch,
                    suggestedBy: 'manual',
                  );

                  await dbService.insertShoppingItem(item);
                  Navigator.pop(context);
                  _refreshShoppingList();
                  Helpers.showSnackBar(context, '${item.name} added to shopping list');
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShoppingItem(ShoppingItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: InkWell(
        onTap: () => _showItemDetails(item),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Checkbox for purchased status
              Checkbox(
                value: item.isPurchased,
                onChanged: (value) => _togglePurchasedStatus(item),
                activeColor: Colors.green,
              ),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 8),
                        // Item name
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              decoration: item.isPurchased
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: item.isPurchased ? Colors.grey : Colors.black,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Quantity and category
                    Row(
                      children: [
                        // Quantity
                        GestureDetector(
                          onTap: () => _showQuantityDialog(item),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${item.quantityNeeded} ${item.unit ?? 'pcs'}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.edit, size: 10, color: Colors.blue),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Category
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppConstants.categoryColors[item.category]?.withOpacity(0.1) ?? Colors.grey.shade100,
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

                        // Suggested by badge
                        if (item.suggestedBy != null && item.suggestedBy != 'manual')
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.shade100),
                              ),
                              child: Text(
                                _getSuggestionBadge(item.suggestedBy!),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Actions
              Column(
                children: [
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 0,
                        child: Text('Remove Item', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                    onSelected: (value) {
                      _deleteItem(item);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getSuggestionBadge(String suggestedBy) {
    switch (suggestedBy) {
      case 'low_stock':
        return 'Low Stock';
      case 'recipe':
        return 'Recipe';
      case 'expiring_soon':
        return 'Replace Soon';
      default:
        return 'Suggested';
    }
  }

  Future<void> _showQuantityDialog(ShoppingItem item) async {
    final TextEditingController quantityController = TextEditingController(
      text: item.quantityNeeded.toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Quantity'),
        content: TextField(
          controller: quantityController,
          decoration: const InputDecoration(
            labelText: 'Quantity',
            hintText: 'Enter quantity',
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newQuantity = int.tryParse(quantityController.text);
              if (newQuantity != null && newQuantity > 0) {
                _updateQuantity(item, newQuantity);
                Navigator.pop(context);
              } else {
                Helpers.showSnackBar(context, 'Please enter a valid quantity', isError: true);
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showItemDetails(ShoppingItem item) {
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
              Column(
                children: [
                  Container(
                    alignment: AlignmentDirectional.center,
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
              ListTile(
                leading: const Icon(Icons.numbers),
                title: const Text('Quantity Needed'),
                subtitle: Text('${item.quantityNeeded} ${item.unit ?? 'pcs'}'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pop(context);
                    _showQuantityDialog(item);
                  },
                ),
              ),

              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('Category'),
                subtitle: Text(item.category),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.categoryColors[item.category]?.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(item.category),
                ),
              ),

              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: const Text('Added Date'),
                subtitle: Text(Helpers.formatTimestamp(item.addedAt)),
              ),

              if (item.suggestedBy != null)
                ListTile(
                  leading: const Icon(Icons.lightbulb),
                  title: const Text('Suggested By'),
                  subtitle: Text(_getSuggestionText(item.suggestedBy!)),
                ),

              if (item.notes != null && item.notes!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 12),
                    const Text(
                      'Notes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(item.notes!),
                  ],
                ),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _togglePurchasedStatus(item);
                      },
                      icon: Icon(item.isPurchased ? Icons.shopping_cart_checkout : Icons.shopping_cart),
                      label: Text(item.isPurchased ? 'Mark as Not Purchased' : 'Mark as Purchased'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: item.isPurchased ? Colors.orange : Colors.green,
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

  String _getSuggestionText(String suggestedBy) {
    switch (suggestedBy) {
      case 'low_stock':
        return 'Automatically suggested based on low stock in your pantry';
      case 'recipe':
        return 'Suggested from recipe ingredients';
      case 'manual':
        return 'Manually added by you';
      case 'expiring_soon':
        return 'Suggested to replace expiring items';
      default:
        return suggestedBy;
    }
  }

  List<ShoppingItem> _applyFilters(List<ShoppingItem> items) {
    List<ShoppingItem> filtered = List.from(items);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((item) =>
      item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.category.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item.notes ?? '').toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    // Apply category filter
    if (_selectedCategory != null) {
      filtered = filtered.where((item) => item.category == _selectedCategory).toList();
    }

    return filtered;
  }

  Widget _buildShoppingListByCategory(List<ShoppingItem> items) {
    if (_selectedCategory != null) {
      // If a category is selected, show all items in that category
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _buildShoppingItem(item);
        },
      );
    } else {
      // Group by category
      final Map<String, List<ShoppingItem>> categorized = {};

      for (final item in items) {
        if (!categorized.containsKey(item.category)) {
          categorized[item.category] = [];
        }
        categorized[item.category]!.add(item);
      }

      final categories = categorized.keys.toList()..sort();

      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final category in categories)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category header
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8),
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
                      Text(
                        category,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${categorized[category]!.length}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

                // Items in this category
                ...categorized[category]!.map((item) => _buildShoppingItem(item)),
              ],
            ),
        ],
      );
    }
  }

  Widget _buildCategoryHeader(String category, int itemCount) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8, left: 8),
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
          Text(
            category,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$itemCount',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshShoppingList,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _generateOutOfStockSuggestions,
            tooltip: 'Add Out-of-Stock Items',
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

                const SizedBox(height: 12),

                // Filters
                Row(
                  children: [
                    // Priority filter
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
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
                    ),

                    const SizedBox(width: 12),

                    // Show purchased toggle
                    FilterChip(
                      label: Text(_showPurchased ? 'Hide Purchased' : 'Show Purchased'),
                      selected: _showPurchased,
                      onSelected: (selected) {
                        setState(() {
                          _showPurchased = selected;
                          _refreshShoppingList();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Shopping list
          Expanded(
            child: FutureBuilder<List<ShoppingItem>>(
              future: _shoppingListFuture,
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
                          'Error loading shopping list',
                          style: TextStyle(fontSize: 18, color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _refreshShoppingList,
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  );
                }

                final items = snapshot.data ?? [];
                final filteredItems = _applyFilters(items);

                if (filteredItems.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Your shopping list is empty',
                          style: TextStyle(fontSize: 20, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Add items manually or generate suggestions',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _generateLowStockSuggestions,
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('Generate Low Stock Suggestions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Group by purchased status
                final purchasedItems = filteredItems.where((item) => item.isPurchased).toList();
                final activeItems = filteredItems.where((item) => !item.isPurchased).toList();

                return RefreshIndicator(
                  onRefresh: _refreshShoppingList,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Active items
                      if (activeItems.isNotEmpty) ...[
                        if (purchasedItems.isNotEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8, bottom: 4),
                            child: Text(
                              'To Buy',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                          ),

                        ...activeItems.map((item) => _buildShoppingItem(item)),
                      ],

                      // Purchased items
                      if (purchasedItems.isNotEmpty && _showPurchased) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 16, bottom: 4),
                          child: Text(
                            'Purchased',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),

                        ...purchasedItems.map((item) => _buildShoppingItem(item)),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Item'),
        tooltip: 'Add item to shopping list',
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}