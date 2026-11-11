# Kaggle 免费 GPU 跑 Qwen3-Coder-30B-A3B（vLLM 双卡版）

用 Kaggle 免费 GPU（T4 x2）跑 Qwen3-Coder-30B-A3B 写代码，
走 OpenAI 兼容接口给本地 Trae / ZCode / VS Code + Continue 用。
2026-11-10 / 11-11 两次实跑通过，过程和排障见 `docs/RUN_LOG.md`。

## 方案一览

| | 主方案（已验证） | 备选（草稿，未实测） |
|---|---|---|
| 模型 | Qwen3-Coder-30B-A3B-AWQ（约 16.8GB） | Qwen2.5-Coder-14B（约 9GB） |
| 仓库 | `QuantTrio/Qwen3-Coder-30B-A3B-Instruct-AWQ` | `qwen2.5-coder:14b` |
| 服务 | vLLM 0.33.0，`--tensor-parallel-size 2` | Ollama |
| Notebook | `notebooks/kaggle-qwen3-coder-30b-vllm.ipynb` | `notebooks/kaggle-qwen2.5-coder-14b-ollama.ipynb` |
| 客户端配置 | `configs/continue-config-qwen3-coder-30b.yaml` | `configs/continue-config-qwen2.5-coder-14b.yaml` |

为什么用 vLLM 而不用 Ollama 跑 30B：Ollama 默认只用一张卡，
19GB 的模型单张 16GB T4 装不下；vLLM 用 `--tensor-parallel-size 2`
把模型拆到两张 T4 上，这是这套配置的关键。

为什么是 QuantTrio 的 AWQ：Qwen 官方没发过 AWQ 版，只发 BF16 与 FP8；
FP8 约 31GB，装不进 Kaggle 的 20GB 磁盘。

## 前置条件

- Kaggle 账号：Gmail 走 Google 登录新建，无密码；
  要过 Persona 自拍验证（手机与身份均需 Verified）。
- 免费额度约 **30 GPU 小时/周 + 20 TPU 小时/周**，单次会话最长 **12 小时**；
  右上角看会话计时，用完就停，别挂着空跑。
- 新建 notebook 时：Accelerator 选 **GPU T4 x2**，
  右侧 Settings 里 **Internet 必须 ON**（否则拉不到 vLLM 和模型）。

## 快速开始

1. 把 `notebooks/kaggle-qwen3-coder-30b-vllm.ipynb` 导入 Kaggle
   （直接上传，不要在 Kaggle 编辑器里改——编辑器有草稿保存失败的毛病，
   见 `docs/TROUBLESHOOTING.md` 第 3 条）。
2. 点 **Start session**，等状态变 Running（分配两张 T4，一般 1–3 分钟）。
3. 按顺序跑 cell：先验环境 → 装 vLLM → 下模型 → 起服务 →
   等服务起来 → 冒烟测试。2026-11-11 实测耗时：
   装 vLLM 约 500 秒、下模型 49 秒、加载 220 秒、冒烟测试 38.5 秒。
4. 起隧道（notebook terminal 里）：
   ```bash
   ./scripts/start-tunnel.sh
   # 看 cloudflared.log 里那行 https://xxx.trycloudflare.com
   ```
   也可以直接跑 `scripts/start-vllm.sh` / `scripts/smoke-test.sh`
   代替 notebook 里对应的 cell。
5. 本地 Trae / ZCode 里改配置（OpenAI 兼容格式）：
   - Base URL：`https://<隧道地址>/v1`
   - 模型：`qwen3-coder-30b`
   - API Key：任意非空串，如 `sk-kaggle-local`
   - Max Tokens：8192
6. 用完在 Kaggle 页面点 **Stop session** 停掉，省配额。
   会话结束模型、隧道全没，下次重跑要重新下模型（约 16.8GB）。

## 关键参数（别乱改）

- `--tensor-parallel-size 2`：双卡拆分。
- `--enforce-eager`：T4 是 Turing 架构（算力 7.5），不支持 FlashAttention 2，
  不能开 CUDA graphs。
- `--max-model-len 65536`：两张 T4 显存的上限附近，再往上提会 OOM。
- `--max-num-seqs 2`：T4 上并发别贪多。
- `--enable-auto-tool-choice --tool-call-parser qwen3_coder`：工具调用。

## 速度预期

T4 上 30B-A3B 是 MoE（每 token 只激活约 3.3B），比同等 dense 30B 快，
但 T4 本身不快，别跟本地 4090 比。冒烟测试（C++17 短函数）约 38 秒；
长输出、写脚本要等更久，是正常的。

**重要**：日常写代码用 **chat 模式**（普通聊天，不带 agent 工具）。
agent 模式会发几万 token 的隐藏提示（系统提示 + 工具定义 + 历史），
首 token 要等几十秒到几分钟，客户端等不及就取消了——
这不是服务挂了，2026-11-10 / 11-11 两次都定位到这点，
chat 模式已验证可用。详见 `docs/TROUBLESHOOTING.md` 第 1 条。

## 安全提醒

- vLLM 默认不设 API Key，隧道地址谁拿到都能免费用，并行只有 2 个；
  **不要把隧道地址外发**。地址每次重建都会变，会话结束即失效。
- 想加固：重启 cloudflared 换地址 + 启动 vLLM 加 `--api-key`，
  客户端填同一个 Key（见 `docs/TROUBLESHOOTING.md` 第 6 条）。
- 模型只在当前会话有效，`/kaggle/working` 下的东西会话结束不保留。
