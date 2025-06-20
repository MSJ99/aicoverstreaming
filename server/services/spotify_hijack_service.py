import os
import json
import requests
import logging
from .download_song_service import download_audio_as_wav, get_youtube_url
from services.ssh_service import connect_ssh

PLAYLIST_DIR = os.path.join("input", "playlist")
SONGS_DIR = os.path.join("input", "songs")
os.makedirs(PLAYLIST_DIR, exist_ok=True)
os.makedirs(SONGS_DIR, exist_ok=True)


class SpotifyHijackingService:
    def __init__(
        self, playlist_id, output_dir="/data/msj9518/repos/vcstream/rvc/input"
    ):
        self.playlist_id = playlist_id
        self.output_dir = output_dir
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)

    def get_song_queries_from_json(
        self, json_path=os.path.join(PLAYLIST_DIR, "playlist.json")
    ):
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        result = []
        for item in data["tracks"]["items"]:
            track = item.get("track")
            if not track:
                continue
            title = track.get("name", "Unknown Title")
            artists = ", ".join([artist["name"] for artist in track.get("artists", [])])
            result.append((title, artists))
        return result

    def hijack_playlist(self):
        # playlist.json에서 곡 정보 추출
        song_list = self.get_song_queries_from_json()
        for title, artist in song_list:
            url = get_youtube_url(title, artist)
            if url:
                download_audio_as_wav(url, title, artist, self.output_dir)


def get_playlist_tracks_with_token(playlist_id, access_token):
    url = f"https://api.spotify.com/v1/playlists/{playlist_id}/tracks"
    headers = {"Authorization": f"Bearer {access_token}"}
    tracks = []
    next_url = url
    while next_url:
        res = requests.get(next_url, headers=headers)
        if res.status_code != 200:
            logging.error(f"❌ Spotify 요청 실패: {res.text}")
            break
        data = res.json()
        for item in data["items"]:
            track = item.get("track")
            if not track:
                continue
            title = track.get("name", "Unknown Title")
            artists = ", ".join([artist["name"] for artist in track.get("artists", [])])
            tracks.append({"title": title, "artists": artists})
        next_url = data.get("next")
    return tracks


def download_playlist_to_gpu_via_ssh(
    playlist_id, access_token, output_dir="/data/msj9518/repos/vcstream/rvc/input"
):
    """
    playlist_id와 access_token을 받아, 해당 플레이리스트의 모든 곡을 GPU 서버 input 디렉토리에 SSH로 접속해 다운로드
    """
    tracks = get_playlist_tracks_with_token(playlist_id, access_token)
    ssh = connect_ssh()
    downloaded_files = []
    for track in tracks:
        title = track["title"]
        artists = track["artists"]
        query = f"{title} {artists} lyrics"
        safe_title = f"{title} - {artists}".replace("/", "_").replace("\\", "_")
        output_path = f"{output_dir}/{safe_title}.wav"
        yt_dlp_cmd = (
            f"cd {output_dir} && "
            "source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && "
            f'yt-dlp -x --audio-format wav "ytsearch1:{query}" -o "{safe_title}.%(ext)s"'
        )
        stdin, stdout, stderr = ssh.exec_command(yt_dlp_cmd)
        stdout.channel.recv_exit_status()  # 명령 완료 대기
        downloaded_files.append(output_path)
    ssh.close()
    return downloaded_files


# 사용 예시
if __name__ == "__main__":
    playlist_id = "3sSHG8i68MZ3cteVQIFkzB"
    access_token = "my_access_token"

    # 1. playlist 정보 받아와서 파일로 저장
    tracks = get_playlist_tracks_with_token(playlist_id, access_token)
    with open(os.path.join(PLAYLIST_DIR, "playlist.json"), "w", encoding="utf-8") as f:
        json.dump(
            {
                "tracks": {
                    "items": [
                        {
                            "track": {
                                "name": t["title"],
                                "artists": [
                                    {"name": a} for a in t["artists"].split(", ")
                                ],
                            }
                        }
                        for t in tracks
                    ]
                }
            },
            f,
            ensure_ascii=False,
            indent=2,
        )

    # 2. YouTube 다운로드 실행
    service = SpotifyHijackingService(playlist_id)
    service.hijack_playlist()
