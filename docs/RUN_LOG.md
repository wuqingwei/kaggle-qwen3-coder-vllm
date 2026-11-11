# 运行与验证记录

这份是 2026-11-10 / 11-11 两次实跑的记录，不是教程。数字都是当时实测的，
下次跑耗时和配额会变，以 Kaggle 设置页为准。

## 2026-11-10（第一次跑通）

- 账号：用邮箱走 Google 登录新建 Kaggle 账号，无密码；
  Persona 自拍验证两次返回 completed，手机与身份验证当天复核均为 Verified。
- 免费额度：GPU 30 小时/周、TPU 20 小时/周；Notebook 里 GPU T4 x2、
  TPU v5e-8 均可选，Internet 已开。单次会话最长 12 小时。
- 模型：`QuantTrio/Qwen3-Coder-30B-A3B-Instruct-AWQ`（约 16.8GB）。
  选它的原因：Qwen 官方没发过 AWQ 版，只发 BF16 与 FP8；
  FP8 约 31GB，装不进 Kaggle 的 20GB 磁盘。
- vLLM 0.33.0，T4 x2，`--tensor-parallel-size 2 --enforce-eager
  --max-model-len 65536 --max-num-seqs 2 --enable-auto-tool-choice
  --tool-call-parser qwen3_coder`。`max_model_len` 是从 16384 →
  32768 → 65536 三次重启提上来的（见 docs/TROUBLESHOOTING.md 为什么）。
- 冒烟测试通过：C++17 写“出现次数最多的元素”，38 秒，226 tokens。
- 工具调用正常：经隧道问南京天气，模型正确发起了 `get_weather` 调用。
- 隧道：cloudflared 快速隧道，`https://<随机>.trycloudflare.com`，
  Trae Base URL 为其 + `/v1`，模型 `qwen3-coder-30b`，API Key 任意非空串。
  公网调 `/v1/models` 返回该模型、聊天补全返回 `Hello!`。
- 18:52 诊断（ZCode 发“你好”等几分钟没回）：vLLM 与隧道均存活，
  无 OOM、无报错；原因是那条请求带了约 32769 token 的大提示，
  在 T4 双卡 + `--enforce-eager` 下 prefill 要算好几分钟，GPU 100% 满载，
  ZCode 等不及取消了流；引擎空闲后小请求 0.57 秒就回。
  根治靠客户端缩短上下文（新开对话、少挂文件），不是重启服务。
- 22:45 会话已停（到达时即显示 Draft Session off，无需再按停止），
  隧道已下线，笔记本未删；GPU 最终用量 02:57/30 hrs（本周剩约 27 小时），
  TPU 00:00/20 hrs。

## 2026-11-11（重跑，换新隧道）

- 从本地已修正的 notebook 新导入一份跑，不用 11-10 那个没存上的旧草稿（Version 1）。
  旧 notebook 未删，其会话 09:47 已停（当时在跑旧版 Qwen 仓库/16384/seqs 8）。
- 各步耗时：装 vLLM 500 秒、下模型 49 秒、加载 220 秒、冒烟测试 38.5 秒通过，
  `max_model_len` 65536 已确认。GPU 用量完成时 03:39/30 hrs（剩约 26 小时 21 分）。
- 新隧道地址当次有效，会话结束即失效，下次重建地址会变。
  本机浏览器直接打开新隧道两次被 Cloudflare 拦截显示 blocked，
  但 curl / urllib 均正常，Trae / ZCode 作为 API 客户端应能用，
  若也被拦则重启 cloudflared 换地址。
- 10:37 诊断（ZCode 不带大上下文发“你好”仍等几分钟无回）：
  请求确实到了 vLLM，日志里 10:25–10:30 间来自用户 IP 的 3 次 POST 全部 200，
  GPU 空闲、无 OOM、无报错、Cloudflare 无拦截；10:31:20 有一条隧道流被远端取消；
  空闲小测试 0.706 秒回 `Hello!`。结论是服务端已回、ZCode 端没呈现。
- 10:49 再诊：用户改 65536 后 10:42 重发的“你好”也到了 vLLM、200，
  流式测试首 token 0.38 秒、总 0.72 秒正常，这次无取消、无报错，
  GPU 算完已空闲，问题在 ZCode 侧。会话已用 04:06/30 hrs。
- 10:50 用户发 ZCode 截图：请求耗时中供应商 67 秒、读取返回 67 秒，
  原因为 `the agent canceled the request`——ZCode 等了 67 秒没等到首个 token、
  自己取消了。服务端无报错。这说明这次“你好”的首 token 实际等了 67 秒，
  远超空闲小测试的 0.38 秒，原因是 ZCode 实际发的提示仍很大
  （agent 模式系统提示 + 工具定义）。
- 更正：此前称某个测试 IP 为扫描器是误判，用户 11:07 澄清那是他自己
  用工具测试的，不是外部扫描，隧道未证实被他人占用；
  vLLM 仍未设 Key、公开隧道理论上仍可被他人用，换地址 + 加 Key 仍是可选加固，非紧急。
- 11:07 用户又说 Trae 里也一样没回，说明问题不在 ZCode 一家，
  两家 agent 客户端都发了大隐藏提示、首 token 要等几十秒以上才被取消，
  curl 小测试（14 token）快是因为提示本身小。
- 11:23 用户确认：**chat 模式可用**，已让模型写了个脚本，只是速度慢。
  agent 模式的大隐藏提示问题至此定位完成。
