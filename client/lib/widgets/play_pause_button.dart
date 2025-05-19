import 'package:flutter/material.dart';

/// 플레이/일시정지 버튼 위젯
/// 탭할 때마다 아이콘이 변경됨
class PlayPauseButton extends StatefulWidget {
  final double size; // 아이콘 크기
  final Color activeColor; // 활성화(아이콘) 색상

  const PlayPauseButton({
    Key? key,
    this.size = 48.0,
    this.activeColor = Colors.blue,
  }) : super(key: key);

  @override
  State<PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<PlayPauseButton> {
  bool isPlaying = false; // 현재 상태: 재생 중이면 true, 일시정지면 false

  void _toggle() {
    setState(() {
      isPlaying = !isPlaying;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: widget.size,
      color: widget.activeColor,
      icon: Icon(
        isPlaying ? Icons.pause : Icons.play_arrow, // 상태에 따라 아이콘 변경
      ),
      onPressed: _toggle, // 버튼 탭 시 상태 변경
      tooltip: isPlaying ? '일시정지' : '재생',
    );
  }
}
