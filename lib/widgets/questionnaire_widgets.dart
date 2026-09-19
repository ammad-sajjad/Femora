import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Building blocks shared by the risk questionnaires (PCOS, breast).

String formatNumber(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

class QuestionSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const QuestionSection({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(color: AppColors.quickLogPeriod, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primaryBerry, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: const TextStyle(fontFamily: 'Inter', fontSize: 12.5, color: AppColors.textMuted)),
          ],
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class QuestionLabel extends StatelessWidget {
  final String text;
  final bool missing;

  const QuestionLabel(this.text, {super.key, this.missing = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      missing ? '$text  •  Required' : text,
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: missing ? AppColors.accentPink : AppColors.textDark,
      ),
    );
  }
}

class QuestionHint extends StatelessWidget {
  final String text;

  const QuestionHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.textLight, height: 1.35),
    );
  }
}

class NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String unit;
  final double min;
  final double max;
  final bool integer;
  final bool required;

  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    required this.unit,
    required this.min,
    required this.max,
    this.integer = false,
    this.required = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: [
        FilteringTextInputFormatter.allow(integer ? RegExp(r'[0-9]') : RegExp(r'[0-9.]')),
      ],
      style: const TextStyle(fontFamily: 'Inter', fontSize: 15, color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        filled: true,
        fillColor: AppColors.lightGrayBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primaryBerry, width: 1.5),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return required ? 'Required' : null;
        final number = double.tryParse(value);
        if (number == null || number < min || number > max) {
          return '${formatNumber(min)}–${formatNumber(max)}';
        }
        return null;
      },
    );
  }
}

/// A row of pill buttons for 2–3 short options.
class ChoiceRow extends StatelessWidget {
  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  const ChoiceRow({super.key, required this.options, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 44,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: selectedIndex == i ? AppColors.primaryBerry : AppColors.lightGrayBg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown, // keeps 4-option rows readable on narrow phones
                  child: Text(
                    options[i],
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selectedIndex == i ? Colors.white : AppColors.textDark,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A full-width tappable tile: a checkbox for multi-select lists, or a radio button for longer single choices.
class SelectTile extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool radio;
  final VoidCallback onTap;

  const SelectTile({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    this.radio = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trailing = radio
        ? (selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded)
        : (selected ? Icons.check_circle_rounded : Icons.circle_outlined);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.pinkTagBg : AppColors.lightGrayBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primaryBerry : Colors.transparent, width: 1.5),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: selected ? AppColors.primaryBerry : AppColors.textMuted),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Icon(trailing, size: 22, color: selected ? AppColors.primaryBerry : AppColors.textLight),
          ],
        ),
      ),
    );
  }
}

/// A vertical list of [SelectTile] radio options, for single choices whose labels don't fit a [ChoiceRow].
class ChoiceList extends StatelessWidget {
  final List<String> options;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  const ChoiceList({super.key, required this.options, required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          SelectTile(label: options[i], selected: selectedIndex == i, radio: true, onTap: () => onSelected(i)),
        ],
      ],
    );
  }
}

class SubmitButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const SubmitButton({super.key, required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(27),
          boxShadow: AppTheme.buttonShadow,
        ),
        alignment: Alignment.center,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : Text(
                label,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
              ),
      ),
    );
  }
}
