import 'package:flutter/material.dart';
import 'dart:ui';
import '../constants/app_theme.dart';

/// Reusable glassmorphic card with backdrop blur
class GlassCard extends StatelessWidget {
  final Widget child;
  final double? borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? blurStrength;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
    this.padding,
    this.onTap,
    this.blurStrength,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusXxl),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurStrength ?? AppTheme.blurLight,
          sigmaY: blurStrength ?? AppTheme.blurLight,
        ),
        child: Container(
          padding: padding ?? const EdgeInsets.all(AppTheme.spacingL),
          decoration: AppTheme.glassDecoration(
            borderRadius: borderRadius ?? AppTheme.radiusXxl,
            backgroundColor: backgroundColor ?? AppTheme.glassColor,
            borderColor: borderColor ?? AppTheme.borderLight,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius ?? AppTheme.radiusXxl),
        child: content,
      );
    }

    return content;
  }
}
