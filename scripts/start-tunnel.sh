#!/usr/bin/env bash
# 把本机 8000 端口的 vLLM 用 cloudflared 快速隧道带到公网。
# 在 Kaggle notebook 的 terminal 里跑；隧道地址每次重建都会变，看 tunnel.log 里那行
# https://xxx.trycloudflare.com，Trae / ZCode 的 Base URL 填它 + /v1。
# 注意：vLLM 默认不设 API Key，这个地址谁拿到都能免 Key 用，不要外发；
# 会话结束隧道即失效，下次重建。想加鉴权见 docs/TROUBLESHOOTING.md。
set -euo pipefail

WORK="${WORK:-/kaggle/working}"
CLOUDFLARED="$WORK/cloudflared"
LOG="$WORK/cloudflared.log"

if [ ! -x "$CLOUDFLARED" ]; then
  echo "下载 cloudflared ..."
  curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 \
    -o "$CLOUDFLARED"
  chmod +x "$CLOUDFLARED"
fi

curl -s --max-time 10 http://localhost:8000/v1/models > /dev/null \
  || { echo "vLLM 还没起来（http://localhost:8000 不通），先跑 start-vllm.sh。" >&2; exit 1; }

nohup "$CLOUDFLARED" tunnel --url http://localhost:8000 > "$LOG" 2>&1 &
echo "隧道已启动，日志：$LOG"
echo "等几秒后执行：grep -o 'https://[^ ]*trycloudflare.com' $LOG | head -1"
