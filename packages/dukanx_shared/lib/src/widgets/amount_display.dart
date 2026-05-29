import 'package:flutter/material.dart';
import '../utils/currency_formatter.dart';

class AmountDisplay extends StatelessWidget {
  final double amount;
  final TextStyle? style;
  final bool compact;
  final bool colored;

  const AmountDisplay({
    super.key,
    required this.amount,
    this.style,
    this.compact = false,
    this.colored = false,
  });

  @override
  Widget build(BuildContext context) {
    final text =
        compact ? CurrencyFormatter.compact(amount) : CurrencyFormatter.format(amount);

    Color? color;
    if (colored) {
      color = amount > 0
          ? const Color(0xFFE53935)
          : amount < 0
              ? const Color(0xFF43A047)
              : null;
    }

    return Text(
      text,
      style: (style ?? Theme.of(context).textTheme.bodyMedium)
          ?.copyWith(color: color ?? style?.color),
    );
  }
}
