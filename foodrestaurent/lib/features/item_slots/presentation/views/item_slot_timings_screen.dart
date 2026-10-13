import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/item_slots/domain/item_slot_model.dart';
import 'package:food_user_application/features/item_slots/presentation/controllers/item_slot_controller.dart';

String _err(Object e) =>
    e is ApiException ? e.message : 'Something went wrong. Please try again.';

class ItemSlotTimingsScreen extends ConsumerWidget {
  const ItemSlotTimingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final card = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final async = ref.watch(itemSlotControllerProvider);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        foregroundColor: textPrimary,
        title: Text(
          'Item slot timings',
          style: TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryButton,
        foregroundColor: Colors.white,
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add slot'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(itemSlotControllerProvider.notifier).refresh(),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 120),
              Icon(Icons.error_outline, size: 48, color: textSecondary),
              const SizedBox(height: 12),
              Center(
                child: Text(_err(e), style: TextStyle(color: textSecondary)),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () =>
                      ref.read(itemSlotControllerProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ),
          data: (slots) {
            if (slots.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 120),
                  Icon(Icons.schedule, size: 56, color: textSecondary),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'No slots created yet',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Add slots like Breakfast, Lunch or Dinner and assign them to menu items to control when customers can see them.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: slots.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final s = slots[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.schedule,
                          color: AppColors.primaryButton,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${ItemSlotModel.display(s.startTime)} - ${ItemSlotModel.display(s.endTime)}',
                              style: TextStyle(color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        icon: Icon(Icons.edit_outlined, color: textSecondary),
                        onPressed: () => _openForm(context, slot: s),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _confirmDelete(context, ref, s),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ItemSlotModel slot,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete slot?'),
        content: Text(
          'Delete "${slot.name}"? Items linked to this slot will become always available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final unlinked =
          await ref.read(itemSlotControllerProvider.notifier).delete(slot.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            unlinked > 0
                ? 'Slot deleted. $unlinked linked item(s) are now always available.'
                : 'Slot deleted',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  Future<void> _openForm(BuildContext context, {ItemSlotModel? slot}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => _SlotForm(slot: slot),
    );
  }
}

class _SlotForm extends ConsumerStatefulWidget {
  const _SlotForm({this.slot});
  final ItemSlotModel? slot;

  @override
  ConsumerState<_SlotForm> createState() => _SlotFormState();
}

class _SlotFormState extends ConsumerState<_SlotForm> {
  late final TextEditingController _name;
  String _start = '';
  String _end = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.slot?.name ?? '');
    _start = widget.slot?.startTime ?? '';
    _end = widget.slot?.endTime ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(bool isStart) async {
    final current = isStart ? _start : _end;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final h = picked.hour.toString().padLeft(2, '0');
    final m = picked.minute.toString().padLeft(2, '0');
    setState(() {
      if (isStart) {
        _start = '$h:$m';
      } else {
        _end = '$h:$m';
      }
    });
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final name = _name.text.trim();
    String? problem;
    if (name.isEmpty) {
      problem = 'Slot name is required';
    } else if (_start.isEmpty) {
      problem = 'Start time is required';
    } else if (_end.isEmpty) {
      problem = 'End time is required';
    }
    if (problem != null) {
      messenger.showSnackBar(SnackBar(content: Text(problem)));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(itemSlotControllerProvider.notifier)
          .save(
            id: widget.slot?.id,
            name: name,
            startTime: _start,
            endTime: _end,
          );
      nav.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(widget.slot == null ? 'Slot created' : 'Slot updated'),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(_err(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.slot == null ? 'Create slot' : 'Edit slot',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Slot name',
              hintText: 'Breakfast',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(true),
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    _start.isEmpty
                        ? 'Start time'
                        : ItemSlotModel.display(_start),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick(false),
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    _end.isEmpty ? 'End time' : ItemSlotModel.display(_end),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryButton,
              ),
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? 'Saving...'
                    : widget.slot == null
                    ? 'Create slot'
                    : 'Update slot',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
