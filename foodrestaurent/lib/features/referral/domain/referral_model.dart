double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;
int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

class ReferralStats {
  const ReferralStats({
    this.referralCount = 0,
    this.totalReferralEarnings = 0,
    this.rewardAmount = 0,
    this.totalInvited = 0,
    this.creditedCount = 0,
    this.pendingCount = 0,
    this.rejectedCount = 0,
  });

  final int referralCount;
  final double totalReferralEarnings;
  final double rewardAmount;
  final int totalInvited;
  final int creditedCount;
  final int pendingCount;
  final int rejectedCount;

  factory ReferralStats.fromJson(Map<String, dynamic> j) => ReferralStats(
    referralCount: _int(j['referralCount']),
    totalReferralEarnings: _num(j['totalReferralEarnings']),
    rewardAmount: _num(j['rewardAmount']),
    totalInvited: _int(j['totalInvited']),
    creditedCount: _int(j['creditedCount']),
    pendingCount: _int(j['pendingCount']),
    rejectedCount: _int(j['rejectedCount']),
  );
}

class ReferredRestaurant {
  const ReferredRestaurant({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    required this.earnedAmount,
    this.invitedAt,
  });

  final String id;
  final String name;
  final String phone;

  /// credited | pending | rejected
  final String status;
  final double earnedAmount;
  final DateTime? invitedAt;

  factory ReferredRestaurant.fromJson(Map<String, dynamic> j) =>
      ReferredRestaurant(
        id: '${j['id'] ?? j['refereeId'] ?? ''}',
        name: '${j['name'] ?? 'Restaurant'}',
        phone: '${j['phone'] ?? ''}',
        status: '${j['status'] ?? 'pending'}',
        earnedAmount: _num(j['earnedAmount']),
        invitedAt: DateTime.tryParse('${j['invitedAt'] ?? ''}'),
      );
}

class ReferralData {
  const ReferralData({
    required this.referralCode,
    required this.stats,
    required this.referred,
  });

  final String referralCode;
  final ReferralStats stats;
  final List<ReferredRestaurant> referred;
}
