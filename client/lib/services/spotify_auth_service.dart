import 'package:spotify_sdk/spotify_sdk.dart';
import 'secure_storage_service.dart';

const String clientId = '1a2bb437d6c041ed8f4f860189c45a7a';
const String redirectUri = 'com.kirby.client://callback';
const String scope =
    'user-read-private,playlist-read-private,playlist-read-collaborative,user-read-playback-state,user-read-currently-playing';

Future<void> authenticateWithSpotify() async {
  final result = await SpotifySdk.connectToSpotifyRemote(
    clientId: clientId,
    redirectUrl: redirectUri,
  );
  if (!result) {
    throw Exception('Spotify 앱 연결 실패');
  }
  final accessToken = await SpotifySdk.getAccessToken(
    clientId: clientId,
    redirectUrl: redirectUri,
    scope: scope,
  );
  await secureStorage.write(key: 'accessToken', value: accessToken);
  // 인증 후 강제로 음악 일시정지
  try {
    await SpotifySdk.pause();
  } catch (e) {
    // 음악이 재생 중이 아니면 무시
  }
}
