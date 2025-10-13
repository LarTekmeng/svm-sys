import 'package:flutter/material.dart';

class EmailField extends StatelessWidget {
  final TextEditingController controller;
  final Color color;
  final String hintText;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;
  final bool autofocus;
  final bool showClearButton;
  final TextInputAction textInputAction;
  final String? semanticLabel;

  const EmailField({
    Key? key,
    required this.controller,
    required this.color,
    required this.hintText,
    this.validator,
    this.onSaved,
    this.autofocus = false,
    this.showClearButton = true,
    this.textInputAction = TextInputAction.next,
    this.semanticLabel,
  }) : super(key: key);

  String? _defaultValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Enter email';
    // Reasonable, not-overly-strict email regex
    final regex = RegExp(r'^[\w\-.+]+@([\w-]+\.)+[\w-]{2,}$');
    return regex.hasMatch(v.trim()) ? null : 'Invalid email';
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? 'Email field',
      textField: true,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, value, __) {
          final hasText = value.text.isNotEmpty;
          return TextFormField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: TextInputType.emailAddress,
            textInputAction: textInputAction,
            cursorColor: color,
            autofillHints: const [AutofillHints.email],
            enableSuggestions: true,
            autocorrect: false,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.black26),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              prefixIcon: Icon(Icons.email_outlined, color: color),
              suffixIcon: showClearButton && hasText
                  ? IconButton(
                onPressed: () {
                  controller.clear();
                  // ensure UI updates/focus is handled by caller's form state if needed
                  FocusScope.of(context).requestFocus(FocusNode());
                },
                tooltip: 'Clear',
                icon: const Icon(Icons.clear),
              )
                  : null,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: color, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: color, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
              errorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.red, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            validator: validator ?? _defaultValidator,
            onSaved: onSaved,
          );
        },
      ),
    );
  }
}
