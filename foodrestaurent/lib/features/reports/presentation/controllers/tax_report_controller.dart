import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/reports/data/tax_report_repository.dart';
import 'package:food_user_application/features/reports/domain/tax_report_model.dart';

/// Holds the most recently generated taxes report (null until generated).
class TaxReportController extends AsyncNotifier<TaxReportModel?> {
  @override
  Future<TaxReportModel?> build() async => null;

  /// Dates are 'YYYY-MM-DD' strings (or null for open-ended).
  Future<void> generate({String? startDate, String? endDate}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref
          .read(taxReportRepositoryProvider)
          .getMyTaxesReport(startDate: startDate, endDate: endDate),
    );
  }

  void clear() => state = const AsyncValue.data(null);
}

final taxReportControllerProvider =
    AsyncNotifierProvider<TaxReportController, TaxReportModel?>(
      TaxReportController.new,
    );

/// Periods the admin has shared with this restaurant.
class SharedTaxReportsController extends AsyncNotifier<List<SharedTaxReport>> {
  @override
  Future<List<SharedTaxReport>> build() {
    return ref.read(taxReportRepositoryProvider).listSharedReports();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(taxReportRepositoryProvider).listSharedReports(),
    );
  }
}

final sharedTaxReportsControllerProvider =
    AsyncNotifierProvider<SharedTaxReportsController, List<SharedTaxReport>>(
      SharedTaxReportsController.new,
    );
