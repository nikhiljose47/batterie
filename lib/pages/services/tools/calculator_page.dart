import 'package:flutter/material.dart';

import '../../../constants/app_spacing.dart';
import 'toolkit.dart';

class CalculatorPage extends StatefulWidget {
  const CalculatorPage({super.key});

  @override
  State<CalculatorPage> createState() => _CalculatorPageState();
}

class _CalculatorPageState extends State<CalculatorPage> {
  final TextEditingController _expression = TextEditingController();
  final List<String> _history = <String>[];
  String _result = '0';

  @override
  void dispose() {
    _expression.dispose();
    super.dispose();
  }

  void _append(String value) {
    final selection = _expression.selection;
    final text = _expression.text;
    final start = selection.start < 0 ? text.length : selection.start;
    final end = selection.end < 0 ? text.length : selection.end;
    _expression.text = text.replaceRange(start, end, value);
    _expression.selection =
        TextSelection.collapsed(offset: start + value.length);
    _preview();
  }

  void _backspace() {
    final text = _expression.text;
    if (text.isEmpty) return;
    final selection = _expression.selection;
    final cursor = selection.start < 0 ? text.length : selection.start;
    if (selection.start != selection.end && selection.start >= 0) {
      _expression.text = text.replaceRange(selection.start, selection.end, '');
      _expression.selection = TextSelection.collapsed(offset: selection.start);
    } else if (cursor > 0) {
      _expression.text = text.replaceRange(cursor - 1, cursor, '');
      _expression.selection = TextSelection.collapsed(offset: cursor - 1);
    }
    _preview();
  }

  void _clear() {
    _expression.clear();
    setState(() => _result = '0');
  }

  void _preview() {
    final value = _evaluate(_expression.text);
    if (value == null) return;
    setState(() => _result = _formatNumber(value));
  }

  void _calculate() {
    final raw = _expression.text.trim();
    final value = _evaluate(raw);
    if (raw.isEmpty || value == null) {
      setState(() => _result = 'Check expression');
      return;
    }
    final formatted = _formatNumber(value);
    setState(() {
      _result = formatted;
      _history.insert(0, '$raw = $formatted');
      if (_history.length > 8) _history.removeLast();
      _expression.text = formatted;
      _expression.selection = TextSelection.collapsed(offset: formatted.length);
    });
  }

  double? _evaluate(String input) {
    try {
      final parser = _MathParser(input);
      final value = parser.parseExpression();
      if (!parser.isAtEnd || value.isNaN || value.isInfinite) return null;
      return value;
    } catch (_) {
      return null;
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) return value.round().toString();
    return value
        .toStringAsFixed(8)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: svcAppBar('Calculator'),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.large),
        children: <Widget>[
          WhiteCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _expression,
                  autofocus: true,
                  keyboardType: TextInputType.none,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                  decoration: const InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                  ),
                  onChanged: (_) => _preview(),
                ),
                const SizedBox(height: 8),
                Text(
                  _result,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CalculatorKeypad(
            onTap: _append,
            onEquals: _calculate,
            onClear: _clear,
            onBackspace: _backspace,
          ),
          if (_history.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            const SectionLabel('History'),
            WhiteCard(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final item in _history)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Text(
                        item,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface.withOpacity(0.72),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalculatorKeypad extends StatelessWidget {
  const _CalculatorKeypad({
    required this.onTap,
    required this.onEquals,
    required this.onClear,
    required this.onBackspace,
  });

  final ValueChanged<String> onTap;
  final VoidCallback onEquals;
  final VoidCallback onClear;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = <List<String>>[
      <String>['C', '(', ')', '⌫'],
      <String>['7', '8', '9', '÷'],
      <String>['4', '5', '6', '×'],
      <String>['1', '2', '3', '-'],
      <String>['0', '.', '=', '+'],
    ];
    return Column(
      children: <Widget>[
        for (final row in rows) ...<Widget>[
          Row(
            children: <Widget>[
              for (final key in row) ...<Widget>[
                Expanded(
                  child: _CalcButton(
                    label: key,
                    onTap: () {
                      switch (key) {
                        case 'C':
                          onClear();
                          return;
                        case '⌫':
                          onBackspace();
                          return;
                        case '=':
                          onEquals();
                          return;
                        case '×':
                          onTap('*');
                          return;
                        case '÷':
                          onTap('/');
                          return;
                        default:
                          onTap(key);
                      }
                    },
                  ),
                ),
                if (key != row.last) const SizedBox(width: 8),
              ],
            ],
          ),
          if (row != rows.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _CalcButton extends StatelessWidget {
  const _CalcButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isAction = 'C⌫=+-×÷()'.contains(label);
    return SizedBox(
      height: 52,
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor:
              isAction ? colors.primary.withOpacity(0.1) : colors.surface,
          foregroundColor: isAction ? colors.primary : colors.onSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colors.outline.withOpacity(0.18)),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _MathParser {
  _MathParser(String input) : _input = input.replaceAll(' ', '');

  final String _input;
  int _index = 0;

  bool get isAtEnd => _index >= _input.length;

  double parseExpression() {
    var value = parseTerm();
    while (!isAtEnd) {
      if (_match('+')) {
        value += parseTerm();
      } else if (_match('-')) {
        value -= parseTerm();
      } else {
        break;
      }
    }
    return value;
  }

  double parseTerm() {
    var value = parseFactor();
    while (!isAtEnd) {
      if (_match('*')) {
        value *= parseFactor();
      } else if (_match('/')) {
        value /= parseFactor();
      } else {
        break;
      }
    }
    return value;
  }

  double parseFactor() {
    if (_match('+')) return parseFactor();
    if (_match('-')) return -parseFactor();
    if (_match('(')) {
      final value = parseExpression();
      if (!_match(')')) throw const FormatException('Missing )');
      return value;
    }

    final start = _index;
    while (!isAtEnd && RegExp(r'[0-9.]').hasMatch(_input[_index])) {
      _index++;
    }
    if (start == _index) throw const FormatException('Expected number');
    return double.parse(_input.substring(start, _index));
  }

  bool _match(String char) {
    if (isAtEnd || _input[_index] != char) return false;
    _index++;
    return true;
  }
}
