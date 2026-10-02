import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/dining/domain/dining_table_model.dart';
import 'package:food_user_application/features/dining/presentation/controllers/dining_tables_controller.dart';

const List<Map<String, String>> kTableSections = [
  {'id': 'all', 'label': 'All'},
  {'id': 'indoor', 'label': 'Indoor'},
  {'id': 'outdoor', 'label': 'Outdoor'},
  {'id': 'rooftop', 'label': 'Rooftop'},
  {'id': 'balcony', 'label': 'Balcony'},
  {'id': 'bar', 'label': 'Bar'},
  {'id': 'private', 'label': 'Private Dining'},
];

class DiningTablesScreen extends ConsumerStatefulWidget {
  const DiningTablesScreen({super.key});

  @override
  ConsumerState<DiningTablesScreen> createState() => _DiningTablesScreenState();
}

class _DiningTablesScreenState extends ConsumerState<DiningTablesScreen> {
  void _openTableModal({DiningTableModel? table}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TableFormBottomSheet(
        table: table,
        onSave: (name, seats, section, note, isActive) async {
          final messenger = ScaffoldMessenger.of(context);
          final nav = Navigator.of(ctx);
          final notifier = ref.read(diningTablesControllerProvider.notifier);
          bool ok;
          if (table == null) {
            ok = await notifier.createTable(
              name: name,
              seats: seats,
              section: section,
              note: note,
              isActive: isActive,
            );
          } else {
            ok = await notifier.updateTable(
              table.id,
              name: name,
              seats: seats,
              section: section,
              note: note,
              isActive: isActive,
            );
          }
          if (ok) {
            nav.pop();
            messenger.showSnackBar(
              SnackBar(
                content: Text(table == null ? 'Table added successfully' : 'Table updated'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(DiningTableModel table) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Table?'),
        content: Text('Are you sure you want to delete "${table.name}"? Active bookings may be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await ref.read(diningTablesControllerProvider.notifier).deleteTable(table.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Table deleted' : 'Failed to delete table'),
                    backgroundColor: ok ? AppColors.success : AppColors.error,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablesAsync = ref.watch(diningTablesControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.cardDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);
    final textSecondary = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Tables & Seating',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => ref.read(diningTablesControllerProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTableModal(),
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Table',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: tablesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              Text(
                'Failed to load tables',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(diningTablesControllerProvider.notifier).refresh(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (state) {
          final summary = state.summary;
          final tables = state.filteredTables;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.read(diningTablesControllerProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              children: [
                // 1. Summary Cards (Active Tables, Total Bookable Seats)
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active Tables',
                              style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              summary.tables.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bookable Seats',
                              style: TextStyle(fontSize: 12, color: textSecondary, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              summary.seats.toString(),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 2. Section Filter Tabs
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kTableSections.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final sec = kTableSections[index];
                      final isSelected = state.activeFilter == sec['id'];
                      return ChoiceChip(
                        label: Text(sec['label']!),
                        selected: isSelected,
                        onSelected: (_) {
                          ref.read(diningTablesControllerProvider.notifier).setFilter(sec['id']!);
                        },
                        selectedColor: AppColors.primary,
                        backgroundColor: cardBg,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF374151)),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? AppColors.primary : borderColor),
                        ),
                        showCheckmark: false,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Table List or Empty State
                if (tables.isEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.table_bar_rounded, size: 36, color: AppColors.primaryDeep),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Tables Found',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          state.activeFilter == 'all'
                              ? 'Add your restaurant tables so guests can reserve seating.'
                              : 'No tables added in the "${state.activeFilter}" section yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => _openTableModal(),
                          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                          label: const Text('Add Table', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...tables.map((table) => _buildTableCard(table, isDark, cardBg, borderColor, textSecondary)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableCard(
    DiningTableModel table,
    bool isDark,
    Color cardBg,
    Color borderColor,
    Color textSecondary,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Seats Badge
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: table.isActive ? AppColors.primaryTint : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  table.seats.toString(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: table.isActive ? AppColors.primaryDeep : const Color(0xFF6B7280),
                  ),
                ),
                Text(
                  'seats',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: table.isActive ? AppColors.primaryDeep : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        table.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        table.sectionLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                        ),
                      ),
                    ),
                  ],
                ),
                if (table.note.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    table.note,
                    style: TextStyle(fontSize: 12, color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Active Switch & Action Buttons
          Switch.adaptive(
            value: table.isActive,
            activeTrackColor: AppColors.primary,
            onChanged: (_) {
              ref.read(diningTablesControllerProvider.notifier).toggleActive(table);
            },
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _openTableModal(table: table),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            color: AppColors.error,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => _confirmDelete(table),
          ),
        ],
      ),
    );
  }
}

class _TableFormBottomSheet extends StatefulWidget {
  final DiningTableModel? table;
  final Future<void> Function(
    String name,
    int seats,
    String section,
    String note,
    bool isActive,
  ) onSave;

  const _TableFormBottomSheet({
    this.table,
    required this.onSave,
  });

  @override
  State<_TableFormBottomSheet> createState() => _TableFormBottomSheetState();
}

class _TableFormBottomSheetState extends State<_TableFormBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _seatsController;
  late TextEditingController _noteController;
  late String _section;
  late bool _isActive;
  bool _isSaving = false;

  final List<Map<String, String>> _sectionOptions = [
    {'id': 'indoor', 'label': 'Indoor'},
    {'id': 'outdoor', 'label': 'Outdoor'},
    {'id': 'rooftop', 'label': 'Rooftop'},
    {'id': 'balcony', 'label': 'Balcony'},
    {'id': 'bar', 'label': 'Bar'},
    {'id': 'private', 'label': 'Private Dining'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.table?.name ?? '');
    _seatsController = TextEditingController(text: widget.table?.seats.toString() ?? '4');
    _noteController = TextEditingController(text: widget.table?.note ?? '');
    _section = widget.table?.section ?? 'indoor';
    _isActive = widget.table?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _seatsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final seats = int.tryParse(_seatsController.text.trim()) ?? 4;
    final note = _noteController.text.trim();

    setState(() => _isSaving = true);
    await widget.onSave(name, seats, _section, note, _isActive);
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.surfaceDark : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.table == null ? 'Add Table' : 'Edit Table',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Name Field
              Text(
                'Table Name / Number *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'e.g., Table 1, Window Booth A',
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter table name' : null,
              ),
              const SizedBox(height: 14),

              // Seats Field
              Text(
                'Number of Seats *',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _seatsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'e.g., 2, 4, 6',
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) {
                  final n = int.tryParse(val?.trim() ?? '');
                  if (n == null || n < 1) return 'Must be at least 1 seat';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Section Dropdown
              Text(
                'Section',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _section,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: _sectionOptions.map((opt) {
                  return DropdownMenuItem(
                    value: opt['id'],
                    child: Text(opt['label']!),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _section = val);
                },
              ),
              const SizedBox(height: 14),

              // Note Field
              Text(
                'Notes (Optional)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF4B5563)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: 'e.g., Near fountain, high-top chairs',
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceVariantDark : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Active Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active for Bookings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Turn off to reserve for walk-ins only',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : const Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  Switch.adaptive(
                    value: _isActive,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          widget.table == null ? 'Add Table' : 'Save Changes',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
