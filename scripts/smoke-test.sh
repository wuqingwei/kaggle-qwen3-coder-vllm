#!/usr/bin/env bash
# 冒烟测试：确认 vLLM 服务在跑、模型能出代码。
# 与 notebooks/kaggle-qwen3-coder-30b-vllm.ipynb 第 6 个 cell 同一个 C++17 题目。
# 用法：./scripts/smoke-test.sh [http://localhost:8000]
set -euo pipefail

BASE="${1:-${VLLM_URL:-http://localhost:8000}}"

echo "== /v1/models =="
curl -s --max-time 10 "$BASE/v1/models" | python3 -m json.tool

echo
echo "== chat completions：C++17 找出现次数最多的元素 =="
curl -s --max-time 300 "$BASE/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "qwen3-coder-30b",
    "temperature": 0.2,
    "max_tokens": 600,
    "messages": [{"role": "user", "content": "用 C++17 写一个函数：输入 std::vector<int>，返回其中出现次数最多的元素，写清时间复杂度，只给代码加一行注释说明思路。"}]
  }' | python3 -c 'import json, sys; d = json.load(sys.stdin); print(d["choices"][0]["message"]["content"]); print("usage:", d.get("usage"))'
