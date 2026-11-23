import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_ui_tokens.dart';
import '../../l10n/app_localizations.dart';
import '../../models/car_color.dart';
import '../../models/car_models.dart';
import '../app_bottom_bars.dart';
import '../auth_widgets.dart';
import '../../services/car_api_service.dart';
import '../../services/notification_service.dart';
import '../../utils/input_validation.dart';
import '../app_scrollbar.dart';
import '../keyboard_dismiss_on_background_tap.dart';
import '../keyboard_motion_coordinator.dart';
import '../keyboard_reveal_target.dart';
import 'car_color_selector.dart';
import 'dart:math' as math;

enum _CarFormField { brand, model, plate, capacity }

class AddCarBottomSheet extends StatefulWidget {
  final CarApiService apiService;
  final List<CarBrandModel> brands;
  final List<CarResponseModel> existingCars;
  final CarResponseModel? carToEdit;

  const AddCarBottomSheet({
    super.key,
    required this.apiService,
    required this.brands,
    required this.existingCars,
    this.carToEdit,
  });

  static Future<CarResponseModel?> show(
    BuildContext context,
    CarApiService apiService,
    List<CarBrandModel> brands,
    List<CarResponseModel> existingCars, {
    CarResponseModel? carToEdit,
  }) {
    final safeInsets = MediaQuery.viewPaddingOf(context);
    final maxSheetHeight = math.max(
      0.0,
      MediaQuery.sizeOf(context).height -
          safeInsets.top -
          AppDimens.topContentGap,
    );

    return showModalBottomSheet<CarResponseModel>(
      context: context,
      isScrollControlled: true,

      useSafeArea: false,

      backgroundColor: Colors.transparent,
      clipBehavior: Clip.none,
      constraints: BoxConstraints(maxHeight: maxSheetHeight),

      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 360),
        reverseDuration: Duration(milliseconds: 260),
      ),

      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: safeInsets.left,
            right: safeInsets.right,
          ),
          child: AddCarBottomSheet(
            apiService: apiService,
            brands: brands,
            existingCars: existingCars,
            carToEdit: carToEdit,
          ),
        );
      },
    );
  }

  @override
  State<AddCarBottomSheet> createState() => _AddCarBottomSheetState();
}

class PlateNumberTextFormatter extends TextInputFormatter {
  const PlateNumberTextFormatter();

  static final RegExp _allowedCharsRegExp = RegExp(r'[A-ZА-ЯІЇЄҐ0-9]');

  String _formatStandardPlate(String raw) {
    if (raw.length <= 2) {
      return raw;
    }

    if (raw.length <= 6) {
      return '${raw.substring(0, 2)} ${raw.substring(2)}';
    }

    return '${raw.substring(0, 2)} ${raw.substring(2, 6)} ${raw.substring(6)}';
  }

  bool _shouldApplyStandardMask(String raw) {
    if (raw.length <= 2) {
      return false;
    }

    return InputValidation.standardCarPlateProgress.hasMatch(raw);
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), '')
        .split('')
        .where((char) => _allowedCharsRegExp.hasMatch(char))
        .join();

    final limitedRaw = raw.length > 8 ? raw.substring(0, 8) : raw;

    final formatted = _shouldApplyStandardMask(limitedRaw)
        ? _formatStandardPlate(limitedRaw)
        : limitedRaw;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
      composing: TextRange.empty,
    );
  }
}

class PassengerCapacityFormatter extends TextInputFormatter {
  const PassengerCapacityFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) {
      return newValue;
    }

    final value = int.tryParse(text);

    if (value == null) {
      return oldValue;
    }

    final clampedValue = value.clamp(1, 90).toString();

    return TextEditingValue(
      text: clampedValue,
      selection: TextSelection.collapsed(offset: clampedValue.length),
    );
  }
}

class _AddCarBottomSheetState extends State<AddCarBottomSheet> {
  static const double _headerFadeExtent = AppDimens.gap2xl;

  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _brandFocusNode = FocusNode();
  final FocusNode _modelFocusNode = FocusNode();
  final FocusNode _plateFocusNode = FocusNode();
  final FocusNode _capacityFocusNode = FocusNode();
  final KeyboardRevealController _brandRevealController =
      KeyboardRevealController();
  final KeyboardRevealController _modelRevealController =
      KeyboardRevealController();
  final KeyboardRevealController _plateRevealController =
      KeyboardRevealController();
  final KeyboardRevealController _capacityRevealController =
      KeyboardRevealController();

  String? _selectedBrandId;
  CarColor _selectedColor = CarColor.white;

  bool _isLoading = false;

  String? _brandError;
  String? _modelError;
  String? _plateError;
  String? _capacityError;

  List<CarModelResponseModel> _fetchedModels = [];

  bool get _isFormEnabled => _selectedBrandId != null;

  @override
  void initState() {
    super.initState();
    final car = widget.carToEdit;
    if (car == null) return;

    _selectedBrandId = car.brandId;
    _modelController.text = car.modelName;
    _plateController.value = const PlateNumberTextFormatter().formatEditUpdate(
      TextEditingValue.empty,
      TextEditingValue(text: car.plateNumber),
    );
    _capacityController.text = car.passengerCapacity.toString();
    _selectedColor = car.color;
    _fetchModelsInBackground(car.brandId);
  }

  @override
  void dispose() {
    _modelController.dispose();
    _plateController.dispose();
    _capacityController.dispose();
    _scrollController.dispose();
    _brandFocusNode.dispose();
    _modelFocusNode.dispose();
    _plateFocusNode.dispose();
    _capacityFocusNode.dispose();
    _brandRevealController.dispose();
    _modelRevealController.dispose();
    _plateRevealController.dispose();
    _capacityRevealController.dispose();
    super.dispose();
  }

  String _normalizePlate(String value) {
    return value.replaceAll(RegExp(r'\s+'), '').trim().toUpperCase();
  }

  static final RegExp _standardLikePlateRegExp = RegExp(
    r'^[A-ZА-ЯІЇЄҐ]{2}\d{4}[A-ZА-ЯІЇЄҐ]{2}$',
  );

  static final RegExp _customPlateRegExp = RegExp(
    r'^(?![A-ZА-ЯІЇЄҐ]{2}\d{4}[A-ZА-ЯІЇЄҐ]{2})(?=(?:.*[A-ZА-ЯІЇЄҐ]){2})[A-ZА-ЯІЇЄҐ0-9]{3,8}$',
  );

  static final RegExp _cyrillicLettersRegExp = RegExp(r'[А-ЯІЇЄҐ]');

  bool _isPlateAlreadyAdded(String plate) {
    final normalizedPlate = _normalizePlate(plate);

    return widget.existingCars.any((car) {
      return car.id != widget.carToEdit?.id &&
          _normalizePlate(car.plateNumber) == normalizedPlate;
    });
  }

  String? _validatePlate(String value) {
    final plate = _normalizePlate(value);

    if (plate.isEmpty) {
      return "";
    }

    if (InputValidation.standardCarPlate.hasMatch(plate)) {
      if (_isPlateAlreadyAdded(plate)) {
        return AppLocalizations.of(context)!.carWithThisNumber;
      }

      return null;
    }

    if (_standardLikePlateRegExp.hasMatch(plate)) {
      if (_cyrillicLettersRegExp.hasMatch(plate)) {
        return AppLocalizations.of(context)!.standardNumberNeedToEnterLatin;
      }

      return AppLocalizations.of(context)!.incorrectNumberFormat;
    }

    if (_customPlateRegExp.hasMatch(plate)) {
      if (_isPlateAlreadyAdded(plate)) {
        return AppLocalizations.of(context)!.carWithThisNumber;
      }

      return null;
    }

    return AppLocalizations.of(context)!.incorrectNumberFormat;
  }

  void _onBrandSelected(CarBrandModel? brand) {
    if (brand == null) return;

    if (_selectedBrandId != brand.id) {
      setState(() {
        _selectedBrandId = brand.id;
        _modelController.clear();

        _brandError = null;
        _modelError = null;
        _plateError = null;
        _capacityError = null;
      });

      _fetchModelsInBackground(brand.id);
    } else {
      setState(() {
        _brandError = null;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isFormEnabled) {
        _modelFocusNode.requestFocus();
      }
    });
  }

  void _onModelSuggestionSelected(String _) {
    if (_modelError != null) {
      setState(() => _modelError = null);
    }

    if (_plateController.text.trim().isEmpty) {
      _plateFocusNode.requestFocus();
    } else if (_capacityController.text.trim().isEmpty) {
      _capacityFocusNode.requestFocus();
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  Future<void> _fetchModelsInBackground(String brandId) async {
    try {
      final models = await widget.apiService.getModels(brandId: brandId);

      if (mounted && _selectedBrandId == brandId) {
        setState(() {
          _fetchedModels = models;
        });
      }
    } catch (e) {
      debugPrint("Error model loading: $e");
    }
  }

  _CarFormField? _validate() {
    final brandSelected = _selectedBrandId != null;
    final model = _modelController.text.trim();
    final plate = _normalizePlate(_plateController.text);
    final capacityText = _capacityController.text.trim();

    final brandError = brandSelected ? null : "";
    final modelError = !brandSelected
        ? null
        : model.isEmpty || !InputValidation.carModel.hasMatch(model)
        ? ""
        : null;
    final plateError = !brandSelected
        ? null
        : plate.isEmpty
        ? ""
        : _validatePlate(plate);
    final capacityError = !brandSelected || capacityText.isNotEmpty ? null : "";

    setState(() {
      _brandError = brandError;
      _modelError = modelError;
      _plateError = plateError;
      _capacityError = capacityError;
    });

    if (brandError != null) return _CarFormField.brand;
    if (modelError != null) return _CarFormField.model;
    if (plateError != null) return _CarFormField.plate;
    if (capacityError != null) return _CarFormField.capacity;
    return null;
  }

  void _focusInvalidField(_CarFormField field) {
    final (focusNode, revealController) = switch (field) {
      _CarFormField.brand => (_brandFocusNode, _brandRevealController),
      _CarFormField.model => (_modelFocusNode, _modelRevealController),
      _CarFormField.plate => (_plateFocusNode, _plateRevealController),
      _CarFormField.capacity => (_capacityFocusNode, _capacityRevealController),
    };

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focusNode.requestFocus();
      revealController.reveal();
    });
  }

  bool get _matchesOriginalCar {
    final car = widget.carToEdit;
    return car != null &&
        _selectedBrandId == car.brandId &&
        _modelController.text.trim().toLowerCase() ==
            car.modelName.trim().toLowerCase() &&
        _normalizePlate(_plateController.text) ==
            _normalizePlate(car.plateNumber) &&
        int.tryParse(_capacityController.text.trim()) ==
            car.passengerCapacity &&
        _selectedColor == car.color;
  }

  Future<void> _submit() async {
    if (_isLoading) return;

    if (_matchesOriginalCar) {
      Navigator.pop(context);
      return;
    }

    final invalidField = _validate();
    if (invalidField != null) {
      _focusInvalidField(invalidField);
      return;
    }

    FocusScope.of(context).unfocus();

    final capacity = int.parse(_capacityController.text.trim());

    setState(() => _isLoading = true);

    bool shouldResetLoading = true;
    final carToEdit = widget.carToEdit;

    try {
      final results = await Future.wait<Object?>([
        carToEdit != null
            ? widget.apiService.updateCar(
                carId: carToEdit.id,
                brandId: _selectedBrandId!,
                modelName: _modelController.text.trim(),
                color: _selectedColor.backendValue,
                plateNumber: _normalizePlate(_plateController.text),
                passengerCapacity: capacity,
              )
            : widget.apiService.addCar(
                brandId: _selectedBrandId!,
                modelName: _modelController.text.trim(),
                color: _selectedColor.backendValue,
                plateNumber: _normalizePlate(_plateController.text),
                passengerCapacity: capacity,
              ),
        Future.delayed(const Duration(milliseconds: 600)),
      ]);

      final newCar = results[0] as CarResponseModel;

      shouldResetLoading = false;

      if (mounted) {
        Navigator.pop(context, newCar);
      }
    } catch (e) {
      if (mounted) {
        NotificationService.showError(e);
      }
    } finally {
      if (mounted && shouldResetLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildLockedColorSelector() {
    return IgnorePointer(
      ignoring: _isLoading,
      child: AnimatedOpacity(
        opacity: _isLoading ? 0.45 : 1.0,
        duration: AppDurations.fieldState,
        curve: Curves.easeOut,
        child: CarColorSelector(
          selectedColor: _selectedColor,
          onColorSelected: (color) {
            if (_isLoading) return;
            setState(() => _selectedColor = color);
          },
        ),
      ),
    );
  }

  Widget _buildCarFieldsHint() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimens.gapSm + 2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.gapMd,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smallBr,
        border: Border.all(
          color: AppColors.borderSubtle,
          width: AppDimens.borderWidth,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              color: AppColors.textMuted,
              size: 15,
            ),
          ),
          const SizedBox(width: AppDimens.gapSm),
          Expanded(
            child: Text(
              AppLocalizations.of(context)!.numberAndSeatClue,
              style: AppText.caption.copyWith(
                fontSize: 12.5,
                height: 1.3,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final Color driverCursorColor = AppColors.driverText;
    final bottomObstruction = math.max(
      media.viewInsets.bottom,
      media.viewPadding.bottom,
    );
    final formBottomPadding = bottomObstruction + AppDimens.bottomContentGap;
    final scrollbarBottomPadding = bottomObstruction + AppDimens.gapLg;
    final keyboardRevealVisibilityPadding = EdgeInsets.fromLTRB(
      AppDimens.gapLg,
      _headerFadeExtent,
      AppDimens.gapLg,
      bottomObstruction + AppDimens.gapLg,
    );

    return PopScope(
      canPop: !_isLoading,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // The native sheet drag dismisses via Navigator.pop, bypassing PopScope.
        // Claim only its drag while saving; the nested form still owns scrolling.
        onVerticalDragUpdate: _isLoading ? (_) {} : null,
        child: KeyboardMotionCoordinator(
          scrollController: _scrollController,
          scrollPhysics: const BouncingScrollPhysics(),
          // Keep the route's full constraints. The inset becomes trailing scroll
          // extent instead of clipping the viewport, so content remains visible
          // behind the keyboard while focused fields can still be revealed.
          applyKeyboardInsetToLayout: false,
          reservedBottomInset: 0,
          // Let the offset clamp to the sheet's natural scroll range while the
          // keyboard closes. A temporary coordinator extent would participate
          // in this shrink-wrapped surface's height and pin it to the top cap.
          builder: (context, _, scrollPhysics, _) {
            return Align(
              alignment: Alignment.bottomCenter,
              heightFactor: 1,
              child: KeyboardDismissOnBackgroundTap(
                child: AppBottomSheetSurface(
                  key: const ValueKey('add-car-sheet-surface'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppDimens.gapMd),
                      const AppSheetHandle(),
                      const SizedBox(height: AppDimens.gapXl),
                      Center(
                        child: Text(
                          widget.carToEdit == null
                              ? AppLocalizations.of(context)!.addCar
                              : AppLocalizations.of(context)!.editCar,
                          style: AppText.modalTitle,
                        ),
                      ),
                      Flexible(
                        child: Padding(
                          padding: EdgeInsets.zero,
                          child: AppScrollbar(
                            controller: _scrollController,
                            mainAxisMargin: 0,
                            topFadeExtent: _headerFadeExtent,
                            padding: EdgeInsets.only(
                              top: _headerFadeExtent,
                              bottom: scrollbarBottomPadding,
                            ),
                            child: SingleChildScrollView(
                              key: const ValueKey('add-car-form-scroll-view'),
                              controller: _scrollController,
                              physics: scrollPhysics,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.manual,
                              padding: EdgeInsets.fromLTRB(
                                AppDimens.pagePadding,
                                _headerFadeExtent,
                                AppDimens.pagePadding,
                                // Keep enough trailing extent to reveal a focused
                                // field while letting content paint behind the
                                // keyboard during manual scrolling.
                                formBottomPadding,
                              ),
                              child: Overlay.wrap(
                                // Brand and model popups must inherit the form
                                // viewport clipping and its header fade mask.
                                clipBehavior: Clip.none,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.carToEdit != null) ...[
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.info_outline_rounded,
                                            color: AppColors.iconMuted,
                                            size: 16,
                                          ),
                                          const SizedBox(
                                            width: AppDimens.gapSm,
                                          ),
                                          Expanded(
                                            child: Text(
                                              AppLocalizations.of(
                                                context,
                                              )!.carEditExistingTripsHint,
                                              style: AppText.bodySecondary
                                                  .copyWith(
                                                    color: Colors.white54,
                                                    fontSize: 13,
                                                    height: 1.3,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppDimens.gapXl),
                                    ],
                                    AuthDropdownField<CarBrandModel>(
                                      key: const ValueKey(
                                        'add-car-brand-field',
                                      ),
                                      value: widget.brands
                                          .where(
                                            (b) => b.id == _selectedBrandId,
                                          )
                                          .firstOrNull,
                                      items: widget.brands,
                                      hint: AppLocalizations.of(context)!.brand,
                                      icon: Icons.local_offer_rounded,
                                      isEnabled: !_isLoading,
                                      focusColor: AppColors.driver,
                                      cursorColor: driverCursorColor,
                                      capitalization: TextCapitalization.words,
                                      errorText: _brandError,
                                      itemLabelBuilder: (brand) => brand.name,
                                      onChanged: _onBrandSelected,
                                      unfocusOnSelection: false,
                                      useKeyboardRevealTarget: true,
                                      focusNode: _brandFocusNode,
                                      keyboardRevealVisibilityPadding:
                                          keyboardRevealVisibilityPadding,
                                      keyboardRevealController:
                                          _brandRevealController,
                                      formatters: [
                                        LengthLimitingTextInputFormatter(
                                          InputValidation
                                              .maximumCarCatalogNameLength,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppDimens.gapLg),
                                    AuthTextField(
                                      key: const ValueKey(
                                        'add-car-model-field',
                                      ),
                                      controller: _modelController,
                                      isEnabled: _isFormEnabled && !_isLoading,
                                      hint: AppLocalizations.of(context)!.model,
                                      icon: Icons.directions_car_rounded,
                                      inputAction: TextInputAction.next,
                                      focusColor: AppColors.driver,
                                      cursorColor: driverCursorColor,
                                      errorText: _modelError,
                                      focusNode: _modelFocusNode,
                                      useKeyboardRevealTarget: true,
                                      keyboardRevealVisibilityPadding:
                                          keyboardRevealVisibilityPadding,
                                      keyboardRevealController:
                                          _modelRevealController,
                                      suggestions: _fetchedModels
                                          .map((m) => m.name)
                                          .toList(),
                                      onChanged: (_) {
                                        if (_modelError != null) {
                                          setState(() => _modelError = null);
                                        }
                                      },
                                      onSuggestionSelected:
                                          _onModelSuggestionSelected,
                                      unfocusOnSuggestionSelected: false,
                                      formatters: [
                                        LengthLimitingTextInputFormatter(
                                          InputValidation
                                              .maximumCarCatalogNameLength,
                                        ),
                                        FilteringTextInputFormatter.allow(
                                          InputValidation.carModelCharacter,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppDimens.gapLg),
                                    _buildCarFieldsHint(),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: AuthTextField(
                                            key: const ValueKey(
                                              'add-car-plate-field',
                                            ),
                                            controller: _plateController,
                                            isEnabled:
                                                _isFormEnabled && !_isLoading,
                                            hint: AppLocalizations.of(
                                              context,
                                            )!.number,
                                            icon: Icons.pin_rounded,
                                            leadingBuilder: (color) =>
                                                UaPlateTextIcon(color: color),
                                            capitalization:
                                                TextCapitalization.characters,
                                            inputAction: TextInputAction.next,
                                            focusColor: AppColors.driver,
                                            cursorColor: driverCursorColor,
                                            errorText: _plateError,
                                            focusNode: _plateFocusNode,
                                            useKeyboardRevealTarget: true,
                                            keyboardRevealVisibilityPadding:
                                                keyboardRevealVisibilityPadding,
                                            keyboardRevealController:
                                                _plateRevealController,
                                            onChanged: (_) {
                                              if (_plateError != null) {
                                                setState(
                                                  () => _plateError = null,
                                                );
                                              }
                                            },
                                            formatters: const [
                                              PlateNumberTextFormatter(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: AppDimens.gapMd),
                                        Expanded(
                                          flex: 1,
                                          child: AuthTextField(
                                            key: const ValueKey(
                                              'add-car-capacity-field',
                                            ),
                                            controller: _capacityController,
                                            isEnabled:
                                                _isFormEnabled && !_isLoading,
                                            hint: AppLocalizations.of(
                                              context,
                                            )!.seats,
                                            icon: Icons
                                                .airline_seat_recline_normal_rounded,
                                            showClearButton: false,
                                            keyboardType: TextInputType.number,
                                            inputAction: TextInputAction.done,
                                            focusColor: AppColors.driver,
                                            cursorColor: driverCursorColor,
                                            errorText: _capacityError,
                                            focusNode: _capacityFocusNode,
                                            useKeyboardRevealTarget: true,
                                            keyboardRevealVisibilityPadding:
                                                keyboardRevealVisibilityPadding,
                                            keyboardRevealController:
                                                _capacityRevealController,
                                            onChanged: (_) {
                                              if (_capacityError != null) {
                                                setState(
                                                  () => _capacityError = null,
                                                );
                                              }
                                            },
                                            formatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              const PassengerCapacityFormatter(),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: AppDimens.gapXl),
                                    _buildLockedColorSelector(),
                                    const SizedBox(height: AppDimens.gap2xl),
                                    AuthButton(
                                      key: const ValueKey(
                                        'add-car-save-button',
                                      ),
                                      text: AppLocalizations.of(context)!.save,
                                      color: Colors.deepOrange.shade800,
                                      isLoading: _isLoading,
                                      dismissKeyboardOnTap: false,
                                      onTap: _submit,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
