import 'package:flutter/material.dart';

class AppConstants {
  // Database
  static const String databaseName = 'pantry_tracker.db';
  static const int databaseVersion = 1;

  // Default expiration days by category
  static final Map<String, int> defaultExpirationDays = {
    'Dairy': 7,
    'Meat': 3,
    'Produce': 5,
    'Bakery': 3,
    'Canned': 365,
    'Frozen': 90,
    'Beverages': 30,
    'Snacks': 60,
    'Condiments': 180,
    'Grains': 180,
    'Spices': 365,
    'Oil': 180,
    'Sauces': 90,
    'Spread': 60,
    'Cheese': 14,
    'Yogurt': 7,
    'Juice': 7,
    'Water': 0, // No expiration
  };

  // Category colors for UI
  static final Map<String, Color> categoryColors = {
    'Dairy': Colors.blue.shade100,
    'Meat': Colors.red.shade100,
    'Produce': Colors.green.shade100,
    'Bakery': Colors.orange.shade100,
    'Canned': Colors.grey.shade300,
    'Frozen': Colors.cyan.shade100,
    'Beverages': Colors.purple.shade100,
    'Snacks': Colors.yellow.shade100,
    'Condiments': Colors.brown.shade100,
    'Grains': Colors.amber.shade100,
    'Spices': Colors.deepOrange.shade100,
    'Oil': Colors.deepPurple.shade100,
    'Sauces': Colors.pink.shade100,
    'Spread': Colors.lime.shade100,
    'Cheese': Colors.indigo.shade100,
    'Yogurt': Colors.lightBlue.shade100,
    'Juice': Colors.teal.shade100,
    'Water': Colors.blueGrey.shade100,
  };

  // Colors
  static const Color primaryColor = Color(0xFF4CAF50);
  static const Color secondaryColor = Color(0xFF2196F3);
  static const Color warningColor = Color(0xFFFF9800);
  static const Color dangerColor = Color(0xFFF44336);
  static const Color successColor = Color(0xFF4CAF50);
  static const Color infoColor = Color(0xFF00BCD4);

  // Expiration status thresholds (in days)
  static const int criticalThreshold = 1;
  static const int warningThreshold = 3;
  static const int cautionThreshold = 7;

  // Notification schedules (in days before expiry)
  static const List<int> notificationDays = [3, 1, 0];

  // Units for products
  static const List<String> units = [
    'pcs', 'g', 'kg', 'ml', 'L', 'oz', 'lb', 'pack', 'bottle', 'can', 'box'
  ];

  // Common categories
  static const List<String> commonCategories = [
    'Dairy',
    'Meat',
    'Produce',
    'Bakery',
    'Canned',
    'Frozen',
    'Beverages',
    'Snacks',
    'Condiments',
    'Grains',
    'Spices',
    'Oil',
    'Sauces',
    'Spread',
    'Cheese',
    'Yogurt',
    'Juice',
    'Water',
    'Other'
  ];

  // In AppConstants class, add:
  static final Map<String, int> defaultMinimumStock = {
    'Dairy': 2,
    'Meat': 1,
    'Produce': 3,
    'Bakery': 1,
    'Canned': 2,
    'Frozen': 2,
    'Beverages': 3,
    'Snacks': 2,
    'Condiments': 1,
    'Grains': 1,
    'Spices': 1,
    'Oil': 1,
    'Sauces': 1,
    'Spread': 1,
    'Cheese': 1,
    'Yogurt': 2,
    'Juice': 2,
    'Water': 6,
  };
}