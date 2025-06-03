import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/get_backend_ip_service.dart';

class ConversionModeProvider extends ChangeNotifier {
  bool _isOn = false;
  String? _backendIp;

  bool get isOn => _isOn;

  Future<void> init() async {
    _backendIp = await getBackendIp();
    final dio = Dio();
    final response = await dio.get('http://$_backendIp:5000/conversion_mode');
    _isOn = response.data['on'] ?? false;
    notifyListeners();
  }

  Future<void> setMode(bool on) async {
    if (_backendIp == null) _backendIp = await getBackendIp();
    final dio = Dio();
    final response = await dio.post(
      'http://$_backendIp:5000/conversion_mode',
      data: {'on': on},
      options: Options(contentType: Headers.jsonContentType),
    );
    _isOn = response.data['on'] ?? false;
    notifyListeners();
  }
}
