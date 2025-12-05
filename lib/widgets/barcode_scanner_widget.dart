import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';


import '../services/ml_kit_service.dart';

class BarcodeScannerWidget extends StatefulWidget {
  final ValueChanged<String> onBarcodeScanned;
  final Widget? overlay;
  final String? instructions;

  const BarcodeScannerWidget({
    super.key,
    required this.onBarcodeScanned,
    this.overlay,
    this.instructions,
  });

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  CameraController? _cameraController;
  final MLKitService _mlKitService = MLKitService();
  bool _isInitializing = true;
  bool _isScanning = false;
  bool _hasError = false;
  StreamSubscription? _barcodeSubscription;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        setState(() {
          _hasError = true;
          _isInitializing = false;
        });
        return;
      }

      // Prefer back camera
      CameraDescription? selectedCamera;
      for (var camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selectedCamera = camera;
          break;
        }
      }

      selectedCamera ??= cameras.first;

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }

      // Start continuous scanning
      _startContinuousScanning();

    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isInitializing = false;
        });
      }
    }
  }

  void _startContinuousScanning() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    // Process frames every 2 seconds
    Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_isScanning || !mounted) return;

      try {
        setState(() {
          _isScanning = true;
        });

        final image = await _cameraController!.takePicture();
        final imageFile = File(image.path); // Convert XFile to File

        final barcode = await _mlKitService.scanBarcodeFromImage(imageFile);

        if (barcode != null && mounted) {
          widget.onBarcodeScanned(barcode);
          // Stop scanning after successful detection
          timer.cancel();
        }
      } catch (e) {
        print('Error during scanning: $e');
      } finally {
        if (mounted) {
          setState(() {
            _isScanning = false;
          });
        }
      }
    });
  }

  Future<void> _manualCapture() async {
    if (_isScanning || _cameraController == null) return;

    try {
      setState(() {
        _isScanning = true;
      });

      final image = await _cameraController!.takePicture();
      final imageFile = File(image.path); // Convert XFile to File

      final barcode = await _mlKitService.scanBarcodeFromImage(imageFile);

      if (barcode != null && mounted) {
        widget.onBarcodeScanned(barcode);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No barcode detected')),
          );
        }
      }
    } catch (e) {
      print('Error capturing barcode: $e');
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

  Widget _buildScannerOverlay() {
    return Center(
      child: Container(
        width: 250,
        height: 150,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.green, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            // Corners
            Positioned(
              top: 0,
              left: 0,
              child: _buildCorner(Alignment.topLeft),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: _buildCorner(Alignment.topRight),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              child: _buildCorner(Alignment.bottomLeft),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: _buildCorner(Alignment.bottomRight),
            ),

            // Scanning line
            if (_isScanning)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.withOpacity(0), Colors.green, Colors.green.withOpacity(0)],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCorner(Alignment alignment) {
    return Container(
      width: 20,
      height: 20,
      alignment: alignment,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: Colors.green,
              width: alignment == Alignment.topLeft || alignment == Alignment.bottomLeft ? 3 : 0,
            ),
            top: BorderSide(
              color: Colors.green,
              width: alignment == Alignment.topLeft || alignment == Alignment.topRight ? 3 : 0,
            ),
            right: BorderSide(
              color: Colors.green,
              width: alignment == Alignment.topRight || alignment == Alignment.bottomRight ? 3 : 0,
            ),
            bottom: BorderSide(
              color: Colors.green,
              width: alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight ? 3 : 0,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _barcodeSubscription?.cancel();
    _cameraController?.dispose();
    _mlKitService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon( Icons.broken_image, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Camera Error',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unable to access camera',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing camera...'),
          ],
        ),
      );
    }

    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_cameraController!),

        // Scanner overlay
        _buildScannerOverlay(),

        // Instructions
        Positioned(
          top: 50,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.instructions ?? 'Align barcode within the frame',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ),

        // Manual capture button
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Center(
            child: FloatingActionButton.extended(
              onPressed: _isScanning ? null : _manualCapture,
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: _isScanning
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: Colors.white),
              )
                  : const Icon(Icons.camera),
              label: Text(_isScanning ? 'Scanning...' : 'Scan'),
            ),
          ),
        ),

        // Loading indicator when scanning
        if (_isScanning)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),

        // Custom overlay if provided
        if (widget.overlay != null) widget.overlay!,
      ],
    );
  }
}