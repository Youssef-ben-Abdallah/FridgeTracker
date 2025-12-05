import 'dart:io';
import 'package:flutter/material.dart';

import 'package:intl/intl.dart';


import '../models/inventory_item.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/ml_kit_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class ExpirationOcrScreen extends StatefulWidget {
  final Product product;

  const ExpirationOcrScreen({super.key, required this.product});

  @override
  State<ExpirationOcrScreen> createState() => _ExpirationOcrScreenState();
}

class _ExpirationOcrScreenState extends State<ExpirationOcrScreen> {
  final MLKitService _mlKitService = MLKitService();
  File? _selectedImage;
  DateTime? _expiryDate;
  bool _isProcessing = false;
  bool _useDefaultExpiry = true;
  int _quantity = 1;
  String? _unit;
  String? _notes;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    // Set default expiry date
    _expiryDate = widget.product.getExpiryDate();
    _dateController.text = _formatDate(_expiryDate!);
  }

  Future<void> _pickImage() async {
    final image = await _mlKitService.pickImageFromCamera();
    if (image != null && mounted) {
      setState(() {
        _selectedImage = image;
      });
      await _extractExpiryDate(image);
    }
  }

  Future<void> _extractExpiryDate(File image) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final extractedDate = await _mlKitService.extractExpirationDate(image);

      if (extractedDate != null && mounted) {
        setState(() {
          _expiryDate = extractedDate;
          _dateController.text = _formatDate(extractedDate);
          _useDefaultExpiry = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expiration date extracted successfully')),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not extract date. Please enter manually.')),
          );
        }
      }
    } catch (e) {
      print('Error extracting date: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error processing image')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final initialDate = _expiryDate ?? DateTime.now().add(const Duration(days: 7));
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );

    if (selectedDate != null && mounted) {
      setState(() {
        _expiryDate = selectedDate;
        _dateController.text = _formatDate(selectedDate);
        _useDefaultExpiry = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Future<void> _saveToInventory() async {
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set an expiration date')),
      );
      return;
    }

    try {
      final dbService = DatabaseService();
      final notificationService = NotificationService();

      final inventoryItem = InventoryItem(
        barcode: widget.product.barcode,
        name: widget.product.name,
        category: widget.product.category,
        quantity: _quantity,
        unit: _unit,
        addedAt: DateTime.now().millisecondsSinceEpoch,
        expiryAt: _expiryDate!.millisecondsSinceEpoch,
        photoPath: _selectedImage?.path,
        notes: _notes,
      );

      final id = await dbService.insertInventoryItem(inventoryItem);
      inventoryItem.id = id;

      // Schedule notifications
      await notificationService.scheduleExpirationNotification(inventoryItem);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      print('Error saving to inventory: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error saving item')),
        );
      }
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Expiration Date'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product info
            Card(
              child: ListTile(
                leading: const Icon(Icons.shopping_bag, size: 40),
                title: Text(
                  widget.product.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Category: ${widget.product.category}'),
                    Text('Barcode: ${widget.product.barcode}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Image capture section
            const Text(
              'Capture Expiration Date',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take a photo of the expiration date on the package',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),

            if (_selectedImage != null)
              Column(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      image: DecorationImage(
                        image: FileImage(_selectedImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            ElevatedButton.icon(
              onPressed: _isProcessing ? null : _pickImage,
              icon: _isProcessing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(),
              )
                  : const Icon(Icons.camera_alt),
              label: Text(_isProcessing ? 'Processing...' : 'Take Photo'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 24),

            // Manual date selection
            const Text(
              'Expiration Date',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Expiry Date',
                      prefixIcon: const Icon(Icons.calendar_today),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _selectDate(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Tooltip(
                  message: 'Use default expiration (${widget.product.defaultExpirationDays ?? AppConstants.defaultExpirationDays[widget.product.category] ?? 7} days)',
                  child: Switch(
                    value: _useDefaultExpiry,
                    onChanged: (value) {
                      setState(() {
                        _useDefaultExpiry = value;
                        if (value) {
                          _expiryDate = widget.product.getExpiryDate();
                          _dateController.text = _formatDate(_expiryDate!);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quantity
            const Text(
              'Quantity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                    onChanged: (value) {
                      _quantity = int.tryParse(value) ?? 1;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _unit,
                  hint: const Text('Unit'),
                  items: AppConstants.units.map((unit) {
                    return DropdownMenuItem(
                      value: unit,
                      child: Text(unit),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _unit = value;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Notes
            TextFormField(
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 3,
              onChanged: (value) {
                _notes = value;
              },
            ),
            const SizedBox(height: 32),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveToInventory,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text(
                  'Add to Pantry',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}