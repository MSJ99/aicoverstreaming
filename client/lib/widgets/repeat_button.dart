import 'package:flutter/material.dart';

enum RepeatMode { none, all, one }

class RepeatButton extends StatefulWidget {
  final RepeatMode initialMode;
  final ValueChanged<RepeatMode>? onChanged;

  const RepeatButton({
    Key? key,
    this.initialMode = RepeatMode.none,
    this.onChanged,
  }) : super(key: key);

  @override
  State<RepeatButton> createState() => _RepeatButtonState();
}

class _RepeatButtonState extends State<RepeatButton> {
  late RepeatMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  void _toggleMode() {
    setState(() {
      switch (_mode) {
        case RepeatMode.none:
          _mode = RepeatMode.all;
          break;
        case RepeatMode.all:
          _mode = RepeatMode.one;
          break;
        case RepeatMode.one:
          _mode = RepeatMode.none;
          break;
      }
      widget.onChanged?.call(_mode);
    });
  }

  @override
  Widget build(BuildContext context) {
    IconData icon;
    switch (_mode) {
      case RepeatMode.none:
        icon = Icons.repeat; // 반복 아이콘(비활성화)
        break;
      case RepeatMode.all:
        icon = Icons.repeat; // 반복 아이콘(활성화)
        break;
      case RepeatMode.one:
        icon = Icons.repeat_one; // 한 곡 반복 아이콘
        break;
    }

    Color color;
    switch (_mode) {
      case RepeatMode.none:
        color = Colors.grey;
        break;
      case RepeatMode.all:
        color = Colors.blue;
        break;
      case RepeatMode.one:
        color = Colors.blue;
        break;
    }

    return IconButton(
      icon: Icon(icon, color: color),
      onPressed: _toggleMode,
      tooltip: _getTooltip(),
    );
  }

  String _getTooltip() {
    switch (_mode) {
      case RepeatMode.none:
        return '반복 재생 안함';
      case RepeatMode.all:
        return '전체 곡 반복 재생';
      case RepeatMode.one:
        return '한 곡 반복 재생';
    }
  }
}
