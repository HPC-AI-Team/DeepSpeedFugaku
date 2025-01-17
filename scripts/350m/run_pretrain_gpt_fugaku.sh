#!/bin/bash -x
#PJM -L "rscgrp=small"
#PJM -L elapse=2:00:00
#PJM -L "node=4"
#PJM --mpi "proc=4"
#PJM --mpi "max-proc-per-node=1"
#PJM -g hp230257
#PJM -j
#PJM -S

# source /data/hp190122/share/PyTorch-1.10.1/env.src
# export PYTHONUSERBASE=$HOME/work/.local
# export PATH=$PATH:$PYTHONUSERBASE/bin
source /vol0001/hp230257/zhangxiangyu/env.sh

export TORCH_EXTENSIONS_DIR=/home/u12219/data/zhangxiangyu/torch_extension
# Change for multinode config
CPUS_PER_NODE=1
NNODES=4
NODE_RANK=0
export WORLD_SIZE=$(($CPUS_PER_NODE * $NNODES))
export MASTER_ADDR=localhost
export MASTER_PORT=$((10000 + ($PJM_JOBID % 50000)))
CHECKPOINT_PATH=checkpoints/pretrain_gpt2/
INPUT_PREFIX=/home/u12219/data/zhangxiangyu/wiki/gpt/
VOCAB_FILE=gpt2-vocab.json
MERGE_FILE=gpt2-merges.txt
DATA_PATH=/vol0003/mdt0/data/hp230257/zhangxiangyu/wiki/gpt/my_gpt_text_document
TENSORBOARD_ARGS="--tensorboard-dir experiments/tensorboard"

output_path="jobs/mpi_outs/${PJM_JOBID}_n${nodos}"
DISTRIBUTED_ARGS="-np $NNODES -std-proc ${output_path}/stdproc"

DATA_PARALLEL_SIZE=4

PIPELINE_MODEL_PARALLEL_SIZE=1
TENSOR_MODEL_PARALLEL_SIZE=1
PIPELINE_PARALLEL_ARGS="--pipeline-model-parallel-size $PIPELINE_MODEL_PARALLEL_SIZE"
MODEL_PARALLEL_ARGS="--tensor-model-parallel-size $TENSOR_MODEL_PARALLEL_SIZE"
DATA_PARALLEL_ARGS="--DDP-impl local"
PARALLEL_ARGS="$MODEL_PARALLEL_ARGS $DATA_PARALLEL_ARGS $PIPELINE_PARALLEL_ARGS"

export OMP_NUM_THREADS=48

mpirun $DISTRIBUTED_ARGS \
  python pretrain_gpt.py \
  --num-layers 24 \
  --hidden-size 1024 \
  --num-attention-heads 16 \
  --micro-batch-size 1 \
  --global-batch-size 4 \
  --seq-length 1024 \
  --max-position-embeddings 1024 \
  --train-iters 500000 \
  --lr-decay-iters 320000 \
  --save $CHECKPOINT_PATH \
  --load $CHECKPOINT_PATH \
  --data-path $DATA_PATH \
  --vocab-file $INPUT_PREFIX/$VOCAB_FILE \
  --merge-file $INPUT_PREFIX/$MERGE_FILE \
  --data-impl mmap \
  --split 949,50,1 \
  --distributed-backend mpi \
  --lr 0.00015 \
  --min-lr 1.0e-5 \
  --lr-decay-style cosine \
  --weight-decay 1e-2 \
  --clip-grad 1.0 \
  --lr-warmup-fraction .01 \
  --log-interval 1 \
  --save-interval 1000 \
  --eval-interval 100 \
  --eval-iters 10 \
  --no-cuda \
  --checkpoint-activations \
  --use-cpu-initialization \
  --num-workers 0 \
  --no-load-rng \
  $PARALLEL_ARGS \
  $TENSORBOARD_ARGS \
  --log-batch-size-to-tensorboard \
  --log-validation-ppl-to-tensorboard \
  --log-timers-to-tensorboard \
  # --wandb-name "ja-wiki-350m_dp4"