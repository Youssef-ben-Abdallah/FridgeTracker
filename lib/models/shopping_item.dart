import 'package:flutter/material.dart';

class ShoppingItem {
  int? id;
  final String? productId; // Reference to products table
  final String name;
  final String category;
  final int quantityNeeded;
  final String? unit;
  final int priority; // 1=Low, 2=Medium, 3=High
  final bool isPurchased;
  final int addedAt;
  final int? purchasedAt;
  final String? notes;
  final String? suggestedBy; // How this item was suggested
  final double? estimatedPrice;

  ShoppingItem({
    this.id,
    this.productId,
    required this.name,
    required this.category,
    this.quantityNeeded = 1,
    this.unit,
    this.priority = 1,
    this.isPurchased = false,
    required this.addedAt,
    this.purchasedAt,
    this.notes,
    this.suggestedBy,
    this.estimatedPrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_id': productId,
      'name': name,
      'category': category,
      'quantity_needed': quantityNeeded,
      'unit': unit,
      'priority': priority,
      'is_purchased': isPurchased ? 1 : 0,
      'added_at': addedAt,
      'purchased_at': purchasedAt,
      'notes': notes,
      'suggested_by': suggestedBy,
      'estimated_price': estimatedPrice,
    };
  }

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    return ShoppingItem(
      id: map['id'],
      productId: map['product_id'],
      name: map['name'],
      category: map['category'],
      quantityNeeded: map['quantity_needed'],
      unit: map['unit'],
      priority: map['priority'],
      isPurchased: map['is_purchased'] == 1,
      addedAt: map['added_at'],
      purchasedAt: map['purchased_at'],
      notes: map['notes'],
      suggestedBy: map['suggested_by'],
      estimatedPrice: map['estimated_price'],
    );
  }

  // Helper methods
  bool get isHighPriority => priority == 3;
  bool get isMediumPriority => priority == 2;
  bool get isLowPriority => priority == 1;

  String get priorityText {
    switch (priority) {
      case 3: return 'High';
      case 2: return 'Medium';
      default: return 'Low';
    }
  }

  Color get priorityColor {
    switch (priority) {
      case 3: return Colors.red;
      case 2: return Colors.orange;
      default: return Colors.blue;
    }
  }

  IconData get priorityIcon {
    switch (priority) {
      case 3: return Icons.warning;
      case 2: return Icons.info;
      default: return Icons.check_circle;
    }
  }

  ShoppingItem copyWith({
    int? id,
    String? productId,
    String? name,
    String? category,
    int? quantityNeeded,
    String? unit,
    int? priority,
    bool? isPurchased,
    int? addedAt,
    int? purchasedAt,
    String? notes,
    String? suggestedBy,
    double? estimatedPrice,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      name: name ?? this.name,
      category: category ?? this.category,
      quantityNeeded: quantityNeeded ?? this.quantityNeeded,
      unit: unit ?? this.unit,
      priority: priority ?? this.priority,
      isPurchased: isPurchased ?? this.isPurchased,
      addedAt: addedAt ?? this.addedAt,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      notes: notes ?? this.notes,
      suggestedBy: suggestedBy ?? this.suggestedBy,
      estimatedPrice: estimatedPrice ?? this.estimatedPrice,
    );
  }
}