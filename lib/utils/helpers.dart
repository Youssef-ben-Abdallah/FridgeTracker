import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'constants.dart';

class Helpers {
  // Date and Time helpers
  static String formatDate(DateTime date, {String format = 'dd/MM/yyyy'}) {
    return DateFormat(format).format(date);
  }

  static String formatTimestamp(int timestamp, {String format = 'dd/MM/yyyy'}) {
    return formatDate(DateTime.fromMillisecondsSinceEpoch(timestamp), format: format);
  }

  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays == -1) {
      return 'Yesterday';
    } else if (difference.inDays > 0 && difference.inDays <= 7) {
      return 'In ${difference.inDays} days';
    } else if (difference.inDays < 0 && difference.inDays >= -7) {
      return '${-difference.inDays} days ago';
    } else {
      return formatDate(date);
    }
  }

  static String formatExpiryStatus(int daysUntilExpiry) {
    if (daysUntilExpiry < 0) {
      return 'Expired';
    } else if (daysUntilExpiry == 0) {
      return 'Expires today';
    } else if (daysUntilExpiry == 1) {
      return 'Expires tomorrow';
    } else if (daysUntilExpiry <= 7) {
      return 'Expires in $daysUntilExpiry days';
    } else {
      final weeks = (daysUntilExpiry / 7).floor();
      if (weeks == 1) {
        return 'Expires in 1 week';
      } else if (weeks > 1) {
        return 'Expires in $weeks weeks';
      } else {
        return 'Expires in $daysUntilExpiry days';
      }
    }
  }

  // Color helpers
  static Color getExpirationColor(int daysUntilExpiry) {
    if (daysUntilExpiry < 0) {
      return AppConstants.dangerColor;
    } else if (daysUntilExpiry <= AppConstants.criticalThreshold) {
      return Colors.red;
    } else if (daysUntilExpiry <= AppConstants.warningThreshold) {
      return AppConstants.warningColor;
    } else if (daysUntilExpiry <= AppConstants.cautionThreshold) {
      return Colors.yellow[700]!;
    } else {
      return AppConstants.successColor;
    }
  }

  static Color getCategoryColor(String category) {
    return AppConstants.categoryColors[category] ?? Colors.grey.shade200;
  }

  // Validation helpers
  static bool isValidBarcode(String barcode) {
    if (barcode.isEmpty) return false;

    // EAN-13 validation (simplified)
    if (barcode.length == 13) {
      return _validateEAN13(barcode);
    }

    // UPC-A validation (simplified)
    if (barcode.length == 12) {
      return _validateUPCA(barcode);
    }

    // Accept other lengths as they might be valid custom barcodes
    return barcode.length >= 6 && barcode.length <= 20;
  }

  static bool _validateEAN13(String barcode) {
    try {
      final digits = barcode.split('').map(int.parse).toList();
      var sum = 0;

      for (var i = 0; i < 12; i++) {
        sum += digits[i] * (i.isOdd ? 3 : 1);
      }

      final checksum = (10 - (sum % 10)) % 10;
      return checksum == digits[12];
    } catch (e) {
      return false;
    }
  }

  static bool _validateUPCA(String barcode) {
    try {
      final digits = barcode.split('').map(int.parse).toList();
      var sum = 0;

      for (var i = 0; i < 11; i++) {
        sum += digits[i] * (i.isOdd ? 3 : 1);
      }

      final checksum = (10 - (sum % 10)) % 10;
      return checksum == digits[11];
    } catch (e) {
      return false;
    }
  }

  // File helpers
  static Future<File> saveImageToAppDir(File image, String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final savedImage = await image.copy('${appDir.path}/$fileName');
    return savedImage;
  }

  static Future<void> deleteImageFile(String? filePath) async {
    if (filePath != null && filePath.isNotEmpty) {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  // UI helpers
  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static void showConfirmDialog(
      BuildContext context,
      String title,
      String message,
      Function() onConfirm,
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  static void showLoadingDialog(BuildContext context, {String message = 'Loading...'}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }

  // String helpers
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  static String truncateWithEllipsis(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  // Quantity helpers
  static String formatQuantity(int quantity, String? unit) {
    if (unit == null || unit.isEmpty) {
      return quantity.toString();
    }
    return '$quantity $unit';
  }

  // Expiration calculation helpers
  static DateTime calculateExpiryDate({
    required DateTime addedDate,
    int? productDefaultDays,
    String? category,
    DateTime? customExpiry,
  }) {
    if (customExpiry != null) {
      return customExpiry;
    }

    if (productDefaultDays != null) {
      return addedDate.add(Duration(days: productDefaultDays));
    }

    if (category != null) {
      final categoryDays = AppConstants.defaultExpirationDays[category];
      if (categoryDays != null) {
        return addedDate.add(Duration(days: categoryDays));
      }
    }

    // Default to 7 days
    return addedDate.add(const Duration(days: 7));
  }

  static int daysBetween(DateTime from, DateTime to) {
    from = DateTime(from.year, from.month, from.day);
    to = DateTime(to.year, to.month, to.day);
    return (to.difference(from).inDays).abs();
  }
}

// Platform-specific helpers (stubs for now)
Future<Directory> getApplicationDocumentsDirectory() async {
  // This would be implemented with path_provider in real app
  throw UnimplementedError('Use path_provider in real implementation');
}