#!/usr/bin/bash
#SBATCH -J VC_train_atoz
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-gpu=8
#SBATCH --mem-per-gpu=29G
#SBATCH -p batch_ugrad
#SBATCH -t 1-0
#SBATCH -w aurora-g1
#SBATCH -o logs/kirby-train-%A.out

# 가수 이름이 인자로 전달되지 않으면 사용법 출력
if [ $# -eq 0 ]; then
    echo "사용법: $0 <가수_이름>"
    echo "예시: $0 kim"
    exit 1
fi

# 가수 이름을 첫 번째 인자로 받음
SINGER_NAME=$1

python /data/msj9518/repos/rvc-cli/rvc_cli.py preprocess \
--model_name "/local_datasets/msj9518/$SINGER_NAME" \
--dataset_path "/data/msj9518/repos/vcstream/rvc/datasets/$SINGER_NAME" \
--sample_rate 48000 \
--cpu_cores 8 \
--cut_preprocess Automatic \
--process_effects False \
--noise_reduction False \
--noise_reduction_strength 0.7 \
&& python /data/msj9518/repos/rvc-cli/rvc_cli.py extract \
--model_name "/local_datasets/msj9518/$SINGER_NAME" \
--f0_method "rmvpe" \
--sample_rate 48000 \
--cpu_cores 8 \
--include_mutes 2 \
--embedder_model "contentvec" \
&& python /data/msj9518/repos/rvc-cli/rvc_cli.py train \
--model_name "/local_datasets/msj9518/$SINGER_NAME" \
--vocoder "HiFi-GAN" \
--checkpointing False \
--save_every_epoch 1 \
--sample_rate 48000 \
--pretrained True \
--total_epoch 5 \
--batch_size 16

# 소스 디렉토리와 대상 디렉토리 설정
SOURCE_DIR="/local_datasets/msj9518/$SINGER_NAME"
TARGET_DIR="/data/msj9518/repos/vcstream/rvc/models/$SINGER_NAME"

# 대상 디렉토리가 없으면 생성
mkdir -p "$TARGET_DIR"

# best 파일이 이미 있으면 복사하지 않음
if [ -f "$TARGET_DIR/${SINGER_NAME}_best.pth" ]; then
    echo "$TARGET_DIR/${SINGER_NAME}_best.pth 파일이 이미 존재합니다. 복사하지 않습니다."
else
    # best_model_info.json에서 best epoch 읽기
    BEST_INFO_FILE="$SOURCE_DIR/best_model_info.json"
    if [ ! -f "$BEST_INFO_FILE" ]; then
        echo "Error: best_model_info.json 파일을 찾을 수 없습니다."
        exit 1
    fi
    BEST_EPOCH=$(jq .epoch "$BEST_INFO_FILE")

    # 가장 가까운 epoch의 pth 파일 찾기
    BEST_PTH=$(ls "$SOURCE_DIR"/${SINGER_NAME}_*e_*.pth 2>/dev/null | awk -F'[_e]' -v best="$BEST_EPOCH" '{
        split($2, arr, "e");
        epoch=arr[1];
        diff=(epoch>best)?epoch-best:best-epoch;
        print diff, $0
    }' | sort -n | head -n1 | cut -d' ' -f2-)

    if [ -z "$BEST_PTH" ]; then
        echo "Error: best epoch에 해당하는 pth 파일을 찾을 수 없습니다."
        exit 1
    fi

    # index 파일 확인
    if [ ! -f "$SOURCE_DIR/${SINGER_NAME}.index" ]; then
        echo "Error: ${SINGER_NAME}.index 파일을 찾을 수 없습니다."
        exit 1
    fi

    # best 파일만 복사
    cp "$BEST_PTH" "$TARGET_DIR/${SINGER_NAME}_best.pth"
    cp "$SOURCE_DIR/${SINGER_NAME}.index" "$TARGET_DIR/"

    echo "모델 파일이 성공적으로 복사되었습니다."
    echo "복사된 파일:"
    echo "- $TARGET_DIR/${SINGER_NAME}_best.pth"
    echo "- $TARGET_DIR/${SINGER_NAME}.index"
fi