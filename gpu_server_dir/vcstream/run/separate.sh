#!/usr/bin/bash

#SBATCH -J VC_separate
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-gpu=8
#SBATCH --mem-per-gpu=29G
#SBATCH -p batch_ugrad
#SBATCH -t 1-0
#SBATCH -o logs/kirby-separate-%A.out

INPUT_DIR="/data/msj9518/repos/vcstream/rvc/input"
OUTPUT_ROOT="/data/msj9518/repos/vcstream/rvc/hidden"
VOCAL_DIR="${OUTPUT_ROOT}/vocal"
INST_DIR="${OUTPUT_ROOT}/inst"

mkdir -p "$VOCAL_DIR"
mkdir -p "$INST_DIR"

for file in "$INPUT_DIR"/*.wav; do
  base_name=$(basename "$file" .wav)
  python uvr_cli.py --audio_file "$file" \
    --output_format "WAV" \
    --output_dir "$OUTPUT_ROOT" \
    --model_filename "2_HP-UVR.pth" \
    --vr_aggression 10

  for out in "$OUTPUT_ROOT"/"${base_name}"*; do
    if [[ -f "$out" ]]; then
      if [[ "$out" == *Vocal* ]]; then
        mv "$out" "$VOCAL_DIR/${base_name}_vocal.wav"
        echo "✅ 보컬 저장됨: $VOCAL_DIR/${base_name}_vocal.wav"
      elif [[ "$out" == *Instrumental* ]]; then
        mv "$out" "$INST_DIR/${base_name}_inst.wav"
        echo "✅ 반주 저장됨: $INST_DIR/${base_name}_inst.wav"
      fi
    fi
  done
done