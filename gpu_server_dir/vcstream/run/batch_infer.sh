#!/usr/bin/bash

#SBATCH -J VC_batch_infer
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-gpu=8
#SBATCH --mem-per-gpu=29G
#SBATCH -p batch_ugrad
#SBATCH -w aurora-g1
#SBATCH -t 1-0
#SBATCH -o logs/kirby-batch-infer-%A.out

SINGER_NAME="$1"
MODEL_DIR="/data/msj9518/repos/vcstream/rvc/models/${SINGER_NAME}"
PTH_PATH="$MODEL_DIR/${SINGER_NAME}_best.pth"
INDEX_PATH="$MODEL_DIR/${SINGER_NAME}.index"

if [ ! -f "$PTH_PATH" ]; then
  echo "[ERROR] Model file not found: $PTH_PATH"
  exit 1
fi

python /data/msj9518/repos/rvc-cli/rvc_cli.py batch_infer \
--input_folder "/data/msj9518/repos/vcstream/rvc/hidden/vocal" \
--output_folder "/data/msj9518/repos/vcstream/rvc/output" \
--pth_path "$PTH_PATH" \
--index_path "$INDEX_PATH" \
