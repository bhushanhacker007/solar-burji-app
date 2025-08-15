class SolarDay {
  final String readingDate; // YYYY-MM-DD
  final double importKwh;
  final double exportKwh;
  final double generationKwh;
  final String? notes;

  SolarDay({
    required this.readingDate,
    required this.importKwh,
    required this.exportKwh,
    required this.generationKwh,
    this.notes,
  });

  factory SolarDay.fromJson(Map<String, dynamic> j) => SolarDay(
        readingDate: j['reading_date'] as String,
        importKwh: (j['import_kwh'] as num).toDouble(),
        exportKwh: (j['export_kwh'] as num).toDouble(),
        generationKwh: (j['generation_kwh'] as num).toDouble(),
        notes: j['notes'] as String?,
      );
}

class Sale {
  final String txnDate;
  final double amount;
  final String paymentMethod; // cash|online
  final String? note;

  Sale({required this.txnDate, required this.amount, required this.paymentMethod, this.note});

  Map<String, dynamic> toJson() => {
        'txn_date': txnDate,
        'amount': amount,
        'payment_method': paymentMethod,
        'note': note,
      };
}

class BorrowEntry {
  final String txnDate;
  final String customerName;
  final double amount;
  final bool isRepayment;
  final String? note;

  BorrowEntry({
    required this.txnDate,
    required this.customerName,
    required this.amount,
    required this.isRepayment,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'txn_date': txnDate,
        'customer_name': customerName,
        'amount': amount,
        'is_repayment': isRepayment ? 1 : 0,
        'note': note,
      };
}
