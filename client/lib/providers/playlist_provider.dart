import 'package:flutter/material.dart';
import '../models/song.dart';

class PlaylistProvider with ChangeNotifier {
  final List<Song> _songs = [];

  List<Song> get songs => List.unmodifiable(_songs);

  void addSong(Song song) {
    _songs.add(song);
    notifyListeners();
  }

  // 필요시 삭제, 전체 삭제 등 메서드 추가
}
