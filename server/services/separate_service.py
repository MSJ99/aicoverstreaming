import logging
from services.ssh_service import submit_job


def separate_vocals_on_gpu_server(ssh):
    """
    곡 변환용 보컬 분리 (separate.sh)
    :param ssh: paramiko SSHClient 객체
    :return: (성공 여부, 로그/메시지)
    """
    command = f"cd /data/msj9518/repos/rvc-cli && source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && sbatch /data/msj9518/repos/vcstream/run/separate.sh"
    result = submit_job(ssh, command)
    # 결과 처리 및 로깅
    return result


def separate_vocals_for_training(ssh, singer_name):
    """
    학습용 보컬 분리 (separate_train.sh)
    :param ssh: paramiko SSHClient 객체
    :param singer_name: 가수이름
    :return: (성공 여부, 로그/메시지)
    """
    command = f"cd /data/msj9518/repos/rvc-cli && source /data/msj9518/anaconda3/etc/profile.d/conda.sh && conda activate rvc && sbatch /data/msj9518/repos/vcstream/run/separate_train.sh '{singer_name}'"
    result = submit_job(ssh, command)
    return result
