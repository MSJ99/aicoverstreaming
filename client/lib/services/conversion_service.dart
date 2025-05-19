import 'package:dio/dio.dart';

Future<void> uploadAudioFile(String filePath) async {
  Dio dio = Dio();
  dio.options.contentType = 'multipart/form-data';
  try {
    FormData formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: 'audio.wav'),
    });

    Response response = await dio.post(
      'http://<BACKEND_IP>:5000/convert',
      data: formData,
    );
    if (response.statusCode == 200) {
      // 필요한 처리 수행 (파일 저장 또는 재생 등))
    }
  } catch (e) {
    print("파일 업로드 실패: $e");
  }
}
