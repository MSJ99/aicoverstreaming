import 'package:dio/dio.dart';
import 'dart:developer' as logging;

Future<String> getBackendIp() async {
  Dio dio = Dio();
  try {
    final response = await dio.get('http://127.0.0.1:5000/get_backend_ip');
    if (response.statusCode == 200 && response.data['ip'] != null) {
      return response.data['ip'];
    }
  } catch (e) {
    logging.log('서버 IP 조회 실패: $e');
  }
  return '127.0.0.1';
}
