class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email wajib diisi';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(value)) return 'Email tidak valid';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';
    if (value.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  static String? required(String? value, [String field = 'Field']) {
    if (value == null || value.trim().isEmpty) return '$field wajib diisi';
    return null;
  }

  static String? price(String? value) {
    if (value == null || value.isEmpty) return 'Harga wajib diisi';
    final price = double.tryParse(value);
    if (price == null || price < 0) return 'Harga tidak valid';
    return null;
  }

  static String? stock(String? value) {
    if (value == null || value.isEmpty) return 'Stok wajib diisi';
    final stock = double.tryParse(value);
    if (stock == null || stock < 0) return 'Stok tidak valid';
    return null;
  }
}