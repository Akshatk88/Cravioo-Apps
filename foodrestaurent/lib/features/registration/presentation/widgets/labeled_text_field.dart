import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_user_application/config/theme/app_colors.dart';

/// The shared field chrome used across all 4 registration steps: a bold
/// label, a white rounded container, optional required-asterisk and helper
/// text.
class LabeledTextField extends StatelessWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.required = false,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.enabled = true,
    this.prefixText,
    this.suffixIcon,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool required;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final bool enabled;
  final String? prefixText;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
            children: [
              TextSpan(text: label),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.error),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF3F3F3),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.black12),
          ),
          child: TextField(
            controller: controller,
            enabled: enabled,
            readOnly: readOnly,
            onTap: onTap,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
            onChanged: onChanged,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? Colors.white : const Color(0xFFF3F3F3),
              border: InputBorder.none,
              focusedBorder: InputBorder.none,
              enabledBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              hintText: hint,
              hintStyle: const TextStyle(fontSize: 14, color: Colors.black38),
              prefixText: prefixText,
              prefixStyle: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}
