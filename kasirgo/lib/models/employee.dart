class Employee {
  final String id;
  final String outletId;
  final String? userId;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final String shift;
  final DateTime date;

  Employee({required this.id, required this.outletId, this.userId, this.checkInTime, this.checkOutTime, this.shift = 'pagi', required this.date});

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] ?? '', outletId: json['outlet_id'] ?? '', userId: json['user_id'],
      checkInTime: json['check_in_time'] != null ? DateTime.parse(json['check_in_time']) : null,
      checkOutTime: json['check_out_time'] != null ? DateTime.parse(json['check_out_time']) : null,
      shift: json['shift'] ?? 'pagi', date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'outlet_id': outletId, 'user_id': userId, 'check_in_time': checkInTime?.toIso8601String(), 'check_out_time': checkOutTime?.toIso8601String(), 'shift': shift, 'date': date.toIso8601String().split('T')[0]};
  Map<String, dynamic> toMap() => toJson();
  factory Employee.fromMap(Map<String, dynamic> map) => Employee.fromJson(map);
}