import 'package:flutter/material.dart';

class TextFieldWidget extends StatelessWidget {
  final TextEditingController controller;
  final Color color;
  final String hintText;
  final IconData? prefixIcon;
  final bool showClearButton;
  final String? Function(String?)? validator;
  final void Function(String?)? onSaved;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool autofocus;
  final int maxLines;
  final String? semanticLabel;

  const TextFieldWidget({
    super.key,
    required this.controller,
    required this.color,
    required this.hintText,
    this.prefixIcon,
    this.showClearButton = true,
    this.validator,
    this.onSaved,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.done,
    this.autofocus = false,
    this.maxLines = 1,
    this.semanticLabel,
  });

  String? _defaultValidator(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return '$hintText is required';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? hintText,
      textField: true,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, value, __) {
          final hasText = value.text.isNotEmpty;
          return TextFormField(
            controller: controller,
            autofocus: autofocus,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            maxLines: maxLines,
            cursorColor: color,
            enableSuggestions: true,
            autocorrect: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              hintText: hintText,
              hintStyle: const TextStyle(color: Colors.black26),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: color) : null,
              suffixIcon: showClearButton && hasText
                  ? IconButton(
                onPressed: () {
                  controller.clear();
                  // remove focus after clearing
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
