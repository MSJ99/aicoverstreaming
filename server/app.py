from flask import Flask, request, send_file, jsonify
from werkzeug.utils import secure_filename
import os
from server.services.ssh_service import (
    connect_ssh,
    upload_file,
    submit_job,
    wait_for_job_done,
    download_file,
    close_ssh,
)
import uuid
from dotenv import load_dotenv

load_dotenv()  # .env 파일 자동 로드

app = Flask(__name__)
UPLOAD_SOURCE_FOLDER = "uploads/source"
UPLOAD_TARGET_FOLDER = "uploads/target"
os.makedirs(UPLOAD_SOURCE_FOLDER, exist_ok=True)
os.makedirs(UPLOAD_TARGET_FOLDER, exist_ok=True)
DOWNLOAD_FOLDER = "downloads"
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

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
ssh_connection = None


# 음성 변환 요청 처리
@app.route("/convert", methods=["POST"])
def convert_voice():
    global ssh_connection
    data = request.json
    singer = data.get("singer")
    song = data.get("song")
    if not singer or not song:
        return "가수와 곡 정보를 모두 입력해야 합니다.", 400

    # GPU 서버 input/output 경로
    remote_target = f"/data/msj9518/repos/seed-vc/input/{secure_filename(singer)}.wav"
    remote_source = f"/data/msj9518/repos/seed-vc/input/{secure_filename(song)}.wav"
    remote_output = f"/data/msj9518/repos/seed-vc/output/{secure_filename(singer)}_{secure_filename(song)}.wav"

    # SSH 연결
    if ssh_connection is None:
        ssh = connect_ssh()
        close_after = True
    else:
        ssh = ssh_connection
        close_after = False

    # Slurm 작업 제출 (스크립트에서 인자 전달 방식에 맞게)
    # 예시: sbatch ~/convert.sh {remote_source} {remote_target} {remote_output}
    submit_job(ssh, remote_source, remote_target, remote_output)

    # 작업 완료 대기
    wait_for_job_done(ssh, remote_output)

    # 결과 파일 다운로드
    local_result_path = os.path.join(
        DOWNLOAD_FOLDER, f"{secure_filename(singer)}_{secure_filename(song)}.wav"
    )
    download_file(ssh, remote_output, local_result_path)

    if close_after:
        close_ssh(ssh)

    return send_file(local_result_path, as_attachment=True)


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
    global conversion_mode, ssh_connection
    data = request.json
    conversion_mode = data.get("on", False)
    if conversion_mode and ssh_connection is None:
        ssh_connection = connect_ssh()
    elif not conversion_mode and ssh_connection is not None:
        close_ssh(ssh_connection)
        ssh_connection = None
    return jsonify({"on": conversion_mode})


# 현재 재생 중인 노래 정보 요청 처리
@app.route("/current_song", methods=["GET"])
def get_current_song():
    return jsonify(current_song)


@app.route("/upload_audio", methods=["POST"])
def upload_audio():
    file = request.files["file"]
    file_type = request.form["type"]  # "target" 또는 "source"
    name = request.form["name"]  # 가수이름 또는 곡이름
    filename = secure_filename(f"{name}.wav")
    if file_type == "target":
        local_input_path = os.path.join(UPLOAD_TARGET_FOLDER, filename)
    elif file_type == "source":
        local_input_path = os.path.join(UPLOAD_SOURCE_FOLDER, filename)
    else:
        return "type은 'target' 또는 'source'만 가능합니다.", 400
    file.save(local_input_path)

    # GPU 서버 input 폴더에 업로드
    remote_input_path = f"/data/msj9518/repos/seed-vc/input/{filename}"
    ssh = connect_ssh()
    upload_file(ssh, local_input_path, remote_input_path)
    close_ssh(ssh)
    return "업로드 완료"


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
