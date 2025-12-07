import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../services/database_service.dart';
import '../services/ml_kit_service.dart';
import 'add_product_screen.dart';
import 'expiration_ocr_screen.dart';
import 'dart:io';

class ScanProductScreen extends StatefulWidget {
  const ScanProductScreen({super.key});

  @override
  State<ScanProductScreen> createState() => _ScanProductScreenState();
}

class _ScanProductScreenState extends State<ScanProductScreen> {
  CameraController? _cameraController;
  final MLKitService _mlKitService = MLKitService();
  bool _isScanning = false;
  String? _scannedBarcode;
  Product? _scannedProduct;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final camera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        _showCameraErrorDialog();
      }
    }
  }

  void _showCameraErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Error'),
        content: const Text('Unable to initialize camera. Please check permissions.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _scanBarcode() async {
    if (_isScanning || _cameraController == null) return;

    setState(() {
      _isScanning = true;
    });

    try {
      // Then in your method:
      final image = await _cameraController!.takePicture();
      final imageFile = File(image.path); // Convert XFile to File

      final barcode = await _mlKitService.scanBarcodeFromImage(imageFile);

      if (barcode != null && mounted) {
        setState(() {
          _scannedBarcode = barcode;
        });
        await _fetchProductDetails(barcode);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No barcode detected. Try again.')),
          );
        }
      }
    } catch (e) {
      print('Error scanning barcode: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error scanning barcode')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _fetchProductDetails(String barcode) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final dbService = Provider.of<DatabaseService>(context, listen: false);
      final product = await dbService.getProductByBarcode(barcode);

      if (mounted) {
        setState(() {
          _scannedProduct = product;
          _isLoading = false;
        });

        if (product != null) {
          _showProductFoundDialog(product);
        } else {
          _showProductNotFoundDialog(barcode);
        }
      }
    } catch (e) {
      print('Error fetching product: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showProductNotFoundDialog(barcode);
      }
    }
  }

  void _showProductFoundDialog(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shopping_bag, color: Colors.green),
              title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(product.category),
            ),
            if (product.defaultExpirationDays != null)
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: Text('Default expiration: ${product.defaultExpirationDays} days'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addToInventory(product);
            },
            child: const Text('Add to Inventory'),
          ),
        ],
      ),
    );
  }

  void _showProductNotFoundDialog(String barcode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Text('Product with barcode $barcode was not found in your database.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Try Again'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToAddProduct(barcode);
            },
            child: const Text('Add New Product'),
          ),
        ],
      ),
    );
  }

  void _addToInventory(Product product) async {
    // Navigate to expiration OCR screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExpirationOcrScreen(product: product),
      ),
    );

    if (result == true && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} added to inventory')),
      );
    }
  }

  void _navigateToAddProduct(String barcode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(initialBarcode: barcode),
      ),
    ).then((_) {
      // Refresh camera view when returning
      if (mounted) {
        setState(() {
          _scannedBarcode = null;
          _scannedProduct = null;
        });
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _mlKitService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Product')
      ),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing camera...'),
          ],
        ),
      )
          : Stack(
        children: [
          CameraPreview(_cameraController!),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green, width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton.extended(
                onPressed: _isScanning ? null : _scanBarcode,
                backgroundColor: Colors.green,
                icon: _isScanning
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.camera),
                label: Text(_isScanning ? 'Scanning...' : 'Scan'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}