import 'package:flutter/material.dart';
import 'package:provider/provider.dart';


import '../models/product.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';

class AddProductScreen extends StatefulWidget {
  final String? initialBarcode;
  final Product? initialProduct;

  const AddProductScreen({
    super.key,
    this.initialBarcode,
    this.initialProduct,
  });

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController();
  final _expirationController = TextEditingController();

  String? _selectedCategory;
  bool _isSubmitting = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();

    if (widget.initialProduct != null) {
      _isEditing = true;
      final product = widget.initialProduct!;
      _nameController.text = product.name;
      _barcodeController.text = product.barcode;
      _categoryController.text = product.category;
      _selectedCategory = product.category;
      if (product.defaultExpirationDays != null) {
        _expirationController.text = product.defaultExpirationDays.toString();
      }
    } else if (widget.initialBarcode != null) {
      _barcodeController.text = widget.initialBarcode!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _expirationController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      final product = Product(
        barcode: _barcodeController.text.trim(),
        name: _nameController.text.trim(),
        category: _selectedCategory ?? _categoryController.text.trim(),
        defaultExpirationDays: int.tryParse(_expirationController.text.trim()),
      );

      if (_isEditing) {
        await dbService.updateProduct(product);
      } else {
        await dbService.insertProduct(product);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? 'Product updated' : 'Product added'),
          ),
        );
        Navigator.pop(context, product);
      }
    } catch (e) {
      print('Error saving product: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save product')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Barcode
              TextFormField(
                controller: _barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Barcode',
                  prefixIcon: Icon(Icons.qr_code),
                  hintText: 'Scan or enter barcode',
                ),
                readOnly: _isEditing, // Can't edit barcode when editing
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a barcode';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Product Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  prefixIcon: Icon(Icons.shopping_bag),
                  hintText: 'e.g., Milk, Bread, Eggs',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a product name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Select category'),
                  ),
                  ...AppConstants.commonCategories.map((category) {
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
                          const SizedBox(width: 12),
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),

              // Alternative category input
              if (_selectedCategory == null || _selectedCategory == 'Select category')
                Column(
                  children: [
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Or enter custom category',
                        prefixIcon: Icon(Icons.edit),
                        hintText: 'e.g., Dairy, Meat, Produce',
                      ),
                      validator: (value) {
                        if ((_selectedCategory == null || _selectedCategory!.isEmpty) &&
                            (value == null || value.isEmpty)) {
                          return 'Please enter a category';
                        }
                        return null;
                      },
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // Default Expiration
              TextFormField(
                controller: _expirationController,
                decoration: const InputDecoration(
                  labelText: 'Default Expiration (days)',
                  prefixIcon: Icon(Icons.calendar_today),
                  hintText: 'e.g., 7 for 1 week',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final days = int.tryParse(value);
                    if (days == null || days <= 0) {
                      return 'Please enter a valid number';
                    }
                  }
                  return null;
                },
              ),


              // Category-based suggestion
              if (_selectedCategory != null &&
                  AppConstants.defaultExpirationDays.containsKey(_selectedCategory))
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Suggested: ${AppConstants.defaultExpirationDays[_selectedCategory]} days',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  child: _isSubmitting
                      ? const CircularProgressIndicator()
                      : Text(_isEditing ? 'Update Product' : 'Add Product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}