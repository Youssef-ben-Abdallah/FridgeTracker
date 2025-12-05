import '../utils/constants.dart';

class Product {
  final String barcode;
  String name;
  String category;
  int? defaultExpirationDays;
  String? imagePath;
  DateTime createdAt;

  Product({
    required this.barcode,
    required this.name,
    required this.category,
    this.defaultExpirationDays,
    this.imagePath,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'name': name,
      'category': category,
      'default_expiration_days': defaultExpirationDays,
      'image_path': imagePath,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      barcode: map['barcode'],
      name: map['name'],
      category: map['category'],
      defaultExpirationDays: map['default_expiration_days'],
      imagePath: map['image_path'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }

  // Helper to get expiration date from added date
  DateTime getExpiryDate({DateTime? addedDate}) {
    final startDate = addedDate ?? DateTime.now();
    if (defaultExpirationDays != null) {
      return startDate.add(Duration(days: defaultExpirationDays!));
    }

    // Fallback to category-based defaults
    final categoryDays = AppConstants.defaultExpirationDays[category];
    if (categoryDays != null) {
      return startDate.add(Duration(days: categoryDays));
    }

    // Default to 7 days if nothing else
    return startDate.add(const Duration(days: 7));
  }
}