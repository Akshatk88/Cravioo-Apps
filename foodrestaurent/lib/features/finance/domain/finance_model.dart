class FinanceOrderRow {
  FinanceOrderRow({
    required this.orderId,
    required this.orderTotal,
    required this.totalAmount,
    required this.payout,
    required this.commission,
    required this.paymentMethod,
    required this.orderStatus,
    required this.status,
    required this.createdAt,
  });

  factory FinanceOrderRow.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());
    return FinanceOrderRow(
      orderId: (json['orderId'] ?? '').toString(),
      orderTotal: asNum(json['orderTotal'])?.toDouble() ?? 0,
      totalAmount: asNum(json['totalAmount'])?.toDouble() ?? 0,
      payout: asNum(json['payout'])?.toDouble() ?? 0,
      commission: asNum(json['commission'])?.toDouble() ?? 0,
      paymentMethod: (json['paymentMethod'] ?? '').toString(),
      orderStatus: (json['orderStatus'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }

  final String orderId;
  final double orderTotal;
  final double totalAmount;
  final double payout;
  final double commission;
  final String paymentMethod;
  final String orderStatus;
  final String status;
  final DateTime createdAt;
}

class FinanceModel {
  FinanceModel({
    required this.restaurantName,
    required this.restaurantDisplayId,
    required this.subscriptionDueAmount,
    required this.subscriptionStatus,
    required this.lockedAmount,
    required this.lockedMonths,
    required this.openInvoices,
    required this.totalEarnings,
    required this.totalWithdrawn,
    required this.withdrawableBalance,
    required this.netAvailable,
    required this.totalOrders,
    required this.invoiceCount,
    required this.invoiceSubtotal,
    required this.invoiceTaxes,
    required this.invoiceGross,
    required this.orders,
  });

  factory FinanceModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());

    final restaurant = Map<String, dynamic>.from(
      (json['restaurant'] ?? {}) as Map,
    );
    final subscription = Map<String, dynamic>.from(
      (json['subscription'] ?? {}) as Map,
    );
    final wallet = Map<String, dynamic>.from((json['wallet'] ?? {}) as Map);
    final invoiceSummary = Map<String, dynamic>.from(
      (json['invoiceSummary'] ?? {}) as Map,
    );
    final orders = (wallet['orders'] as List? ?? [])
        .map(
          (e) => FinanceOrderRow.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();

    return FinanceModel(
      restaurantName: (restaurant['name'] ?? '').toString(),
      restaurantDisplayId: (restaurant['restaurantId'] ?? '').toString(),
      subscriptionDueAmount:
          asNum(restaurant['subscriptionDueAmount'])?.toDouble() ?? 0,
      subscriptionStatus: (restaurant['subscriptionStatus'] ?? '').toString(),
      lockedAmount: asNum(subscription['lockedAmount'])?.toDouble() ?? 0,
      lockedMonths: (subscription['lockedMonths'] ?? '').toString(),
      openInvoices: (subscription['openInvoices'] is num)
          ? (subscription['openInvoices'] as num).toInt()
          : 0,
      totalEarnings: asNum(wallet['totalEarnings'])?.toDouble() ?? 0,
      totalWithdrawn: asNum(wallet['totalWithdrawn'])?.toDouble() ?? 0,
      withdrawableBalance:
          asNum(wallet['withdrawableBalance'])?.toDouble() ?? 0,
      netAvailable: asNum(wallet['netAvailable'])?.toDouble() ?? 0,
      totalOrders: (wallet['totalOrders'] is num)
          ? (wallet['totalOrders'] as num).toInt()
          : 0,
      invoiceCount: (invoiceSummary['count'] is num)
          ? (invoiceSummary['count'] as num).toInt()
          : 0,
      invoiceSubtotal: asNum(invoiceSummary['subtotal'])?.toDouble() ?? 0,
      invoiceTaxes: asNum(invoiceSummary['taxes'])?.toDouble() ?? 0,
      invoiceGross: asNum(invoiceSummary['gross'])?.toDouble() ?? 0,
      orders: orders,
    );
  }

  final String restaurantName;
  final String restaurantDisplayId;
  final double subscriptionDueAmount;
  final String subscriptionStatus;
  final double lockedAmount;
  final String lockedMonths;
  final int openInvoices;
  final double totalEarnings;
  final double totalWithdrawn;
  final double withdrawableBalance;
  final double netAvailable;
  final int totalOrders;
  final int invoiceCount;
  final double invoiceSubtotal;
  final double invoiceTaxes;
  final double invoiceGross;
  final List<FinanceOrderRow> orders;
}
