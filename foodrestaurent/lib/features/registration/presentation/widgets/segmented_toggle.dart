import 'package:flutter/material.dart';
import 'package:food_user_application/config/theme/app_colors.dart';

class SegmentedOption<T> {
  const SegmentedOption(this.value, this.label);
  final T value;
  final String label;
}

/// The pill-shaped Yes/No (or Savings/Current) selector used in the
/// registration steps — matches the reference screenshot's
/// "Yes, Pure Veg" / "No, Mixed Menu" control.
class SegmentedToggle<T> extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<SegmentedOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((option) {
        final isSelected = option.value == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: option == options.last ? 0 : 10),
            child: GestureDetector(
              onTap: () => onChanged(option.value),
              child: Container(
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.black12,
                  ),
                ),
                child: Text(
                  option.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
