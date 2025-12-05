class Validators {
  // Barcode validators
  static String? validateBarcode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Barcode is required';
    }

    if (value.length < 6 || value.length > 20) {
      return 'Barcode must be between 6 and 20 characters';
    }

    // Check if contains only numbers
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Barcode can only contain numbers';
    }

    return null;
  }

  // Product name validators
  static String? validateProductName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Product name is required';
    }

    if (value.length < 2) {
      return 'Product name must be at least 2 characters';
    }

    if (value.length > 100) {
      return 'Product name is too long';
    }

    return null;
  }

  // Category validators
  static String? validateCategory(String? value) {
    if (value == null || value.isEmpty) {
      return 'Category is required';
    }

    if (value.length < 2) {
      return 'Category must be at least 2 characters';
    }

    if (value.length > 50) {
      return 'Category is too long';
    }

    return null;
  }

  // Expiration days validators
  static String? validateExpirationDays(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final days = int.tryParse(value);
    if (days == null) {
      return 'Please enter a valid number';
    }

    if (days <= 0) {
      return 'Expiration days must be positive';
    }

    if (days > 365 * 5) { // 5 years max
      return 'Expiration days cannot exceed 5 years';
    }

    return null;
  }

  // Quantity validators
  static String? validateQuantity(String? value) {
    if (value == null || value.isEmpty) {
      return 'Quantity is required';
    }

    final quantity = int.tryParse(value);
    if (quantity == null) {
      return 'Please enter a valid number';
    }

    if (quantity <= 0) {
      return 'Quantity must be at least 1';
    }

    if (quantity > 999) {
      return 'Quantity is too high';
    }

    return null;
  }

  // Unit validators
  static String? validateUnit(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    if (value.length > 10) {
      return 'Unit is too long';
    }

    return null;
  }

  // Notes validators
  static String? validateNotes(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    if (value.length > 500) {
      return 'Notes are too long (max 500 characters)';
    }

    return null;
  }

  // Date validators
  static String? validateFutureDate(DateTime? date) {
    if (date == null) {
      return 'Date is required';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDate = DateTime(date.year, date.month, date.day);

    if (selectedDate.isBefore(today)) {
      return 'Date cannot be in the past';
    }

    // Check if date is too far in the future (10 years max)
    final maxDate = today.add(const Duration(days: 365 * 10));
    if (selectedDate.isAfter(maxDate)) {
      return 'Date is too far in the future';
    }

    return null;
  }

  // Email validators (for future use)
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email';
    }

    return null;
  }

  // Password validators (for future use)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }

    return null;
  }

  // Confirm password validators (for future use)
  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }

  // Phone number validators (for future use)
  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Tunisian phone number format
    final phoneRegex = RegExp(r'^[259][0-9]{7}$');

    if (!phoneRegex.hasMatch(value)) {
      return 'Please enter a valid Tunisian phone number';
    }

    return null;
  }

  // Search query validators
  static String? validateSearchQuery(String? value) {
    if (value == null || value.isEmpty) {
      return 'Search query is required';
    }

    if (value.length < 2) {
      return 'Search query must be at least 2 characters';
    }

    return null;
  }

  // Price validators (for future use)
  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final price = double.tryParse(value);
    if (price == null) {
      return 'Please enter a valid price';
    }

    if (price < 0) {
      return 'Price cannot be negative';
    }

    if (price > 1000000) {
      return 'Price is too high';
    }

    return null;
  }

  // Weight validators (for future use)
  static String? validateWeight(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final weight = double.tryParse(value);
    if (weight == null) {
      return 'Please enter a valid weight';
    }

    if (weight <= 0) {
      return 'Weight must be positive';
    }

    if (weight > 1000) {
      return 'Weight is too high';
    }

    return null;
  }

  // URL validators (for future use)
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }

    final urlRegex = RegExp(
      r'^(https?:\/\/)?' // protocol
      r'((([a-zA-Z0-9]([a-zA-Z0-9-]*[a-zA-Z0-9])?)\.)+[a-zA-Z]{2,}|' // domain
      r'localhost|' // localhost
      r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})' // OR ip
      r'(:\d+)?' // port
      r'(\/[^\s]*)?$', // path
      caseSensitive: false,
    );

    if (!urlRegex.hasMatch(value)) {
      return 'Please enter a valid URL';
    }

    return null;
  }
}