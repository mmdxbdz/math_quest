import 'package:flutter/material.dart';

/// 大按钮数字键盘：1-9、清空、0、确认
class NumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onClear;
  final VoidCallback onOk;
  final bool okEnabled;

  const NumPad({
    super.key,
    required this.onDigit,
    required this.onClear,
    required this.onOk,
    this.okEnabled = true,
  });

  Widget _key(BuildContext context, String label, VoidCallback? onTap,
      {Color? color}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: color ?? Colors.blue.shade50,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 54,
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Column(
      children: [
        for (final row in rows)
          Row(children: [
            for (final d in row)
              _key(context, d, () => onDigit(d)),
          ]),
        Row(children: [
          _key(context, '清空', onClear, color: Colors.orange.shade100),
          _key(context, '0', () => onDigit('0')),
          _key(context, '确认', okEnabled ? onOk : null,
              color: okEnabled ? Colors.green.shade300 : Colors.grey.shade300),
        ]),
      ],
    );
  }
}
