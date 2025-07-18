import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/api_client.dart';
import 'dart:convert';

/// ConversionModeProvider
/// - 변환 모드(ON/OFF) 상태를 관리하며, 서버와 동기화 기능을 제공
class ConversionModeProvider extends ChangeNotifier {
  bool _isOn = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentSelectedSinger;

  /// 변환 모드 ON/OFF 상태 반환
  bool get isOn => _isOn;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentSelectedSinger => _currentSelectedSinger;

  void setCurrentSelectedSinger(String? singer) {
    _currentSelectedSinger = singer;
    notifyListeners();
  }

  /// 서버에서 변환 모드 상태를 조회하여 동기화
  Future<void> init() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
      final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
      final response = await ApiClient().get(
        Uri.parse('http://$backendIp:$backendPort/conversion_mode'),
      );
      if (response.statusCode == 401) {
        _errorMessage = '401: 인증이 필요합니다.';
      } else if (response.statusCode != 200) {
        _errorMessage = '변환 모드 조회 실패: \\${response.statusCode}';
      } else {
        final data = jsonDecode(response.body);
        _isOn = data['on'] ?? false;
      }
    } catch (e) {
      _errorMessage = '변환 모드 조회 중 오류: $e';
    }
    _isLoading = false;
    notifyListeners();
  }

  /// 서버에 변환 모드 변경 요청
  Future<void> setMode(bool on) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final backendIp = dotenv.env['BACKEND_IP'] ?? '127.0.0.1';
      final backendPort = dotenv.env['BACKEND_PORT'] ?? '5000';
      final response = await ApiClient().post(
        Uri.parse('http://$backendIp:$backendPort/conversion_mode'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'on': on}),
      );
      if (response.statusCode == 401) {
        _errorMessage = '401: 인증이 필요합니다.';
      } else if (response.statusCode != 200) {
        _errorMessage = '변환 모드 변경 실패: \\${response.statusCode}';
      } else {
        final data = jsonDecode(response.body);
        _isOn = data['on'] ?? false;
      }
    } catch (e) {
      _errorMessage = '변환 모드 변경 중 오류: $e';
    }
    _isLoading = false;
    notifyListeners();
  }
}
