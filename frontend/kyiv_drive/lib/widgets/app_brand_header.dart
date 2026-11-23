import 'package:flutter/material.dart';

import '../core/constants/app_ui_tokens.dart';

class AppBrandHeader extends StatelessWidget {
  final Color color;

  const AppBrandHeader({super.key, this.color = AppColors.passenger});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: AppRadius.compactControlBr,
        ),
        child: Icon(Icons.near_me_rounded, color: color, size: 40),
      ),
      const SizedBox(height: AppDimens.gapXl),
      const Text('KyivDrive', style: AppText.appTitle),
    ],
  );
}
