import 'package:flutter/material.dart';
import 'dart:ui';
import '../constants/app_theme.dart';

/// Reusable Zen-style input field with glassmorphic design
class ZenInputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final FocusNode? focusNode;
  final int maxLines;
  final TextInputType? keyboardType;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;

  const ZenInputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.maxLines = 1,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusXl),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingL,
            vertical: AppTheme.spacingS,
          ),
          decoration: AppTheme.glassDecoration(
            backgroundColor: AppTheme.glassColor,
            borderColor: AppTheme.borderMedium,
          ),
          child: Row(
            crossAxisAlignment: maxLines > 1
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: maxLines > 1 ? 12.0 : 0),
                child: Icon(icon, color: Colors.white54, size: 20),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: maxLines,
                  keyboardType: keyboardType,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textHint,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: () {
                      controller.clear();
                      if (onChanged != null) onChanged!('');
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8.0),
                      child: Icon(Icons.close, color: Colors.white38, size: 18),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
