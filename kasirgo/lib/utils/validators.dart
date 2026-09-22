class Validators {
  static String? email(String? value) {
    if (value == null || value.isEmpty) return 'Email wajib diisi';
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(value)) return 'Format email tidak valid';
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password wajib diisi';
    if (value.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  static String? required(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Field ini'} wajib diisi';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null;
    final regex = RegExp(r'^[0-9]{10,13}$');
    if (!regex.hasMatch(value)) return 'Nomor telepon tidak valid';
    return null;
  }

  static String? phoneNumber(String? value) => phone(value);

  static String? number(String? value, [String? fieldName]) {
    if (value == null || value.isEmpty) {
      return '${fieldName ?? 'Field ini'} wajib diisi';
    }
    if (num.tryParse(value) == null) {
      return 'Harus berupa angka';
    }
    return null;
  }

  static String? positiveNumber(String? value, [String? fieldName]) {
    final numberError = Validators.number(value, fieldName);
    if (numberError != null) return numberError;
    if (num.parse(value!) <= 0) {
      return '${fieldName ?? 'Nilai'} harus lebih dari 0';
    }
    return null;
  }

  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) return 'Nama wajib diisi';
    if (value.trim().length < 2) return 'Nama minimal 2 karakter';
    return null;
  }
}