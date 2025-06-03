import logging


def separate_vocals_on_gpu_server(ssh, remote_input_path, remote_hidden_dir):
    """
    GPU 서버에서 보컬 분리 명령을 실행합니다.
    :param ssh: paramiko SSHClient 객체
    :param remote_input_path: GPU 서버의 입력 음원 경로 (예: /data/msj9518/repos/vcstream/rvc/input/xxx.wav)
    :param remote_hidden_dir: 보컬 분리 결과 저장 경로 (예: /data/msj9518/repos/vcstream/rvc/hidden)
    :return: (성공 여부, 로그/메시지)
    """
    # 실제 명령어는 환경에 맞게 수정 필요
    command = f"python /data/msj9518/repos/vcstream/separate.py --input {remote_input_path} --output {remote_hidden_dir}"
    logging.info(f"[보컬 분리] 명령 실행: {command}")
    stdin, stdout, stderr = ssh.exec_command(command)
    out = stdout.read().decode()
    err = stderr.read().decode()
    if err:
        logging.error(f"[보컬 분리] 에러: {err}")
        return False, err
    logging.info(f"[보컬 분리] 결과: {out}")
    return True, out
