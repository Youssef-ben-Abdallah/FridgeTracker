class InventoryItem {
  int? id;
  final String barcode;
  final String name;
  final String category;
  final int quantity;
  final String? unit;
  final int addedAt;
  final int expiryAt;
  final String? photoPath;
  final String? notes;
  bool isConsumed;

  InventoryItem({
    this.id,
    required this.barcode,
    required this.name,
    required this.category,
    this.quantity = 1,
    this.unit,
    required this.addedAt,
    required this.expiryAt,
    this.photoPath,
    this.notes,
    this.isConsumed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'barcode': barcode,
      'name': name,
      'category': category,
      'quantity': quantity,
      'unit': unit,
      'added_at': addedAt,
      'expiry_at': expiryAt,
      'photo_path': photoPath,
      'notes': notes,
      'is_consumed': isConsumed ? 1 : 0,
    };
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'],
      barcode: map['barcode'],
      name: map['name'],
      category: map['category'],
      quantity: map['quantity'],
      unit: map['unit'],
      addedAt: map['added_at'],
      expiryAt: map['expiry_at'],
      photoPath: map['photo_path'],
      notes: map['notes'],
      isConsumed: map['is_consumed'] == 1,
    );
  }

  int get daysUntilExpiry {
    final now = DateTime.now();
    final expiry = DateTime.fromMillisecondsSinceEpoch(expiryAt);
    return expiry.difference(now).inDays;
  }

  String get expiryStatus {
    final days = daysUntilExpiry;
    if (days < 0) return 'expired';
    if (days <= 1) return 'critical';
    if (days <= 3) return 'warning';
    return 'safe';
  }

  bool get isExpired => daysUntilExpiry < 0;
  bool get isExpiringSoon => daysUntilExpiry <= 3;
  bool get isCritical => daysUntilExpiry <= 1;

  DateTime get addedDate => DateTime.fromMillisecondsSinceEpoch(addedAt);
  DateTime get expiryDate => DateTime.fromMillisecondsSinceEpoch(expiryAt);

  String get formattedAddedDate {
    return _formatDate(addedDate);
  }

  String get formattedExpiryDate {
    return _formatDate(expiryDate);
  }

  String get expiryMessage {
    final days = daysUntilExpiry;
    if (days < 0) return 'Expired ${-days} days ago';
    if (days == 0) return 'Expires today';
    if (days == 1) return 'Expires tomorrow';
    if (days <= 7) return 'Expires in $days days';
    final weeks = (days / 7).floor();
    return 'Expires in $weeks ${weeks == 1 ? 'week' : 'weeks'}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == yesterday) return 'Yesterday';

    final diff = today.difference(dateOnly).inDays;
    if (diff < 7 && diff > -7) {
      if (diff > 0) return '$diff days ago';
      return 'In ${-diff} days';
    }

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  InventoryItem copyWith({
    int? id,
    String? barcode,
    String? name,
    String? category,
    int? quantity,
    String? unit,
    int? addedAt,
    int? expiryAt,
    String? photoPath,
    String? notes,
    bool? isConsumed,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      addedAt: addedAt ?? this.addedAt,
      expiryAt: expiryAt ?? this.expiryAt,
      photoPath: photoPath ?? this.photoPath,
      notes: notes ?? this.notes,
      isConsumed: isConsumed ?? this.isConsumed,
    );
  }
}