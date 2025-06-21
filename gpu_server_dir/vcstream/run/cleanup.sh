#!/usr/bin/bash

#SBATCH -J VC_cleanup
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-gpu=8
#SBATCH --mem-per-gpu=29G
#SBATCH -p batch_ugrad
#SBATCH -w aurora-g1
#SBATCH -t 1-0

rm -rf /data/msj9518/repos/vcstream/rvc/input/*
rm -rf /data/msj9518/repos/vcstream/rvc/output/*
rm -rf /data/msj9518/repos/vcstream/rvc/combined/*
rm -rf /data/msj9518/repos/vcstream/rvc/hidden/inst/*
rm -rf /data/msj9518/repos/vcstream/rvc/hidden/vocal/*
