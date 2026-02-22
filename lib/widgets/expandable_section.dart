import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

/// Reusable expandable section with smooth animation
class ExpandableSection extends StatelessWidget {
  final bool isExpanded;
  final String title;
  final IconData icon;
  final VoidCallback onToggle;
  final Widget child;
  final Duration? duration;

  const ExpandableSection({
    super.key,
    required this.isExpanded,
    required this.title,
    required this.icon,
    required this.onToggle,
    required this.child,
    this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toggle Button
        InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingL,
              vertical: AppTheme.spacingM,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusL),
              border: Border.all(color: AppTheme.borderMedium),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.white54, size: 20),
                    const SizedBox(width: AppTheme.spacingS),
                    Text(
                      title,
                      style: AppTheme.bodyMedium.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),

        // Expandable Content
        AnimatedSize(
          duration: duration ?? AppTheme.animationMedium,
          curve: Curves.easeInOut,
          child: isExpanded
              ? Column(
                  children: [
                    const SizedBox(height: AppTheme.spacingL),
                    child,
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
