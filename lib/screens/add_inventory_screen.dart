import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/inventory_item.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../utils/constants.dart';
import 'package:provider/provider.dart';

class AddInventoryScreen extends StatefulWidget {
  final Product product;
  final DateTime? initialExpiryDate;

  const AddInventoryScreen({
    super.key,
    required this.product,
    this.initialExpiryDate,
  });

  @override
  State<AddInventoryScreen> createState() => _AddInventoryScreenState();
}

class _AddInventoryScreenState extends State<AddInventoryScreen> {
  final _formKey = GlobalKey<FormState>();

  final _quantityController = TextEditingController(text: '1');
  final _unitController = TextEditingController(text: 'pcs');
  final _notesController = TextEditingController();

  DateTime? _expiryDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Set default expiry date based on product
    _expiryDate = widget.initialExpiryDate ??
        widget.product.getExpiryDate(addedDate: DateTime.now());
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expiry date')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);

      final inventoryItem = InventoryItem(
        barcode: widget.product.barcode,
        name: widget.product.name,
        category: widget.product.category,
        quantity: int.parse(_quantityController.text),
        unit: _unitController.text.isNotEmpty ? _unitController.text : null,
        addedAt: DateTime.now().millisecondsSinceEpoch,
        expiryAt: _expiryDate!.millisecondsSinceEpoch,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        isConsumed: false,
      );

      await dbService.insertInventoryItem(inventoryItem);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.product.name} added to inventory'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return success
      }
    } catch (e) {
      print('Error saving inventory item: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add to inventory')),
        );
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
        title: const Text('Add to Inventory'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product info card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppConstants.categoryColors[widget.product.category]?.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.shopping_bag,
                          color: AppConstants.categoryColors[widget.product.category],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.product.name,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppConstants.categoryColors[widget.product.category]?.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    widget.product.category,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppConstants.categoryColors[widget.product.category],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.product.barcode,
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Quantity
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  prefixIcon: Icon(Icons.format_list_numbered),
                  hintText: 'Enter quantity',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Unit
              TextFormField(
                controller: _unitController,
                decoration: const InputDecoration(
                  labelText: 'Unit (optional)',
                  prefixIcon: Icon(Icons.linear_scale),
                  hintText: 'e.g., pcs, kg, ml, lbs',
                ),
              ),

              const SizedBox(height: 16),

              // Expiry Date
              InkWell(
                onTap: _selectExpiryDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Expiry Date',
                    prefixIcon: Icon(Icons.calendar_today),
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _expiryDate != null
                            ? DateFormat('MMM dd, yyyy').format(_expiryDate!)
                            : 'Select date',
                        style: TextStyle(
                          color: _expiryDate != null ? Colors.black87 : Colors.grey,
                        ),
                      ),
                      const Icon(Icons.calendar_month, color: Colors.grey),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Suggested expiry: ${DateFormat('MMM dd, yyyy').format(widget.product.getExpiryDate())}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),

              const SizedBox(height: 16),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.note),
                  hintText: 'Add any notes...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),

              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Add to Inventory',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}