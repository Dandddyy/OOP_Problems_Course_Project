import 'package:flutter/material.dart';

import '../../core/constants/app_ui_tokens.dart';
import '../address_widgets.dart';
import '../dashed_route_line.dart';

class RoutePreviewAddresses extends StatelessWidget {
  static const originIconSize = 22.0;
  static const destinationIconSize = 26.0;

  final Widget origin;
  final Widget destination;

  const RoutePreviewAddresses({
    super.key,
    required this.origin,
    required this.destination,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppDimens.gapXs,
          bottom: AppDimens.gapSm,
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                origin,
                Container(
                  height: AppDimens.dividerThickness,
                  color: AppColors.borderMuted,
                  margin: const EdgeInsetsDirectional.only(
                    start: 2 * AppDimens.gapLg + AddressRow.iconSlotWidth,
                    end: AppDimens.gapLg,
                  ),
                ),
                destination,
              ],
            ),
            const PositionedDirectional(
              start:
                  AppDimens.gapLg +
                  (AddressRow.iconSlotWidth - dashedRouteLineWidth) / 2,
              top: (AppDimens.rowHeight + originIconSize) / 2 + AppDimens.gapXs,
              bottom:
                  (AppDimens.rowHeight + destinationIconSize) / 2 +
                  AppDimens.gapXs,
              width: dashedRouteLineWidth,
              child: CustomPaint(painter: _AddressConnectorPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressConnectorPainter extends CustomPainter {
  const _AddressConnectorPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.width / 2;
    paintDashedRouteLine(
      canvas,
      Offset(center, 0),
      Offset(center, size.height),
    );
  }

  @override
  bool shouldRepaint(_AddressConnectorPainter oldDelegate) => false;
}
