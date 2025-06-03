import logging
from services.ssh_service import submit_job


def separate_vocals_on_gpu_server(ssh):
    """
    GPU 서버에서 보컬 분리 명령을 실행하는 함수
    :param ssh: paramiko SSHClient 객체
    :return: (성공 여부, 로그/메시지)
    """
    run_sh_path = "/data/msj9518/repos/vcstream/run/separate.sh"
    result = submit_job(ssh, run_sh_path=run_sh_path)
    # 결과 처리 및 로깅
    return result
