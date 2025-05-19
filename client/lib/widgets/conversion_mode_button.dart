import 'package:flutter/material.dart';

/// Conversion Mode 버튼 위젯
/// - 첫 번째 상태: Conversion Mode = Off
/// - 두 번째 상태: Conversion Mode = On
/// 버튼을 탭하면 두 상태가 토글됩니다.
class ConversionModeButton extends StatefulWidget {
  final bool initialModeOn;
  final ValueChanged<bool>? onChanged;

  const ConversionModeButton({
    Key? key,
    this.initialModeOn = false,
    this.onChanged,
  }) : super(key: key);

  @override
  State<ConversionModeButton> createState() => _ConversionModeButtonState();
}

class _ConversionModeButtonState extends State<ConversionModeButton> {
  late bool _isModeOn;

  @override
  void initState() {
    super.initState();
    _isModeOn = widget.initialModeOn;
  }

  void _toggleMode() {
    setState(() {
      _isModeOn = !_isModeOn;
    });
    widget.onChanged?.call(_isModeOn);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _toggleMode,
      style: ElevatedButton.styleFrom(
        backgroundColor: _isModeOn ? Colors.blue : Colors.grey[400],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
      child: Text(
        _isModeOn ? 'Conversion Mode: On' : 'Conversion Mode: Off',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }
}
