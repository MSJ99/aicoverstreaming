import 'package:flutter/material.dart';

/// 셔플(랜덤 재생) 버튼 위젯
/// - 첫 번째 상태: 랜덤 재생 안함
/// - 두 번째 상태: 랜덤 재생 함
/// 버튼을 탭하면 두 상태가 토글됩니다.
class ShuffleButton extends StatefulWidget {
  final bool initialShuffleOn;
  final ValueChanged<bool>? onChanged;

  const ShuffleButton({Key? key, this.initialShuffleOn = false, this.onChanged})
    : super(key: key);

  @override
  State<ShuffleButton> createState() => _ShuffleButtonState();
}

class _ShuffleButtonState extends State<ShuffleButton> {
  late bool _isShuffleOn;

  @override
  void initState() {
    super.initState();
    _isShuffleOn = widget.initialShuffleOn;
  }

  void _toggleShuffle() {
    setState(() {
      _isShuffleOn = !_isShuffleOn;
    });
    widget.onChanged?.call(_isShuffleOn);
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _toggleShuffle,
      icon: Icon(
        Icons.shuffle,
        color: _isShuffleOn ? Colors.green : Colors.grey,
      ),
      tooltip: _isShuffleOn ? '랜덤 재생 켜짐' : '랜덤 재생 꺼짐',
    );
  }
}
