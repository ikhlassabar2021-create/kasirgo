class Debt {
  final String id;
  final String outletId;
  final String? customerId;
  final String? transactionId;
  final double amount;
  final double paidAmount;
  final String status; // unpaid, partial, paid
  final DateTime? dueDate;
  final String? note;
  final DateTime createdAt;

  const Debt({
    required this.id,
    required this.outletId,
    this.customerId,
    this.transactionId,
    required this.amount,
    this.paidAmount = 0,
    this.status = 'unpaid',
    this.dueDate,
    this.note,
    required this.createdAt,
  });

  double get remainingAmount => amount - paidAmount;

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] ?? '',
      outletId: json['outlet_id'] ?? '',
      customerId: json['customer_id'],
      transactionId: json['transaction_id'],
      amount: (json['amount'] ?? 0).toDouble(),
      paidAmount: (json['paid_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'unpaid',
      dueDate: json['due_date'] != null
          ? DateTime.parse(json['due_date'])
          : null,
      note: json['note'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'outlet_id': outletId,
      'customer_id': customerId,
      'transaction_id': transactionId,
      'amount': amount,
      'paid_amount': paidAmount,
      'status': status,
      if (dueDate != null)
        'due_date':
            "${dueDate!.year.toString().padLeft(4, '0')}-${dueDate!.month.toString().padLeft(2, '0')}-${dueDate!.day.toString().padLeft(2, '0')}",
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'outlet_id': outletId,
      'customer_id': customerId,
      'transaction_id': transactionId,
      'amount': amount,
      'paid_amount': paidAmount,
      'status': status,
      'due_date': dueDate?.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'] ?? '',
      outletId: map['outlet_id'] ?? '',
      customerId: map['customer_id'],
      transactionId: map['transaction_id'],
      amount: (map['amount'] ?? 0).toDouble(),
      paidAmount: (map['paid_amount'] ?? 0).toDouble(),
      status: map['status'] ?? 'unpaid',
      dueDate: map['due_date'] != null
          ? DateTime.parse(map['due_date'])
          : null,
      note: map['note'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Debt copyWith({
    String? id,
    String? outletId,
    String? customerId,
    String? transactionId,
    double? amount,
    double? paidAmount,
    String? status,
    DateTime? dueDate,
    String? note,
    DateTime? createdAt,
  }) {
    return Debt(
      id: id ?? this.id,
      outletId: outletId ?? this.outletId,
      customerId: customerId ?? this.customerId,
      transactionId: transactionId ?? this.transactionId,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      status: status ?? this.status,
      dueDate: dueDate ?? this.dueDate,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class DebtPayment {
  final String id;
  final String debtId;
  final double amount;
  final DateTime paidAt;

  const DebtPayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.paidAt,
  });

  factory DebtPayment.fromJson(Map<String, dynamic> json) {
    return DebtPayment(
      id: json['id'] ?? '',
      debtId: json['debt_id'] ?? '',
      amount: (json['amount'] ?? 0).toDouble(),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'debt_id': debtId,
      'amount': amount,
      'paid_at': paidAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debt_id': debtId,
      'amount': amount,
      'paid_at': paidAt.toIso8601String(),
    };
  }

  factory DebtPayment.fromMap(Map<String, dynamic> map) {
    return DebtPayment(
      id: map['id'] ?? '',
      debtId: map['debt_id'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paidAt: map['paid_at'] != null
          ? DateTime.parse(map['paid_at'])
          : DateTime.now(),
    );
  }

  DebtPayment copyWith({
    String? id,
    String? debtId,
    double? amount,
    DateTime? paidAt,
  }) {
    return DebtPayment(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      amount: amount ?? this.amount,
      paidAt: paidAt ?? this.paidAt,
    );
  }
}
