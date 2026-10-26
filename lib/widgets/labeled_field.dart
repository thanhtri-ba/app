import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Label + rounded text field used by the account screens (same look as the sign-in form).
class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final String? error;
  final bool obscure;
  final TextInputType? keyboard;
  final TextInputAction? action;
  final Iterable<String>? autofill;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmit;
  final bool enabled;

  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.error,
    this.obscure = false,
    this.keyboard,
    this.action,
    this.autofill,
    this.onChanged,
    this.onSubmit,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final hasErr = error != null;
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: 1.5),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: pal.text)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboard,
          textInputAction: action,
          autofillHints: autofill,
          autocorrect: false,
          enableSuggestions: !obscure,
          onChanged: onChanged,
          onSubmitted: onSubmit == null ? null : (_) => onSubmit!(),
          style: TextStyle(fontSize: 16, color: pal.text),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: pal.sec),
            filled: true,
            fillColor: pal.card,
            contentPadding: const EdgeInsets.all(16),
            enabledBorder: border(hasErr ? pal.dangerText : pal.line),
            focusedBorder: border(hasErr ? pal.dangerText : AppColors.accent),
            disabledBorder: border(pal.line),
            border: border(pal.line),
          ),
        ),
        if (hasErr)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(error!, style: TextStyle(fontSize: 13, color: pal.dangerText)),
          ),
      ],
    );
  }
}
