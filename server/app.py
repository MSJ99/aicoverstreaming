from flask import Flask, request, send_file, jsonify
from werkzeug.utils import secure_filename
import os, paramiko

app = Flask(__name__)
UPLOAD_FOLDER = "uploads"
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER

# 임시 데이터 (TODO: 반응형으로)
singers = ["아이유", "방탄소년단", "블랙핑크", "임영웅", "뉴진스", "세븐틴", "르세라핌"]
selected_singers = []
songs = [
    {"title": "좋은날", "artist": "아이유", "audio_url": "/audio/good_day.mp3"},
    {"title": "Dynamite", "artist": "BTS", "audio_url": "/audio/dynamite.mp3"},
    {
        "title": "Pink Venom",
        "artist": "BLACKPINK",
        "audio_url": "/audio/pink_venom.mp3",
    },
]
conversion_mode = False
current_song = {"title": "Ditto", "artist": "NewJeans", "album": "OMG"}


# 음성 변환 요청 처리
@app.route("/convert", methods=["POST"])
def convert_voice():
    if "file" not in request.files:
        return "No file part", 400
    file = request.files["file"]
    if file.filename == "":
        return "No selected file", 400

    filename = secure_filename(file.filename)
    local_path = os.path.join(app.config["UPLOAD_FOLDER"], filename)
    file.save(local_path)
    # TODO: Paramiko로 GPU 서버 전송, Slurm 실행, 결과 다운로드, 변환 파일 반환


# 가수 검색 요청 처리
@app.route("/singers", methods=["GET"])
def get_singers():
    query = request.args.get("query", "")
    filtered = [s for s in singers if query in s]
    return jsonify(filtered)


# 선택된 가수 처리
@app.route("/selected_singers", methods=["GET", "POST"])
def handle_selected_singers():
    if request.method == "POST":
        data = request.json
        singer = data.get("singer")
        if singer and singer not in selected_singers:
            selected_singers.append(singer)
        return jsonify(selected_singers)
    return jsonify(selected_singers)


# 노래 목록 요청 처리
@app.route("/songs", methods=["GET"])
def get_songs():
    return jsonify(songs)


# 변환 모드 처리
@app.route("/conversion_mode", methods=["GET", "POST"])
def handle_conversion_mode():
    global conversion_mode
    if request.method == "POST":
        data = request.json
        conversion_mode = data.get("on", False)
    return jsonify({"on": conversion_mode})


# 현재 재생 중인 노래 정보 요청 처리
@app.route("/current_song", methods=["GET"])
def get_current_song():
    return jsonify(current_song)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
