from flask import Flask, request, send_file, jsonify
from werkzeug.utils import secure_filename
import os
from services.ssh_service import (
    connect_ssh,
    upload_file,
    submit_job,
    wait_for_job_done,
    download_file,
    close_ssh,
)
import uuid
from dotenv import load_dotenv
import logging
import socket
import sys

load_dotenv()  # .env 파일 자동 로드
logging.basicConfig(level=logging.INFO, stream=sys.stdout, force=True)

app = Flask(__name__)
UPLOAD_SOURCE_FOLDER = "uploads/source"
UPLOAD_TARGET_FOLDER = "uploads/target"
os.makedirs(UPLOAD_SOURCE_FOLDER, exist_ok=True)
os.makedirs(UPLOAD_TARGET_FOLDER, exist_ok=True)
DOWNLOAD_FOLDER = "downloads"
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

ssh_connection = None
conversion_mode = False
selected_singers = []


# 음성 변환 요청 처리
@app.route("/convert", methods=["POST"])
def convert_voice():
    global ssh_connection
    data = request.json
    if not data:
        return "Invalid JSON", 400
    singer = data.get("singer")
    song = data.get("song")
    if not singer or not song:
        return "가수와 곡 정보를 모두 입력해야 합니다.", 400

    logging.info(f"[LOG] 받은 singer: {singer}, song: {song}")

    # GPU 서버 input/output 경로

    # seed-VC
    # remote_target = f"/data/msj9518/repos/seed-vc/input/{secure_filename(singer)}.wav"
    # remote_source = f"/data/msj9518/repos/seed-vc/input/{secure_filename(song)}.wav"
    # 결과 파일명 규칙에 맞게 수정 (source=곡명, target=가수명, arg1=1.0, arg2=50, arg3=0.7)
    # arg1 = 1.0
    # arg2 = 50
    # arg3 = 0.7
    # remote_output = f"/data/msj9518/repos/seed-vc/output/vc_{secure_filename(song)}_{secure_filename(singer)}_{arg1}_{arg2}_{arg3}.wav"

    # RVC v2
    remote_input = f"/data/msj9518/repos/rvc-v2/input/{secure_filename(song)}.wav"
    remote_output = f"/data/msj9518/repos/rvc-v2/output/{secure_filename(song)}_{secure_filename(singer)}.wav"

    # SSH 연결
    if ssh_connection is None:
        ssh = connect_ssh()
        close_after = True
    else:
        ssh = ssh_connection
        close_after = False

    # Slurm 작업 제출 (스크립트에서 인자 전달 방식에 맞게)
    # 예시: sbatch ~/convert.sh {remote_source} {remote_target} {remote_output}
    submit_job(ssh)

    # 작업 완료 대기
    wait_for_job_done(ssh, remote_output)

    # 결과 파일 다운로드
    local_result_path = os.path.join(
        DOWNLOAD_FOLDER, f"{secure_filename(singer)}_{secure_filename(song)}.wav"
    )
    download_file(ssh, remote_output, local_result_path)

    if close_after:
        close_ssh(ssh)

    logging.info("[LOG] 변환 완료")
    return send_file(local_result_path, as_attachment=True)


# 가수 검색 요청 처리 (TBD: 추후 구현 예정)
# @app.route("/singers", methods=["GET"])
# def get_singers():
#     print("[LOG] /singers endpoint called")
#     query = request.args.get("query", "")
#     filtered = [s for s in singers if query in s]
#     return jsonify(filtered)


# 선택된 가수 처리
@app.route("/selected_singers", methods=["GET", "POST"])
def handle_selected_singers():
    logging.info("[LOG] /selected_singers endpoint called")
    if request.method == "POST":
        data = request.json
        singer = data.get("singer")
        if singer and singer not in selected_singers:
            selected_singers.append(singer)
        return jsonify(selected_singers)
    return jsonify(selected_singers)


# 변환 모드 처리
@app.route("/conversion_mode", methods=["GET", "POST"])
def handle_conversion_mode():
    logging.info("[LOG] /conversion_mode endpoint called")
    global conversion_mode, ssh_connection
    data = request.json
    conversion_mode = data.get("on", False)
    if conversion_mode and ssh_connection is None:
        ssh_connection = connect_ssh()
        logging.info("[LOG] Conversion mode ON: SSH 연결 생성")
    elif not conversion_mode and ssh_connection is not None:
        close_ssh(ssh_connection)
        ssh_connection = None
        logging.info("[LOG] Conversion mode OFF: SSH 연결 해제")
    else:
        logging.info(
            f"[LOG] Conversion mode 상태 변경: on={conversion_mode}, ssh_connection={'있음' if ssh_connection else '없음'}"
        )
    return jsonify({"on": conversion_mode})


@app.route("/upload_audio", methods=["POST"])
def upload_audio():
    logging.info("[LOG] /upload_audio endpoint called")
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
    logging.info("[LOG] 업로드 완료")
    return "업로드 완료"


@app.route("/get_backend_ip", methods=["GET"])
def get_backend_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = "127.0.0.1"
    finally:
        s.close()
    return jsonify({"ip": ip})


@app.route("/current_track_info", methods=["POST"])
def receive_current_track_info():
    data = request.json
    access_token = data.get("access_token")
    context_uri = data.get("context_uri")
    # ... (기존 track_name, artist 등 필요시 추가)
    # context_uri에서 playlist_id 추출
    if context_uri and context_uri.startswith("spotify:playlist:"):
        playlist_id = context_uri.split(":")[-1]
        from services.spotify_hijack_service import get_playlist_tracks_with_token

        tracks = get_playlist_tracks_with_token(playlist_id, access_token)
        # 원하는 형태로 tracks를 가공하거나 저장
        return jsonify({"tracks": tracks})
    return jsonify({"error": "invalid context_uri"}), 400


if __name__ == "__main__":
    logging.info("[LOG] Server started")
    app.run(host="0.0.0.0", port=5000, debug=True)
