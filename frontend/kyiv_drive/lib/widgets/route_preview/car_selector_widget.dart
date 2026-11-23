import 'package:flutter/material.dart';
import '../../core/constants/app_ui_tokens.dart';
import '../../models/car_color.dart';
import '../../models/car_models.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/pluralization_formatters.dart';
import '../address_widgets.dart';
import '../animated_field_icon.dart';
import '../animated_touch_templates.dart';
import '../animated_value_text.dart';
import '../shimmer_placeholder.dart';

class CarSelectorWidget extends StatefulWidget {
  static const int maxCars = 3;

  final bool isLoading;
  final bool showSkeleton;
  final List<CarResponseModel> cars;
  final String? selectedCarId;
  final ValueChanged<String> onCarSelected;
  final VoidCallback onAddCarTap;
  final Function(String) onDeleteCarTap;
  final Function(String)? onEditCarTap;
  final Set<String> deletingCarIds;
  final bool hasError;

  const CarSelectorWidget({
    super.key,
    required this.isLoading,
    this.showSkeleton = false,
    required this.cars,
    required this.selectedCarId,
    required this.onCarSelected,
    required this.onAddCarTap,
    required this.onDeleteCarTap,
    this.onEditCarTap,
    this.deletingCarIds = const <String>{},
    this.hasError = false,
  });

  @override
  State<CarSelectorWidget> createState() => _CarSelectorWidgetState();
}

class _CarSelectorWidgetState extends State<CarSelectorWidget> {
  static const Duration _animationDuration = Duration(milliseconds: 300);
  // A symmetric curve keeps the indicator aligned with a row animated in
  // reverse while preserving the project's cubic ease-in-out motion.
  static const Curve _animationCurve = Cubic(0.65, 0, 0.35, 1);
  static const double _carItemStride =
      AppDimens.rowHeight + AppDimens.dividerThickness;

  GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  late List<CarResponseModel> _cars;

  Duration get _selectionDuration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : _animationDuration;

  @override
  void initState() {
    super.initState();
    _cars = List<CarResponseModel>.of(widget.cars);
  }

  @override
  void didUpdateWidget(covariant CarSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isLoading ||
        oldWidget.isLoading ||
        widget.showSkeleton ||
        oldWidget.showSkeleton) {
      _resetCars(widget.cars);
      return;
    }

    _syncCars(widget.cars);
  }

  void _resetCars(List<CarResponseModel> cars) {
    _cars = List<CarResponseModel>.of(cars);
    _listKey = GlobalKey<AnimatedListState>();
  }

  void _syncCars(List<CarResponseModel> incomingCars) {
    final listState = _listKey.currentState;
    if (listState == null) {
      _resetCars(incomingCars);
      return;
    }

    final incomingIds = incomingCars.map((car) => car.id).toSet();

    for (int index = _cars.length - 1; index >= 0; index--) {
      final car = _cars[index];
      if (incomingIds.contains(car.id)) continue;

      final hadDivider =
          index < _cars.length - 1 || _cars.length < CarSelectorWidget.maxCars;
      _cars.removeAt(index);
      listState.removeItem(
        index,
        (context, animation) => _buildAnimatedCarEntry(
          context,
          car: car,
          animation: animation,
          showDivider: hadDivider,
          forceDisabled: true,
          isRemoving: true,
        ),
        duration: _animationDuration,
      );
    }

    for (int index = 0; index < incomingCars.length; index++) {
      final car = incomingCars[index];
      if (_cars.any((currentCar) => currentCar.id == car.id)) continue;

      _cars.insert(index, car);
      listState.insertItem(index, duration: _animationDuration);
    }

    final currentIds = _cars.map((car) => car.id).toList();
    final nextIds = incomingCars.map((car) => car.id).toList();
    if (!_sameIds(currentIds, nextIds)) {
      _resetCars(incomingCars);
      return;
    }

    final incomingById = {for (final car in incomingCars) car.id: car};
    for (int index = 0; index < _cars.length; index++) {
      _cars[index] = incomingById[_cars[index].id]!;
    }
  }

  bool _sameIds(List<String> first, List<String> second) {
    if (first.length != second.length) return false;

    for (int index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }

    return true;
  }

  String _formatPlateNumber(String rawPlate) {
    final standardPlateRegExp = RegExp(
      r'^([A-ZА-ЯІЇЄҐ]{2})(\d{4})([A-ZА-ЯІЇЄҐ]{2})$',
    );
    final match = standardPlateRegExp.firstMatch(rawPlate.replaceAll(' ', ''));
    if (match != null) {
      return '${match.group(1)} ${match.group(2)} ${match.group(3)}';
    }
    return rawPlate;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppDurations.fieldState,
      foregroundDecoration: BoxDecoration(
        borderRadius: AppRadius.formControlBr,
        border: Border.all(
          color: widget.hasError
              ? AppColors.danger.withValues(alpha: 0.8)
              : Colors.transparent,
          width: AppDimens.focusBorderWidth,
        ),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.formControlBr,
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.showSkeleton
          ? _buildLoadingState(context)
          : AnimatedSize(
              duration: _animationDuration,
              curve: _animationCurve,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: _animationDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.topCenter,
                    children: [...previousChildren, ?currentChild],
                  );
                },
                child: widget.isLoading
                    ? KeyedSubtree(
                        key: const ValueKey('car-selector-loading'),
                        child: _buildLoadingState(context),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('car-selector-content'),
                        child: _buildSelector(context),
                      ),
              ),
            ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final rowCount = widget.isLoading ? 2 : widget.cars.length;
    final canAddMore = rowCount < CarSelectorWidget.maxCars;
    return Column(
      children: [
        for (var index = 0; index < rowCount; index++) ...[
          _buildLoadingCarRow(
            selected: widget.isLoading
                ? index == 0
                : widget.cars[index].id == widget.selectedCarId,
          ),
          if (index < rowCount - 1 || canAddMore)
            Container(
              height: AppDimens.dividerThickness,
              color: AppColors.borderMuted,
            ),
        ],
        if (rowCount == 0)
          _buildEmptyState(context, showSkeleton: true)
        else if (canAddMore)
          _buildAddMoreButton(context, showSkeleton: true),
      ],
    );
  }

  Widget _buildLoadingCarRow({required bool selected}) {
    return SizedBox(
      height: AppDimens.rowHeight,
      child: Row(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                left: AppDimens.gapLg,
                right: AppDimens.gapSm,
              ),
              child: Row(
                children: [
                  ShimmerBlock(width: 12, height: 12, borderRadius: 6),
                  SizedBox(width: AppDimens.gapMd),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerPlaceholder(
                          child: SizedBox(
                            width: 120,
                            child: Text(
                              ' ',
                              style: AppText.listTitle,
                              maxLines: 1,
                            ),
                          ),
                        ),
                        SizedBox(height: AppDimens.gapXs),
                        ShimmerPlaceholder(
                          child: SizedBox(
                            width: 150,
                            child: Text(
                              ' ',
                              style: AppText.listSubtitle,
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (selected)
            const SizedBox(
              width: 96,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ShimmerBlock(width: 22, height: 22, borderRadius: 6),
                  SizedBox(width: 20),
                  ShimmerBlock(width: 22, height: 22, borderRadius: 6),
                  SizedBox(width: 24),
                ],
              ),
            )
          else
            const SizedBox(width: AppDimens.gapLg),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {bool showSkeleton = false}) {
    final label = Text(
      AppLocalizations.of(context)!.addCar,
      style: AppText.compactButton.copyWith(fontWeight: FontWeight.bold),
    );
    return AnimatedTouchItem(
      onTap: showSkeleton ? null : widget.onAddCarTap,
      normalColor: Colors.transparent,
      pressedColor: Colors.transparent,
      pressedScale: 0.97,
      pressedOpacity: 0.6,
      borderRadius: AppRadius.formControlBr,
      child: SizedBox(
        height: AppDimens.buttonHeight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showSkeleton)
              const ShimmerBlock(width: 24, height: 24, borderRadius: 12)
            else
              AnimatedFieldIcon(
                color: widget.hasError ? AppColors.danger : Colors.white70,
                builder: (color) => Icon(
                  Icons.add_circle_outline_rounded,
                  color: color,
                  size: 24,
                ),
              ),
            const SizedBox(width: AppDimens.gapMd),
            showSkeleton ? ShimmerPlaceholder(child: label) : label,
          ],
        ),
      ),
    );
  }

  Widget _buildSelector(BuildContext context) {
    final canAddMore = _cars.length < CarSelectorWidget.maxCars;
    final selectedIndex = _cars.indexWhere(
      (car) => car.id == widget.selectedCarId,
    );
    final isSelectedCarDeleting =
        widget.selectedCarId != null &&
        widget.deletingCarIds.contains(widget.selectedCarId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            AnimatedList(
              key: _listKey,
              initialItemCount: _cars.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemBuilder: (context, index, animation) {
                return _buildAnimatedCarEntry(
                  context,
                  car: _cars[index],
                  animation: animation,
                  showDivider: index < _cars.length - 1 || canAddMore,
                );
              },
            ),
            if (selectedIndex >= 0)
              AnimatedPositioned(
                duration: _selectionDuration,
                curve: _animationCurve,
                left: 0,
                top: selectedIndex * _carItemStride,
                width: 4,
                height: AppDimens.rowHeight,
                child: AnimatedOpacity(
                  key: const ValueKey('car-selection-indicator'),
                  duration: _selectionDuration,
                  curve: _animationCurve,
                  opacity: isSelectedCarDeleting ? 0 : 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.driverAccent,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        _buildTrailingAction(context, canAddMore: canAddMore),
      ],
    );
  }

  Widget _buildAnimatedCarEntry(
    BuildContext context, {
    required CarResponseModel car,
    required Animation<double> animation,
    required bool showDivider,
    bool forceDisabled = false,
    bool isRemoving = false,
  }) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: _animationCurve,
      reverseCurve: _animationCurve,
    );

    return KeyedSubtree(
      key: ValueKey(isRemoving ? 'removing-${car.id}' : car.id),
      child: ClipRect(
        child: SizeTransition(
          sizeFactor: curvedAnimation,
          alignment: AlignmentDirectional.topStart,
          child: FadeTransition(
            opacity: curvedAnimation,
            child: Column(
              children: [
                _buildCarItem(context, car, forceDisabled: forceDisabled),
                if (showDivider)
                  Container(
                    height: AppDimens.dividerThickness,
                    color: AppColors.borderMuted,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrailingAction(
    BuildContext context, {
    required bool canAddMore,
  }) {
    final Widget child;
    if (_cars.isEmpty) {
      child = KeyedSubtree(
        key: const ValueKey('empty-add-car'),
        child: _buildEmptyState(context),
      );
    } else if (canAddMore) {
      child = KeyedSubtree(
        key: const ValueKey('add-more-car'),
        child: _buildAddMoreButton(context),
      );
    } else {
      child = const SizedBox.shrink(key: ValueKey('cars-limit-reached'));
    }

    return AnimatedSwitcher(
      duration: _animationDuration,
      switchInCurve: _animationCurve,
      switchOutCurve: _animationCurve,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [...previousChildren, ?currentChild],
        );
      },
      transitionBuilder: (child, animation) {
        return ClipRect(
          child: SizeTransition(
            sizeFactor: animation,
            alignment: AlignmentDirectional.topStart,
            child: FadeTransition(opacity: animation, child: child),
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildCarItem(
    BuildContext context,
    CarResponseModel car, {
    bool forceDisabled = false,
  }) {
    final isSelected = car.id == widget.selectedCarId;
    final isDeleting = forceDisabled || widget.deletingCarIds.contains(car.id);
    final showActionsArea = isSelected || forceDisabled;
    final stateDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppDurations.buttonState;

    final uiColor = car.color.uiColor;
    final formattedPlate = _formatPlateNumber(car.plateNumber);
    final seats = PluralizationService.getSeats(context, car.passengerCapacity);
    final colorName = car.color.localizedName(context);

    return AbsorbPointer(
      absorbing: isDeleting,
      child: AnimatedOpacity(
        key: ValueKey('car-content-${car.id}'),
        duration: _selectionDuration,
        curve: _animationCurve,
        opacity: isDeleting || !isSelected ? 0.45 : 1,
        child: SizedBox(
          height: AppDimens.rowHeight,
          child: Row(
            children: [
              Expanded(
                child: AnimatedTouchItem(
                  onTap: () => widget.onCarSelected(car.id),
                  normalColor: Colors.transparent,
                  pressedColor: Colors.transparent,
                  pressedScale: 0.97,
                  borderRadius: BorderRadius.zero,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: uiColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24, width: 1),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedValueText(
                                '${car.brandName} '
                                '${car.modelName}',
                                style: AppText.listTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              AnimatedValueText(
                                '$formattedPlate • $seats • $colorName',
                                style: AppText.listSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOutCubic,
                width: showActionsArea ? 96 : 16,
                height: AppDimens.rowHeight,
                alignment: Alignment.centerRight,
                child: AnimatedSwitcher(
                  duration: stateDuration,
                  reverseDuration: stateDuration,
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  child: isDeleting
                      ? const SizedBox(
                          key: ValueKey('deleting'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('actions'),
                          child: _buildCarActions(
                            car: car,
                            isSelected: isSelected,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarActions({
    required CarResponseModel car,
    required bool isSelected,
  }) {
    return AnimatedOpacity(
      duration: Duration(milliseconds: isSelected ? 250 : 150),
      opacity: isSelected ? 1 : 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        reverse: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedTouchItem(
              onTap: widget.onEditCarTap == null
                  ? null
                  : () => widget.onEditCarTap!(car.id),
              normalColor: Colors.transparent,
              pressedColor: Colors.white.withValues(alpha: 0.05),
              pressedScale: 0.95,
              borderRadius: AppRadius.smallBr,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.edit_rounded,
                  color: Colors.white54,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 4),
            AnimatedTouchItem(
              onTap: () => widget.onDeleteCarTap(car.id),
              normalColor: Colors.transparent,
              pressedColor: AppColors.danger.withValues(alpha: 0.2),
              pressedScale: 0.95,
              borderRadius: AppRadius.smallBr,
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.white54,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: AppDimens.gapLg),
          ],
        ),
      ),
    );
  }

  Widget _buildAddMoreButton(
    BuildContext context, {
    bool showSkeleton = false,
  }) {
    final label = Text(
      AppLocalizations.of(context)!.anotherCar,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
    return AnimatedTouchItem(
      onTap: showSkeleton ? null : widget.onAddCarTap,
      normalColor: Colors.transparent,
      pressedColor: Colors.transparent,
      pressedScale: 0.97,
      pressedOpacity: 0.6,
      borderRadius: BorderRadius.zero,
      child: SizedBox(
        height: 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showSkeleton)
              const ShimmerBlock(width: 22, height: 22, borderRadius: 6)
            else
              const Icon(Icons.add_rounded, color: Colors.white38, size: 22),
            const SizedBox(width: 8),
            showSkeleton ? ShimmerPlaceholder(child: label) : label,
          ],
        ),
      ),
    );
  }
}
