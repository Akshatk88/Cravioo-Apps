import 'package:flutter/material.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/features/registration/presentation/widgets/labeled_text_field.dart';

class EditFieldSpec {
  const EditFieldSpec({
    required this.key,
    required this.label,
    required this.initialValue,
    this.keyboardType,
    this.maxLines = 1,
    this.hint,
  });

  final String key;
  final String label;
  final String initialValue;
  final TextInputType? keyboardType;
  final int maxLines;
  final String? hint;
}

/// A generic bottom-sheet edit form shared by Outlet Info's per-card "Edit"
/// links — avoids building a bespoke edit screen for every profile field
/// group. Returns `{fieldKey: newValue}` on save, or `null` if cancelled.
Future<Map<String, String>?> showEditFieldSheet({
  required BuildContext context,
  required String title,
  required List<EditFieldSpec> fields,
}) {
  return showModalBottomSheet<Map<String, String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _EditFieldSheetBody(title: title, fields: fields),
  );
}

class _EditFieldSheetBody extends StatefulWidget {
  const _EditFieldSheetBody({required this.title, required this.fields});

  final String title;
  final List<EditFieldSpec> fields;

  @override
  State<_EditFieldSheetBody> createState() => _EditFieldSheetBodyState();
}

class _EditFieldSheetBodyState extends State<_EditFieldSheetBody> {
  late final _controllers = {
    for (final field in widget.fields)
      field.key: TextEditingController(text: field.initialValue),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black87),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final field in widget.fields) ...[
              LabeledTextField(
                label: field.label,
                controller: _controllers[field.key]!,
                keyboardType: field.keyboardType,
                maxLines: field.maxLines,
                hint: field.hint,
              ),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  final result = {
                    for (final entry in _controllers.entries)
                      entry.key: entry.value.text.trim(),
                  };
                  Navigator.pop(context, result);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Save',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
