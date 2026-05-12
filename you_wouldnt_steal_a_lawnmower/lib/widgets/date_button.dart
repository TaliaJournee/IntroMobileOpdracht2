import 'package:flutter/material.dart';

String formatDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class DateButton extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onPressed;

  const DateButton({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_month),
      label: Text(value == null ? label : '${label}: ${formatDate(value!)}'),
    );
  }
}
