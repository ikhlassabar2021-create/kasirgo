/// Akun Pembeli LOKAL (disimpan di perangkat, bukan server).
///
/// Berisi data akun yang diisi sekali saat daftar: nama akun, nama, email,
/// nomor HP, dan alamat lengkap. Dipakai untuk mengisi otomatis (autofill)
/// saat checkout. Kebijakan: "buyer data tersimpan LOKAL saja".
class BuyerProfile {
  final String accountName;
  final String name;
  final String email;
  final String phone;
  final String address;

  const BuyerProfile({
    this.accountName = '',
    this.name = '',
    this.email = '',
    this.phone = '',
    this.address = '',
  });

  bool get isEmpty =>
      accountName.trim().isEmpty &&
      name.trim().isEmpty &&
      email.trim().isEmpty &&
      phone.trim().isEmpty &&
      address.trim().isEmpty;

  bool get hasName => name.trim().isNotEmpty;

  bool get hasPhone => phone.trim().isNotEmpty;

  bool get hasAddress => address.trim().isNotEmpty;

  BuyerProfile copyWith({
    String? accountName,
    String? name,
    String? email,
    String? phone,
    String? address,
  }) {
    return BuyerProfile(
      accountName: accountName ?? this.accountName,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
    );
  }

  factory BuyerProfile.fromJson(Map<String, dynamic> json) {
    return BuyerProfile(
      accountName: json['account_name']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_name': accountName,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
    };
  }
}
