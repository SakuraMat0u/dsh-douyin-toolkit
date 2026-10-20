# dsh-douyin-toolkit

把抖音接入 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness)，作为 DSH 的一等公民工具：热榜、搜索、视频、用户、状态自检，外加一套**可轮询的扫码/短信登录状态机**和一条**默认 dry-run 的受控评论**。发布只保留接口，不执行。

> 这是一个 Cordis Host 插件，不是 MCP server；工具直接注册到 `ctx.tools`。

## 和已有项目的区别

GitHub 上已经有一些同类项目。这个仓库不是从零重复造轮子，而是把它们的成熟部分组合成一个完整的 DSH 工具插件：

| 项目 | 关系 |
|---|---|
| [`Youhai020616/douyin`](https://github.com/Youhai020616/douyin)（`dy-cli`） | **直接复用**：热榜、搜索、用户资料的逆向接口、cookie 读取、错误码和 JSON 信封都在这里 |
| [`Kuhakucai/douyin-mcp`](https://github.com/Kuhakucai/douyin-mcp) | 登录态判定（`localStorage.HasUserLogin`）、专用 profile、单 worker 的设计参考 |
| [`WJZ-P/douyin-upload-mcp-skill`](https://github.com/WJZ-P/douyin-upload-mcp-skill) | 多阶段登录状态机的设计参考 |
| [`NanmiCoder/MediaCrawler`](https://github.com/NanmiCoder/MediaCrawler) | `search_id` 链式翻页、翻页风控等已知坑 |
| [`nisew2/dsh-whale-dive`](https://github.com/nisew2/dsh-whale-dive) | 最接近的 DSH 插件：用真实 Edge/CDP 读抖音 hot/feed/video/search/status，只读 |
| [`canadaeee/dsh-douyin`](https://github.com/canadaeee/dsh-douyin) | 同生态，但做的是企业号私信通道，不是内容工具 |

和 `dsh-whale-dive` 的主要差异：

- 只读路径优先走 `dy-cli` 的逆向 API（更快、更省浏览器），接口失效时才回退到页面 XHR；
- 有 `login_start -> login_status -> login_submit` 的扫码/短信状态机，而不是只看 cookie 是否存在；
- 有用户作品、账号指纹、单条评论、发布接口占位；
- 有单 worker、3–8 秒页间抖动、小时配额和指数退避。

## 工具

| 工具 | 入参 | 说明 | 通道 |
|---|---|---|---|
| `douyin_hot` | `count?` | 热榜条目、热度、搜索链接 | 逆向 API |
| `douyin_search` | `keyword`, `limit?`, `pages?`, `cursor?`, `sort?` | 搜索；`next_cursor` 走 `search_id` 链式分页 | 逆向 API |
| `douyin_video` | `aweme_id` 或 `url`, `comment_limit?` | 文案、作者、互动数据、前 N 条评论 | 逆向 API → 浏览器 XHR 回退 |
| `douyin_user` | `user` 或 `sec_uid`, `post_limit?` | 简介、粉丝、近期作品 | 逆向 API + 浏览器 XHR |
| `douyin_status` | — | 一句话结论、登录态、配额、上次错误 | 本地 |
| `douyin_login_start` | — | 打开专用 Edge，返回 `qrcode` 和截图路径 | 浏览器 |
| `douyin_login_status` | — | 轮询 `idle/qrcode/sms_*/challenge_required/logged_in/expired/failed/stopped` | 本地/浏览器 |
| `douyin_login_submit` | `codes` | 提交 4–8 位短信验证码 | 浏览器 |
| `douyin_verify` | `keyword?`, `timeout_seconds?` | 打开验证页让你手动过滑块/验证，插件只轮询 | 浏览器 |
| `douyin_comment` | `aweme_id` 或 `url`, `content`, `dry_run?`, `confirm?` | 单条评论；`dry_run` 默认 `true` | 浏览器 |
| `douyin_publish` | 接口参数 | 恒返回 `implemented:false`，不发请求 | — |

## 架构

```
DSH Cordis 插件（dsh-douyin-toolkit）
  ├─ 工具注册 / 参数校验 / 错误码 / 限频 / 配额 / 并发锁 / 日志脱敏
  ├─ 只读后端：dy-cli（子进程）
  │    ├─ 热榜、用户资料、视频详情：python -m dy_cli.main <cmd> --json-output
  │    └─ 搜索：python dy_query.py search（复用 dy-cli client，只补 offset + search_id）
  └─ 浏览器后端：系统 Edge（Playwright，独立 profile）
       ├─ 扫码 / 短信登录状态机
       ├─ 视频详情与评论：截获页面自己发出的签名 XHR
       ├─ 用户作品：截获页面自己发出的签名 XHR
       └─ 单条评论
```

插件本身不实现 X-Bogus、不重写登录协议、不绕过验证码。

## 环境要求

- Windows（当前只在 Windows 上实测；代码里没有 Windows 专属 API，但 Edge 路径发现和 profile 清理是 Windows 优先）
- Python 3.10+（实测 3.14）
- Node.js 22+（DSH 自带）
- 系统已安装 Microsoft Edge。默认路径：
  `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`
- 不需要 `playwright install chromium`，也不使用 Chrome

## 安装

### 方式 A：克隆到固定目录（推荐）

```powershell
git clone https://github.com/SakuraMat0u/dsh-douyin-toolkit.git
cd dsh-douyin-toolkit
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r python\requirements.txt
```

然后用插件管理器把它作为本地 bundle 安装，target 传这个克隆目录的绝对路径：

```text
plugin_manager install_bundle  target = <克隆目录>
```

或者用 DSH 的插件命令：

```powershell
dsh plugin --profile desktop add <克隆目录的绝对路径>
```

这样 `.venv` 就在插件包旁边，`pythonPath` 不需要额外配置，`data/` 也默认落在这个目录里。

### 方式 B：直接从 GitHub 安装

```powershell
dsh plugin --profile desktop add github:SakuraMat0u/dsh-douyin-toolkit
```

pnpm 安装的是包副本，不会带 `.venv`。安装后需要在 profile 的 `cordis.patch.yml` 里补两项配置：

```yaml
- id: douyin
  name: dsh-douyin-toolkit
  config:
    pythonPath: C:\path\to\python.exe   # 已安装 dy-cli 和 playwright 的解释器
    dataDir: C:\path\to\writable\dir    # 专用 Edge profile、cookie、日志都写这里
```

无论哪种方式，改完配置后重启 DSH。

## 挂载与配置

bundle 自带 `cordis.patch.yml`，安装时会插入：

```yaml
- insert:
    - id: douyin
      name: dsh-douyin-toolkit
      config:
        enabled: true
        writesEnabled: false
        ...
```

不要再用 `insert` 手工挂同一个 id；要改配置，在 profile 的 `cordis.patch.yml` 顶层加同 id 覆盖行：

```yaml
- id: douyin
  name: dsh-douyin-toolkit
  config:
    writesEnabled: true
    maxSearchPages: 2
```

或者用启动时的额外 patch 层：

```powershell
dsh --profile desktop --patch <仓库>\examples\standalone.patch.yml
```

配置合成结果可以用 `dsh --profile desktop --dump-config` 检查。

### 配置项

| 字段 | 默认 | 说明 |
|---|---|---|
| `enabled` | `true` | 关闭后不注册任何工具 |
| `writesEnabled` | `false` | 写操作总开关；为 false 时 `douyin_comment` 只返回 `writes_disabled` |
| `toolEnabled` | 全部 `true` | 每条工具单独开关：`hot` / `search` / `video` / `user` / `status` / `login` / `verify` / `comment` / `publish`；设为 `false` 就不注册该工具 |
| `maxResults` | `20` | 单次返回上限，硬上限 20 |
| `maxSearchPages` | `3` | 单次搜索最多翻页数，硬上限 3 |
| `hourlyRequestBudget` | `60` | 滚动 1 小时的后端请求预算 |
| `pageDelayMinMs` / `pageDelayMaxMs` | `3000` / `8000` | 翻页之间的高斯抖动区间 |
| `callDelayMinMs` / `callDelayMaxMs` | `1800` / `3200` | 独立调用之间的最小间隔 |
| `pythonPath` | 空 | 默认 `<插件目录>\.venv\Scripts\python.exe` |
| `dataDir` | 空 | 默认 `<插件目录>\data` |
| `edgePath` | 空 | 默认自动发现系统 Edge |
| `logLevel` | `info` | `silent` / `error` / `info` / `debug` |

## 登录状态机

1. `douyin_login_start`：打开独立 Edge（`<dataDir>\browser-profile`），返回 `phase: qrcode` 和二维码截图路径。
2. 用抖音 App 扫码，在手机上确认。
3. 轮询 `douyin_login_status`。成功后插件把 `storage_state` 写到
   `<dataDir>\home\.dy\cookies\default.json`（`dy-cli` 读取的路径），并记录 `sec_uid`、昵称和作品指纹。
4. 若切到验证码登录：先自己填手机号，再调用 `douyin_login_submit` 传 `codes`。
5. 若出现滑块/安全验证：插件不会绕过。调用 `douyin_verify` 打开可见窗口，手动完成后重试。

只有同时满足以下条件才判定为已登录：

- 页面 `localStorage.HasUserLogin` 为真，或
- cookie 中存在 `sessionid` / `sessionid_ss`（兜底）

两者都拿不到时返回 `unknown`，不会武断报「未登录」，也不会自动触发重新登录。

`login_start` 每次启动都会重置登录状态；换号后旧 `sec_uid` 不会沿用。账号与首次记录不一致时，写工具返回 `account_mismatch`，删除 `<dataDir>\state\account.json` 后重试。

## 风控与数据语义

- 全局单 worker，并发 1；所有 dy / 浏览器调用串行。
- 翻页之间 3–8 秒高斯抖动；独立调用之间 1.8–3.2 秒。
- 滚动 1 小时请求预算，默认 60；`douyin_status` 显示已用/剩余。
- 触发 `rate_limited` / `challenge_required` 后指数退避（1、2、4、8、15 分钟），不立即重试。
- 搜索返回 `verify_check` 时映射为 `challenge_required`，不会静默返回 0 条。
- 缺失字段一律 `null`，不填 0、不猜。
- 部分成功返回 `partial: true` + `failures[]` + `coverage`。
- 分页使用不透明 `next_cursor`，不要用页码推算。
- 错误码固定：`not_authenticated` / `challenge_required` / `rate_limited` / `not_found` / `parse_failed` / `profile_in_use` / `backend_unavailable`；写操作另有 `account_mismatch`、`invalid_args`。
- cookie、`sessionid`、`passport_*`、`localStorage`、`storage_state` 不会进入工具返回值、日志或报错。

## 故障排查

| 现象 | 处理 |
|---|---|
| `profile_in_use` | 专用 profile 已被登录窗口占用；先 `douyin_login_status`，或关闭那个 Edge 窗口。插件只会清理命令行里带本插件 profile 的 Edge 进程。 |
| `not_authenticated` | 调用 `douyin_login_start` 重新扫码；不会静默重试。 |
| `challenge_required` | 调用 `douyin_verify`，在可见窗口手动完成验证。 |
| `backend_unavailable` + 找不到 Python | 检查 `<插件目录>\.venv\Scripts\python.exe` 是否存在，或配置 `pythonPath`。 |
| `backend_unavailable` + Playwright 启动失败 | 确认 Edge 路径；插件会先清理自己的残留 Edge 再重试一次。Edge 自动更新替换 `msedge.exe` 时属于偶发断连，重启登录即可。 |
| 控制台中文乱码 | 插件已给子进程设置 `PYTHONIOENCODING=utf-8` / `PYTHONUTF8=1`；手工执行时也要设置。 |
| 搜索/详情为空 | 先看 `douyin_status` 的 `last_error`；如果是 `challenge_required`，按上一条处理。 |
| `dataDir` 不可写 | 方式 B 从 pnpm 安装时尤其常见；把 `dataDir` 指到一个可写目录。 |

插件把子进程的 `USERPROFILE` / `HOME` / `TMP` / `TEMP` 都重定向到 `<dataDir>\home` 和 `<dataDir>\tmp`，因此 `dy-cli` 的 `~/.dy` 落在插件数据目录内，不会污染日常 `.dy` 或浏览器 profile。

## 自检

```powershell
powershell -ExecutionPolicy Bypass -File scripts\selfcheck.ps1
```

它会打印 Python/Edge 探测结果、桥接状态和一次真实热榜（3 条）。在 DSH 里也可以直接调用 `douyin_status`。

## 加一个新工具

1. 在 `lib/tools.js` 的 `createTools()` 数组里加一个 `defineTool({...})`。
2. `parameters` 用作者 DSL：属性上的 `required: true` 会被本地 `defineTool` 提升为对象级 `required`。
3. 只读命令优先走 `backend.runDy([...])` 或 `backend.runDyQuery([...])`；需要浏览器时走 `backend.runBrowser(command, [...])`。
4. 结果先用 `lib/normalize.js` 归一化，再 `return backendNote({...})`；不要返回 cookie/localStorage。
5. 在 `cordis.patch.yml`、`README.md` 和 `lib/tools.js` 的开关映射里补一行，重新安装 bundle。

## 能力边界

能做的：

- 读热榜、按关键词搜索、`search_id` 链式翻页、读视频详情与前 N 条评论、读用户资料与近期作品。
- 用专用 Edge profile 扫码/短信登录，状态可轮询、可中断、可重试。
- 发出**单条**评论（默认 dry-run，且默认 `writesEnabled:false`）。

不能做 / 不做的：

- 批量评论、批量点赞、批量关注、私信群发、养号、多账号矩阵。
- 自动过验证码、接打码平台、新的签名逆向。
- headless 运行这个小号。
- 未经确认的发布；`douyin_publish` 只保留接口。

明显提高风控的操作：

- 高频搜索/翻页、短时间重复同一关键词、无间隔连续调用。
- 在没有登录态时反复请求搜索/详情。
- 用同一个 profile 同时开多个浏览器/插件实例。

## 安全

- `<dataDir>` 含 cookie、登录状态和账号指纹，**不要提交、不要分享**。
- 工具返回值和日志都做了凭证脱敏。
- 写操作默认关闭，真实发送需要 `writesEnabled: true` + `dry_run: false` + `confirm: true`。
- 插件不会自动解决验证码，也不会把 cookie 发给第三方。

## 许可与致谢

MIT。见 [LICENSE](LICENSE)。

感谢 `dy-cli`、`douyin-mcp`、`douyin-upload-mcp-skill`、`MediaCrawler` 和 `dsh-whale-dive` 的作者；这个项目主要是在它们的基础上做集成和 DSH 适配。