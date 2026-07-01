import 'package:flutter/material.dart';

class VariantCell extends StatefulWidget {
  final int initialValue;
  final ValueChanged<int> onChanged;
  final bool isHeader;
  final String? headerText;

  /// Color label for the variant row (used in Semantics).
  final String? color;

  /// Size label for the variant column (used in Semantics).
  final String? size;

  const VariantCell({
    super.key,
    this.initialValue = 0,
    this.onChanged = _noopOnChanged,
    this.isHeader = false,
    this.headerText,
    this.color,
    this.size,
  });

  static void _noopOnChanged(int _) {}

  @override
  State<VariantCell> createState() => _VariantCellState();
}

class _VariantCellState extends State<VariantCell> {
  late TextEditingController _controller;
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
    _controller = TextEditingController(
      text: _value == 0 ? '' : _value.toString(),
    );
  }

  @override
  void didUpdateWidget(VariantCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue) {
      _value = widget.initialValue;
      _controller.text = _value == 0 ? '' : _value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateValue(int newValue) {
    if (newValue < 0) return;
    setState(() {
      _value = newValue;
      _controller.text = _value == 0 ? '' : _value.toString();
    });
    widget.onChanged(_value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isHeader) {
      final headerLabel = '${widget.headerText ?? ''} column header';
      return Semantics(
        label: headerLabel,
        header: true,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: Text(
            widget.headerText ?? '',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final colorLabel = widget.color ?? 'unknown color';
    final sizeLabel = widget.size ?? 'unknown size';
    final cellLabel = 'Quantity for $colorLabel size $sizeLabel: $_value';

    return Semantics(
      label: cellLabel,
      value: _value.toString(),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: _value > 0
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : colorScheme.surface,
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIconButton(
              Icons.remove,
              () => _updateValue(_value - 1),
              tooltip: 'Decrease quantity',
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  fontWeight: _value > 0 ? FontWeight.bold : FontWeight.normal,
                  color: _value > 0
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
                onChanged: (val) {
                  final num = int.tryParse(val);
                  if (num != null && num >= 0) {
                    _value = num;
                    widget.onChanged(_value);
                  } else if (val.isEmpty) {
                    _value = 0;
                    widget.onChanged(_value);
                  }
                },
              ),
            ),
            _buildIconButton(
              Icons.add,
              () => _updateValue(_value + 1),
              tooltip: 'Increase quantity',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon,
    VoidCallback onPressed, {
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
