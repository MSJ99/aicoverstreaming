import os
import json
import requests
import logging
from .download_song_service import download_audio_as_wav, get_youtube_url

PLAYLIST_DIR = os.path.join("server", "input", "playlist")
SONGS_DIR = os.path.join("server", "input", "songs")
os.makedirs(PLAYLIST_DIR, exist_ok=True)
os.makedirs(SONGS_DIR, exist_ok=True)


class SpotifyHijackingService:
    def __init__(self, playlist_id, output_dir=SONGS_DIR):
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
        song_list = self.get_song_queries_from_json()
        youtube_links = []
        for title, artist in song_list:
            url = get_youtube_url(title, artist)
            youtube_links.append((title, artist, url))
        # 링크 저장
        with open(
            os.path.join(PLAYLIST_DIR, "youtube_links.txt"), "w", encoding="utf-8"
        ) as f:
            for title, artist, url in youtube_links:
                f.write(f"{title} - {artist} ||| {url if url else ''}\n")
        # 다운로드
        for title, artist, url in youtube_links:
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
