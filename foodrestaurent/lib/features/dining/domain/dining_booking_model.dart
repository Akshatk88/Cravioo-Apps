class BookedTableModel {
  final String id;
  final String name;
  final int seats;

  const BookedTableModel({
    required this.id,
    required this.name,
    required this.seats,
  });

  factory BookedTableModel.fromJson(Map<String, dynamic> json) {
    return BookedTableModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      seats: (json['seats'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'seats': seats,
  };
}

class DiningBookingModel {
  final String id;
  final String bookingCode;
  final String status;
  final String restaurantId;
  final String restaurantName;
  final String date;
  final String slotStart;
  final String slotEnd;
  final int guests;
  final List<BookedTableModel> tables;
  final String guestName;
  final String guestPhone;
  final String occasion;
  final String specialRequest;
  final String cancelledBy;
  final String cancelReason;
  final String paymentStatus;
  final String paymentMethod;
  final double paidAmount;
  final double reservationFee;
  final DateTime? createdAt;

  const DiningBookingModel({
    required this.id,
    required this.bookingCode,
    required this.status,
    required this.restaurantId,
    required this.restaurantName,
    required this.date,
    required this.slotStart,
    required this.slotEnd,
    required this.guests,
    required this.tables,
    required this.guestName,
    required this.guestPhone,
    required this.occasion,
    required this.specialRequest,
    required this.cancelledBy,
    required this.cancelReason,
    this.paymentStatus = 'free',
    this.paymentMethod = 'free',
    this.paidAmount = 0.0,
    this.reservationFee = 0.0,
    this.createdAt,
  });

  factory DiningBookingModel.fromJson(Map<String, dynamic> json) {
    final rawTables = json['tables'] as List? ?? [];
    return DiningBookingModel(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      bookingCode: json['bookingCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      restaurantId: json['restaurantId']?.toString() ?? '',
      restaurantName: json['restaurantName']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      slotStart: json['slotStart']?.toString() ?? '',
      slotEnd: json['slotEnd']?.toString() ?? '',
      guests: (json['guests'] as num?)?.toInt() ?? 1,
      tables: rawTables
          .map((t) => BookedTableModel.fromJson(Map<String, dynamic>.from(t as Map)))
          .toList(),
      guestName: json['guestName']?.toString() ?? '',
      guestPhone: json['guestPhone']?.toString() ?? '',
      occasion: json['occasion']?.toString() ?? '',
      specialRequest: json['specialRequest']?.toString() ?? '',
      cancelledBy: json['cancelledBy']?.toString() ?? '',
      cancelReason: json['cancelReason']?.toString() ?? '',
      paymentStatus: json['paymentStatus']?.toString() ?? 'free',
      paymentMethod: json['paymentMethod']?.toString() ?? 'free',
      paidAmount: (json['paidAmount'] as num?)?.toDouble() ?? 0.0,
      reservationFee: (json['reservationFee'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isSeated => status == 'seated';
  bool get isCompleted => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isRejected => status == 'rejected';
  bool get isNoShow => status == 'no_show';
}
