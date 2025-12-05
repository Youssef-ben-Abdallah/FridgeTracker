import 'dart:io';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class MLKitService {
  final BarcodeScanner barcodeScanner = BarcodeScanner();
  final TextRecognizer textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String?> scanBarcodeFromImage(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final List<Barcode> barcodes = await barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        // Return the first barcode found
        return barcodes.first.displayValue;
      }
      return null;
    } catch (e) {
      print('Error scanning barcode: $e');
      return null;
    }
  }

  Future<DateTime?> extractExpirationDate(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      final text = recognizedText.text.toLowerCase();

      // Common date patterns found on food packages
      final patterns = [
        // Expiry date patterns
        RegExp(r'exp.*?(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})', caseSensitive: false),
        RegExp(r'use by.*?(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})', caseSensitive: false),
        RegExp(r'best before.*?(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})', caseSensitive: false),
        RegExp(r'use until.*?(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})', caseSensitive: false),
        RegExp(r'consume by.*?(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})', caseSensitive: false),

        // French patterns (for Tunisia)
        RegExp(r'à consommer avant.*?(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})', caseSensitive: false),
        RegExp(r'date de péremption.*?(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})', caseSensitive: false),

        // Arabic patterns (for Tunisia)
        RegExp(r'تاريخ االنتهاء.*?(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})', caseSensitive: false),
        RegExp(r'يستهلك قبل.*?(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})', caseSensitive: false),

        // Simple date patterns
        RegExp(r'(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})'),
        RegExp(r'(\d{4}[/\-\.]\d{1,2}[/\-\.]\d{1,2})'),
      ];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          final dateString = match.group(1)!;
          final date = _parseDate(dateString);
          if (date != null) return date;
        }
      }

      // Try to find month names
      final monthPatterns = [
        RegExp(r'(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+(\d{2,4})', caseSensitive: false),
        RegExp(r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\s+(\d{1,2})\s+(\d{2,4})', caseSensitive: false),
      ];

      for (final pattern in monthPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          final date = _parseMonthDate(match);
          if (date != null) return date;
        }
      }

      return null;
    } catch (e) {
      print('Error extracting expiration date: $e');
      return null;
    }
  }

  DateTime? _parseDate(String dateString) {
    try {
      // Clean the date string
      String cleaned = dateString.replaceAll(RegExp(r'[^\d\/\-\.]'), '');

      // Try different date formats
      final formats = [
        'dd/MM/yyyy',
        'dd-MM-yyyy',
        'dd.MM.yyyy',
        'MM/dd/yyyy',
        'MM-dd-yyyy',
        'MM.dd.yyyy',
        'yyyy/MM/dd',
        'yyyy-MM-dd',
        'yyyy.MM.dd',
        'dd/MM/yy',
        'dd-MM-yy',
        'dd.MM.yy',
      ];

      for (final format in formats) {
        try {
          final parts = cleaned.split(RegExp(r'[/\-\.]'));
          if (parts.length != 3) continue;

          int day, month, year;

          if (format.startsWith('dd')) {
            day = int.parse(parts[0]);
            month = int.parse(parts[1]);
            year = int.parse(parts[2]);
          } else if (format.startsWith('MM')) {
            month = int.parse(parts[0]);
            day = int.parse(parts[1]);
            year = int.parse(parts[2]);
          } else {
            year = int.parse(parts[0]);
            month = int.parse(parts[1]);
            day = int.parse(parts[2]);
          }

          // Handle 2-digit years
          if (year < 100) {
            year += 2000; // Assume 21st century
          }

          // Validate date
          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            return DateTime(year, month, day);
          }
        } catch (e) {
          continue;
        }
      }

      return null;
    } catch (e) {
      print('Error parsing date: $e');
      return null;
    }
  }

  DateTime? _parseMonthDate(RegExpMatch match) {
    try {
      final monthMap = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };

      late int day, month, year;

      if (match.groupCount == 3) {
        if (monthMap.containsKey(match.group(2)?.toLowerCase())) {
          // Format: day month year
          day = int.parse(match.group(1)!);
          month = monthMap[match.group(2)!.toLowerCase()]!;
          year = int.parse(match.group(3)!);
        } else {
          // Format: month day year
          month = monthMap[match.group(1)!.toLowerCase()]!;
          day = int.parse(match.group(2)!);
          year = int.parse(match.group(3)!);
        }
      } else {
        return null;
      }

      // Handle 2-digit years
      if (year < 100) {
        year += 2000; // Assume 21st century
      }

      return DateTime(year, month, day);
    } catch (e) {
      print('Error parsing month date: $e');
      return null;
    }
  }

  Future<File?> pickImageFromCamera() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('Error picking image from camera: $e');
      return null;
    }
  }

  Future<File?> pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      print('Error picking image from gallery: $e');
      return null;
    }
  }

  Future<List<String>> extractAllText(File imageFile) async {
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      return recognizedText.text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    } catch (e) {
      print('Error extracting text: $e');
      return [];
    }
  }

  void dispose() {
    barcodeScanner.close();
    textRecognizer.close();
  }
}