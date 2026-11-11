#!/usr/bin/env bash
# 在 Kaggle notebook 的 terminal 里跑：以后台方式启动 vLLM OpenAI 兼容服务。
# 与 notebooks/kaggle-qwen3-coder-30b-vllm.ipynb 第 4 个 cell 完全一致的参数。
# 先决条件：模型已下到 /kaggle/working/Qwen3-Coder-30B-A3B-AWQ（见 notebook 第 3 个 cell）。
set -euo pipefail

MODEL_DIR="${MODEL_DIR:-/kaggle/working/Qwen3-Coder-30B-A3B-AWQ}"
LOG="${LOG:-/kaggle/working/vllm.log}"

if [ ! -d "$MODEL_DIR" ]; then
  echo "模型目录不存在：$MODEL_DIR，先跑 notebook 第 3 个 cell 下载模型。" >&2
  exit 1
fi

nohup python3 -m vllm.entrypoints.openai.api_server \
  --model "$MODEL_DIR" \
  --served-model-name qwen3-coder-30b \
  --host 0.0.0.0 --port 8000 \
  --tensor-parallel-size 2 \
  --max-model-len 65536 \
  --gpu-memory-utilization 0.90 \
  --max-num-seqs 2 \
  --enforce-eager \
  --enable-auto-tool-choice \
  --tool-call-parser qwen3_coder \
  --disable-log-stats \
  > "$LOG" 2>&1 &

echo "vLLM 已以后台启动，日志：$LOG"
echo "等几分钟后用 ./scripts/smoke-test.sh 验证，或 curl http://localhost:8000/v1/models"
