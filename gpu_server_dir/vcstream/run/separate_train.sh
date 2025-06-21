#!/usr/bin/bash

#SBATCH -J VC_separate_train
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-gpu=8
#SBATCH --mem-per-gpu=29G
#SBATCH -p batch_ugrad
#SBATCH -t 1-0
#SBATCH -w aurora-g1
#SBATCH -o logs/kirby-separate-train-%A.out

SINGER_NAME="$1"
INPUT_DIR="/data/msj9518/repos/vcstream/rvc/train_input/${SINGER_NAME}"
OUTPUT_DIR="/data/msj9518/repos/vcstream/rvc/datasets/${SINGER_NAME}"

mkdir -p "$OUTPUT_DIR"

for file in "$INPUT_DIR"/*.wav; do
  base_name=$(basename "$file" .wav)
  python uvr_cli.py --audio_file "$file" \
    --output_format "WAV" \
    --output_dir "$OUTPUT_DIR" \
    --model_filename "2_HP-UVR.pth" \
    --vr_aggression 10 \
    --single_stem "Vocals"

  for out in "$OUTPUT_DIR"/"${base_name}"*; do
    if [[ -f "$out" && "$out" == *Vocal* ]]; then
      mv "$out" "$OUTPUT_DIR/${base_name}.wav"
      echo "✅ 보컬 저장됨: $OUTPUT_DIR/${base_name}.wav"
    fi
  done
done