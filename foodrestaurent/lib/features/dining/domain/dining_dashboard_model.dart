import 'dining_profile_model.dart';
import 'dining_table_model.dart';

class DiningStatsModel {
  final int pending;
  final int confirmed;
  final int seated;
  final int completed;
  final int cancelled;
  final int noShow;
  final int todayBookings;
  final int todayGuests;

  const DiningStatsModel({
    this.pending = 0,
    this.confirmed = 0,
    this.seated = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.noShow = 0,
    this.todayBookings = 0,
    this.todayGuests = 0,
  });

  factory DiningStatsModel.fromJson(Map<String, dynamic> json) {
    final today = json['today'] is Map ? json['today'] as Map : {};
    return DiningStatsModel(
      pending: (json['pending'] as num?)?.toInt() ?? 0,
      confirmed: (json['confirmed'] as num?)?.toInt() ?? 0,
      seated: (json['seated'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      noShow: (json['noShow'] as num?)?.toInt() ?? 0,
      todayBookings: (today['bookings'] as num?)?.toInt() ?? 0,
      todayGuests: (today['guests'] as num?)?.toInt() ?? 0,
    );
  }
}

class DiningDashboardModel {
  final DiningProfileModel? profile;
  final DiningStatsModel stats;
  final DiningTableSummary tables;

  const DiningDashboardModel({
    this.profile,
    this.stats = const DiningStatsModel(),
    this.tables = const DiningTableSummary(),
  });

  factory DiningDashboardModel.fromJson(Map<String, dynamic> json) {
    return DiningDashboardModel(
      profile: json['profile'] != null
          ? DiningProfileModel.fromJson(Map<String, dynamic>.from(json['profile'] as Map))
          : null,
      stats: json['stats'] != null
          ? DiningStatsModel.fromJson(Map<String, dynamic>.from(json['stats'] as Map))
          : const DiningStatsModel(),
      tables: json['tables'] != null
          ? DiningTableSummary.fromJson(Map<String, dynamic>.from(json['tables'] as Map))
          : const DiningTableSummary(),
    );
  }

  DiningDashboardModel copyWith({
    DiningProfileModel? profile,
    DiningStatsModel? stats,
    DiningTableSummary? tables,
  }) {
    return DiningDashboardModel(
      profile: profile ?? this.profile,
      stats: stats ?? this.stats,
      tables: tables ?? this.tables,
    );
  }
}
