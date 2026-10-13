import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/reports/domain/tax_report_model.dart';
import 'package:food_user_application/features/reports/presentation/controllers/tax_report_controller.dart';
import 'package:food_user_application/features/wallet/presentation/widgets/money_ui.dart';

/// Taxes report: pick a period (or open an admin-shared period), generate it
/// from the backend, preview totals/orders and copy it as CSV.
class DownloadReportScreen extends ConsumerStatefulWidget {
  const DownloadReportScreen({super.key});

  @override
  ConsumerState<DownloadReportScreen> createState() =>
      _DownloadReportScreenState();
}

class _DownloadReportScreenState extends ConsumerState<DownloadReportScreen> {
  static final _api = DateFormat('yyyy-MM-dd');
  DateTimeRange? _range;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  void _preset(int days) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _range = DateTimeRange(
        start: today.subtract(Duration(days: days - 1)),
        end: today,
      );
    });
  }

  Future<void> _generate({String? start, String? end}) async {
    await ref
        .read(taxReportControllerProvider.notifier)
        .generate(
          startDate: start ?? (_range != null ? _api.format(_range!.start) : null),
          endDate: end ?? (_range != null ? _api.format(_range!.end) : null),
        );
  }

  Future<void> _openShared(SharedTaxReport s) async {
    setState(() {
      if (s.startDate != null && s.endDate != null) {
        _range = DateTimeRange(
          start: s.startDate!.toLocal(),
          end: s.endDate!.toLocal(),
        );
      } else {
        _range = null;
      }
    });
    await _generate(
      start: s.startDate != null ? _api.format(s.startDate!.toLocal()) : '',
      end: s.endDate != null ? _api.format(s.endDate!.toLocal()) : '',
    );
  }

  Future<void> _copyCsv(TaxReportModel r) async {
    if (r.orders.isEmpty) {
      showMoneySnack(context, 'No orders found for the selected period');
      return;
    }
    await Clipboard.setData(ClipboardData(text: r.toCsv()));
    if (mounted) {
      showMoneySnack(context, 'Report copied as CSV. Paste it into a sheet or note.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = MoneyColors(isDarkMode(context));
    final reportAsync = ref.watch(taxReportControllerProvider);
    final sharedAsync = ref.watch(sharedTaxReportsControllerProvider);
    final busy = reportAsync.isLoading;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        foregroundColor: c.text,
        elevation: 0,
        title: const Text('Download report'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: c.text, size: 20),
                    const SizedBox(width: 8),
                    Text('Taxes Report',
                        style: TextStyle(
                            color: c.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Your orders for a period: item subtotal, commission deducted, '
                  'packing fee earned and order total per order. Leave the period '
                  'empty for all time.',
                  style: TextStyle(color: c.subtext, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(label: const Text('Last 7 days'), onPressed: () => _preset(7)),
                    ActionChip(label: const Text('Last 14 days'), onPressed: () => _preset(14)),
                    ActionChip(label: const Text('Last 30 days'), onPressed: () => _preset(30)),
                    ActionChip(
                      label: const Text('All time'),
                      onPressed: () => setState(() => _range = null),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(_range == null
                      ? 'Custom period (all time)'
                      : '${formatDate(_range!.start)} - ${formatDate(_range!.end)}'),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _generate(),
                    icon: busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.bar_chart),
                    label: const Text('Generate report'),
                    style: FilledButton.styleFrom(
                      backgroundColor: c.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          reportAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                moneyErrorMessage(e, 'Failed to fetch taxes report'),
                style: const TextStyle(color: AppColors.error),
              ),
            ),
            data: (r) => r == null
                ? const SizedBox.shrink()
                : _ReportResult(report: r, c: c, onCopy: () => _copyCsv(r)),
          ),
          const SizedBox(height: 8),
          Text('Reports shared with you',
              style: TextStyle(
                  color: c.text, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 8),
          sharedAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => MoneyErrorView(
              message: moneyErrorMessage(e, 'Failed to load shared reports'),
              onRetry: () =>
                  ref.read(sharedTaxReportsControllerProvider.notifier).refresh(),
            ),
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('No reports have been shared with you yet.',
                        style: TextStyle(color: c.subtext, fontSize: 13)),
                  )
                : Column(
                    children: [
                      for (final s in list)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: c.border),
                          ),
                          child: ListTile(
                            title: Text(
                              s.startDate == null && s.endDate == null
                                  ? 'All time'
                                  : '${s.startDate != null ? formatDate(s.startDate) : 'Start'} - ${s.endDate != null ? formatDate(s.endDate) : 'Now'}',
                              style: TextStyle(
                                  color: c.text, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text('Shared ${formatDate(s.sharedAt)}',
                                style: TextStyle(color: c.subtext, fontSize: 12)),
                            trailing: TextButton(
                              onPressed: busy ? null : () => _openShared(s),
                              child: const Text('View'),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _ReportResult extends StatelessWidget {
  const _ReportResult({required this.report, required this.c, required this.onCopy});

  final TaxReportModel report;
  final MoneyColors c;
  final VoidCallback onCopy;

  static const _maxPreview = 50;

  @override
  Widget build(BuildContext context) {
    final t = report.totals;
    final preview = report.orders.take(_maxPreview).toList();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${report.orders.length} orders'
            '${report.restaurantName.isEmpty ? '' : ' - ${report.restaurantName}'}',
            style: TextStyle(color: c.text, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          _row('Item subtotal', formatInr(t.itemSubtotal)),
          _row('Commission deducted', formatInr(t.commission)),
          _row('Packing fee earned', formatInr(t.packagingFee)),
          _row('Order total', formatInr(t.total), bold: true),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy),
              label: const Text('Copy report as CSV'),
            ),
          ),
          if (preview.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('No orders found for the selected period',
                  style: TextStyle(color: c.subtext)),
            )
          else ...[
            const SizedBox(height: 8),
            Divider(color: c.border),
            for (final o in preview)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('#${o.orderId}',
                              style: TextStyle(
                                  color: c.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                          Text(formatDateTime(o.date),
                              style: TextStyle(color: c.subtext, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(formatInr(o.total),
                            style: TextStyle(
                                color: c.text,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        Text('Comm. ${formatInr(o.commission)}',
                            style: TextStyle(color: c.subtext, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            if (report.orders.length > _maxPreview)
              Text(
                'Showing first $_maxPreview orders. The CSV contains all ${report.orders.length}.',
                style: TextStyle(color: c.subtext, fontSize: 11),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: c.subtext, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: c.text,
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
        ],
      ),
    );
  }
}
