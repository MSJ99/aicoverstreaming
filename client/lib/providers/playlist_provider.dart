import 'package:flutter/material.dart';
import '../models/song.dart';

/// PlaylistProvider
/// - 플레이리스트(곡 목록) 상태를 관리하며, 곡 추가/삭제 기능을 제공
class PlaylistProvider with ChangeNotifier {
  final List<Song> _songs = [];

  /// 현재 플레이리스트(곡 목록) 반환 (불변 리스트)
  List<Song> get songs => List.unmodifiable(_songs);

  /// 곡 추가
  void addSong(Song song) {
    _songs.add(song);
    notifyListeners();
  }

  /// 곡 삭제
  void removeSong(Song song) {
    _songs.remove(song);
    notifyListeners();
  }

  /// 곡 전체를 서버 output 파일 리스트로 갱신
  void setSongs(List<Song> songs) {
    _songs
      ..clear()
      ..addAll(songs);
    notifyListeners();
  }

  // 필요시 삭제, 전체 삭제 등 메서드 추가 가능
}
