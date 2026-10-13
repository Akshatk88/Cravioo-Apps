import 'package:food_user_application/features/wallet/presentation/widgets/money_ui.dart';

class TaxReportOrder {
  TaxReportOrder({
    required this.orderId,
    required this.date,
    required this.itemSubtotal,
    required this.commission,
    required this.packagingFee,
    required this.total,
  });

  factory TaxReportOrder.fromJson(Map<String, dynamic> json) {
    return TaxReportOrder(
      orderId: (json['orderId'] ?? '').toString(),
      date: asDate(json['date']),
      itemSubtotal: asNum(json['itemSubtotal'])?.toDouble() ?? 0,
      commission: asNum(json['commission'])?.toDouble() ?? 0,
      packagingFee: asNum(json['packagingFee'])?.toDouble() ?? 0,
      total: asNum(json['total'])?.toDouble() ?? 0,
    );
  }

  final String orderId;
  final DateTime? date;
  final double itemSubtotal;
  final double commission;
  final double packagingFee;
  final double total;
}

class TaxReportTotals {
  const TaxReportTotals({
    this.itemSubtotal = 0,
    this.commission = 0,
    this.packagingFee = 0,
    this.total = 0,
  });

  factory TaxReportTotals.fromJson(Map<String, dynamic> json) {
    return TaxReportTotals(
      itemSubtotal: asNum(json['itemSubtotal'])?.toDouble() ?? 0,
      commission: asNum(json['commission'])?.toDouble() ?? 0,
      packagingFee: asNum(json['packagingFee'])?.toDouble() ?? 0,
      total: asNum(json['total'])?.toDouble() ?? 0,
    );
  }

  final double itemSubtotal;
  final double commission;
  final double packagingFee;
  final double total;
}

/// Response of GET /food/restaurant/orders/tax-report.
class TaxReportModel {
  TaxReportModel({
    required this.restaurantName,
    required this.restaurantCode,
    required this.startDate,
    required this.endDate,
    required this.orders,
    required this.totals,
    required this.generatedAt,
  });

  factory TaxReportModel.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurant'] is Map
        ? Map<String, dynamic>.from(json['restaurant'] as Map)
        : <String, dynamic>{};
    final period = json['period'] is Map
        ? Map<String, dynamic>.from(json['period'] as Map)
        : <String, dynamic>{};
    return TaxReportModel(
      restaurantName: (restaurant['name'] ?? '').toString(),
      restaurantCode: (restaurant['code'] ?? '').toString(),
      startDate: asDate(period['startDate']),
      endDate: asDate(period['endDate']),
      orders: (json['orders'] is List ? json['orders'] as List : const [])
          .whereType<Map>()
          .map((e) => TaxReportOrder.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totals: json['totals'] is Map
          ? TaxReportTotals.fromJson(
              Map<String, dynamic>.from(json['totals'] as Map),
            )
          : const TaxReportTotals(),
      generatedAt: asDate(json['generatedAt']),
    );
  }

  final String restaurantName;
  final String restaurantCode;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<TaxReportOrder> orders;
  final TaxReportTotals totals;
  final DateTime? generatedAt;

  /// CSV with the same columns/totals row as the web Excel export.
  String toCsv() {
    String esc(Object? v) {
      final s = (v ?? '').toString();
      return (s.contains(',') || s.contains('"') || s.contains('\n'))
          ? '"${s.replaceAll('"', '""')}"'
          : s;
    }

    String m(double v) => v.toStringAsFixed(2);
    final b = StringBuffer()
      ..writeln('Restaurant Taxes Report')
      ..writeln(esc(
          'Restaurant: ${restaurantName.isEmpty ? 'N/A' : restaurantName}'
          '${restaurantCode.isEmpty ? '' : ' ($restaurantCode)'}'))
      ..writeln(esc(
          'Period: ${startDate != null ? formatDateTime(startDate) : 'All time'}'
          ' - ${endDate != null ? formatDateTime(endDate) : 'Now'}'))
      ..writeln(esc('Total Orders: ${orders.length}'))
      ..writeln()
      ..writeln(
          'Order ID,Order Date,Item Subtotal,Commission Deducted,Packing Fee Earned,Order Total');
    for (final o in orders) {
      b.writeln([
        esc(o.orderId),
        esc(formatDateTime(o.date)),
        m(o.itemSubtotal),
        m(o.commission),
        m(o.packagingFee),
        m(o.total),
      ].join(','));
    }
    b.writeln([
      '',
      'Grand Total',
      m(totals.itemSubtotal),
      m(totals.commission),
      m(totals.packagingFee),
      m(totals.total),
    ].join(','));
    return b.toString();
  }
}

/// A period the admin has shared with this restaurant.
class SharedTaxReport {
  SharedTaxReport({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.sharedAt,
  });

  factory SharedTaxReport.fromJson(Map<String, dynamic> json) {
    return SharedTaxReport(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      startDate: asDate(json['startDate']),
      endDate: asDate(json['endDate']),
      sharedAt: asDate(json['sharedAt']),
    );
  }

  final String id;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime? sharedAt;
}
