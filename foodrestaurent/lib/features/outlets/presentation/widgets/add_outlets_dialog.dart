import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/outlets/presentation/controllers/outlets_controller.dart';

const _maxOutletsPerRequest = 20;

/// Collects one or more outlet names and creates them in a single request.
/// Returns `true` when at least one outlet was created.
Future<bool> showAddOutletsDialog(BuildContext context) async {
  final created = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _AddOutletsDialog(),
  );
  return created == true;
}

class _AddOutletsDialog extends ConsumerStatefulWidget {
  const _AddOutletsDialog();

  @override
  ConsumerState<_AddOutletsDialog> createState() => _AddOutletsDialogState();
}

class _AddOutletsDialogState extends ConsumerState<_AddOutletsDialog> {
  final List<TextEditingController> _controllers = [TextEditingController()];
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _names => _controllers
      .map((c) => c.text.trim())
      .where((n) => n.isNotEmpty)
      .toList();

  void _addField() {
    if (_controllers.length >= _maxOutletsPerRequest) return;
    setState(() => _controllers.add(TextEditingController()));
  }

  void _removeField(int index) {
    final removed = _controllers.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _create() async {
    final names = _names;
    if (names.isEmpty || _busy) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(outletsControllerProvider.notifier)
          .addOutlets(names);
      for (final failure in result.failed) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('${failure.name}: ${failure.message}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      if (result.created.isNotEmpty) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${result.created.length} outlet(s) added. Complete each one\'s onboarding.',
            ),
          ),
        );
        if (mounted) navigator.pop(true);
        return;
      }
      if (mounted) setState(() => _busy = false);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not add outlets',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _names.length;
    return AlertDialog(
      title: const Text('Add outlets'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Owner details, PAN, bank and zone carry over from your account. '
                'Each outlet is submitted for review on its own, so you only '
                'enter its location, menu and documents.',
                style: TextStyle(fontSize: 12.5, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < _controllers.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controllers[i],
                          enabled: !_busy,
                          textCapitalization: TextCapitalization.words,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Outlet ${i + 1} name',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_controllers.length > 1)
                        IconButton(
                          onPressed: _busy ? null : () => _removeField(i),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove outlet',
                        ),
                    ],
                  ),
                ),
              TextButton.icon(
                onPressed: (_busy || _controllers.length >= _maxOutletsPerRequest)
                    ? null
                    : _addField,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add another outlet'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: (_busy || count == 0) ? null : _create,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  count == 0
                      ? 'Create'
                      : 'Create $count outlet${count == 1 ? '' : 's'}',
                ),
        ),
      ],
    );
  }
}
