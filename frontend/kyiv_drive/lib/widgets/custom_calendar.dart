import 'package:flutter/material.dart';
import '../core/constants/app_ui_tokens.dart';
import '../l10n/app_localizations.dart';
import '../utils/ukraine_time.dart';
import 'animated_touch_templates.dart';
import 'animated_value_text.dart';

class CustomCalendar extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onDateChanged;
  final Color primaryColor;
  final SelectableDayPredicate? selectableDayPredicate;

  const CustomCalendar({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onDateChanged,
    required this.primaryColor,
    this.selectableDayPredicate,
  });

  @override
  State<CustomCalendar> createState() => _CustomCalendarState();
}

class _CustomCalendarState extends State<CustomCalendar> {
  late DateTime _currentMonth;
  late DateTime _selectedDate;

  List<String> get _weekDays => [
    AppLocalizations.of(context)!.monShort,
    AppLocalizations.of(context)!.tueShort,
    AppLocalizations.of(context)!.wedShort,
    AppLocalizations.of(context)!.thuShort,
    AppLocalizations.of(context)!.friShort,
    AppLocalizations.of(context)!.satShort,
    AppLocalizations.of(context)!.sunShort,
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    final initialMonth = DateTime(_selectedDate.year, _selectedDate.month);
    _currentMonth = initialMonth.isBefore(firstMonth)
        ? firstMonth
        : initialMonth.isAfter(lastMonth)
        ? lastMonth
        : initialMonth;
  }

  void _previousMonth() {
    if (_currentMonth.isAfter(
      DateTime(widget.firstDate.year, widget.firstDate.month),
    )) {
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      });
    }
  }

  void _nextMonth() {
    if (_currentMonth.isBefore(
      DateTime(widget.lastDate.year, widget.lastDate.month),
    )) {
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      });
    }
  }

  Widget _buildSequentialFade(Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.center,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
          ),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.5, 1.0, curve: Curves.easeOutCubic),
              ),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final String monthYearText = MaterialLocalizations.of(
      context,
    ).formatMonthYear(_currentMonth);
    final String displayTitle =
        monthYearText[0].toUpperCase() + monthYearText.substring(1);

    final bool canGoBack = _currentMonth.isAfter(
      DateTime(widget.firstDate.year, widget.firstDate.month),
    );
    final bool canGoForward = _currentMonth.isBefore(
      DateTime(widget.lastDate.year, widget.lastDate.month),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _CalendarArrow(
              icon: Icons.chevron_left_rounded,
              onTap: canGoBack ? _previousMonth : null,
            ),

            Flexible(
              child: AnimatedValueText(
                displayTitle,
                alignment: Alignment.center,
                textAlign: TextAlign.center,
                style: AppText.screenTitle.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            _CalendarArrow(
              icon: Icons.chevron_right_rounded,
              onTap: canGoForward ? _nextMonth : null,
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _weekDays.map((day) {
            return SizedBox(
              width: 36,
              child: Center(
                child: Text(
                  day,
                  style: AppText.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),

        _buildSequentialFade(
          _buildDaysGrid(key: ValueKey(_currentMonth.toIso8601String())),
        ),
      ],
    );
  }

  Widget _buildDaysGrid({Key? key}) {
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );

    final firstAllowedDate = DateUtils.dateOnly(widget.firstDate);

    final lastAllowedDate = DateUtils.dateOnly(widget.lastDate);

    final today = UkraineTime.today();

    final dayWidgets = List<Widget>.generate(42, (index) {
      final date = DateTime(
        _currentMonth.year,
        _currentMonth.month,
        1 - (firstDayOfMonth.weekday - 1) + index,
      );

      final isCurrentMonth =
          date.year == _currentMonth.year && date.month == _currentMonth.month;

      final isOutsideMonth = !isCurrentMonth;

      final isDisabled =
          date.isBefore(firstAllowedDate) ||
          date.isAfter(lastAllowedDate) ||
          !(widget.selectableDayPredicate?.call(date) ?? true);

      final isSelected = DateUtils.isSameDay(date, _selectedDate);

      final isToday = DateUtils.isSameDay(date, today);

      final showSelected = isSelected && !isDisabled;

      Color textColor;

      if (isDisabled) {
        textColor = Colors.white.withValues(alpha: 0.12);
      } else if (isOutsideMonth) {
        textColor = AppColors.textDisabled;
      } else if (showSelected) {
        textColor = AppColors.textPrimary;
      } else {
        textColor = AppColors.textSecondary;
      }

      return AnimatedTouchItem(
        key: ValueKey('calendar-day-${date.year}-${date.month}-${date.day}'),
        onTap: isDisabled
            ? null
            : () {
                setState(() {
                  _selectedDate = date;

                  if (isOutsideMonth) {
                    _currentMonth = DateTime(date.year, date.month);
                  }
                });

                widget.onDateChanged(date);
              },
        normalColor: Colors.transparent,
        pressedColor: Colors.transparent,
        pressedScale: 0.85,
        borderRadius: AppRadius.smallBr,
        child: AnimatedContainer(
          duration: AppDurations.fastest,
          curve: Curves.easeInOutCubic,
          decoration: BoxDecoration(
            color: showSelected ? widget.primaryColor : Colors.transparent,
            borderRadius: AppRadius.smallBr,
            border: Border.all(
              color: isToday && !showSelected && !isDisabled
                  ? Colors.white24
                  : Colors.transparent,
              width: AppDimens.borderWidth,
            ),
          ),
          child: Center(
            child: AnimatedDefaultTextStyle(
              duration: AppDurations.fastest,
              curve: Curves.easeInOutCubic,
              style: AppText.bodyStrong.copyWith(
                color: textColor,
                fontWeight: showSelected ? FontWeight.bold : FontWeight.w500,
              ),
              child: Text('${date.day}'),
            ),
          ),
        ),
      );
    });

    return GridView.count(
      key: key,
      padding: EdgeInsets.zero,
      crossAxisCount: 7,
      childAspectRatio: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppDimens.gapXs,
      crossAxisSpacing: AppDimens.gapSm,
      children: dayWidgets,
    );
  }
}

class _CalendarArrow extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CalendarArrow({required this.icon, required this.onTap});

  @override
  State<_CalendarArrow> createState() => _CalendarArrowState();
}

class _CalendarArrowState extends State<_CalendarArrow> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDown() { if (widget.onTap != null) _controller.forward(); }

  void _onUp() {
    if (widget.onTap != null) {
      _controller.reverse();
      widget.onTap!();
    }
  }

  void _onCancel() { if (widget.onTap != null) _controller.reverse(); }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _onDown(),
      onPointerUp: (_) => _onUp(),
      onPointerCancel: (_) => _onCancel(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 1.0 - (_controller.value * 0.15);

          final color = widget.onTap == null
              ? AppColors.textDisabled
              : Color.lerp(
            AppColors.textSecondary,
            AppColors.textMuted,
            _controller.value,
          );

          return Transform.scale(
            scale: scale,
            child: Padding(
              padding: const EdgeInsets.all(AppDimens.gapXs),
              child: Icon(widget.icon, color: color, size: 32),
            ),
          );
        },
      ),
    );
  }
}
