import 'dart:math' as math;
import 'package:flutter/services.dart';

String normalizeMoneyText(String text) {
  if (text.isEmpty) return text;
  final point = text.indexOf('.');
  final whole = point < 0 ? text : text.substring(0, point);
  final fraction = point < 0 ? '' : text.substring(point);
  final normalized =
      whole.isEmpty ? '0' : whole.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  return '$normalized$fraction';
}

List<TextInputFormatter> appMoneyInputFormatters() => [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      TextInputFormatter.withFunction((oldValue, newValue) {
        final text = newValue.text;
        if ('.'.allMatches(text).length > 1) return oldValue;
        final point = text.indexOf('.');
        if (point >= 0 && text.length - point - 1 > 2) return oldValue;
        final normalized = normalizeMoneyText(text);
        final removed = text.length - normalized.length;
        final cursor = math.max(
            0, math.min(normalized.length, newValue.selection.end - removed));
        return TextEditingValue(
            text: normalized,
            selection: TextSelection.collapsed(offset: cursor));
      }),
    ];
