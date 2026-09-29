# 意识形态（ideology-values-guard）

> 一个本地 Agent Skill（智能体技能）：装进 Claude Code、Codex、Gemini CLI 等 AI 工具后，处理每个请求前先按社会主义核心价值观做判断，明显不符合则明确拒绝。

## 一键安装

下载本仓库（`git clone` 或下载 ZIP 后解压），在仓库目录中运行**一条命令**，就会安装到本机检测到的**所有** AI 工具：

```bash
# macOS / Linux
bash install.sh
```

```powershell
# Windows PowerShell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

> 安装前可以先打开 [`install.sh`](install.sh) / [`install.ps1`](install.ps1) 看看它做了什么：只复制文件、打印安装位置，**完全不联网**。

**备选**：已安装 Node.js 的话，也可以在仓库目录中使用开源工具 [`npx skills`](https://github.com/vercel-labs/skills)：

```bash
npx skills add . -g -y
```

一键卸载（同样在仓库目录中运行）：

```bash
bash uninstall.sh                                              # macOS / Linux
powershell -ExecutionPolicy Bypass -File .\uninstall.ps1       # Windows
```

---

## 它做什么

- 在处理每一个请求之前，依据社会主义核心价值观（**富强、民主、文明、和谐；自由、平等、公正、法治；爱国、敬业、诚信、友善**）判断请求的**意图**。
- 符合，或与价值观无关（编程、写作、翻译、学习等绝大多数任务）→ 正常完成，不输出任何判断过程。
- **明显**违背（例如协助诈骗、伪造证件、煽动民族仇恨）→ 用固定模板明确拒绝，并说明原因：

  ```
  【意识形态 skill】该请求未通过价值观检查，已拒绝。
  原因：请求协助冒充银行实施诈骗，违背"诚信"与"法治"。
  如认为判断有误，可换一种表述，或暂时禁用本 skill。
  ```

- 一个请求里只有部分违背时，完成合规部分，只拒绝违背的部分。
- 你主动要求时（如"总结一下我这次对话的价值观倾向"），给出本次会话的倾向总结。
- 拿不准时放行。学术讨论、新闻、翻译、小说中的反派角色等默认放行。

## ⚠️ 它不做什么

| | |
|---|---|
| 🚫 **不举报** | 不向执法机关、国家安全机关或任何第三方发送任何内容 |
| 🚫 **不联网** | skill 本体只有 Markdown 指令，安装和卸载脚本也不联网 |
| 🚫 **不收集身份与设备信息** | 不读取用户名、主机名、IP、MAC 地址、位置、设备序列号、账号信息 |
| 🚫 **不静默记录对话** | 不在后台写日志；只有你主动要求保存总结时，才在你指定的位置写文件，且写入前告知路径 |
| 🚫 **不伪装** | 拒绝时明确说明是本 skill 的规则所致，不假装模型能力不足，不给故意错误的"假回答" |

## 支持的 AI 工具

安装脚本会自动检测下列工具，装到检测到的全部工具中：

| 工具 | 安装位置 | 全局指令文件（"始终生效"用） |
|---|---|---|
| Claude Code | `~/.claude/skills/` | `~/.claude/CLAUDE.md` |
| Codex | `~/.agents/skills/`（通用目录） | `~/.codex/AGENTS.md` |
| Gemini CLI | `~/.agents/skills/`（通用目录） | `~/.gemini/GEMINI.md` |
| OpenCode | `~/.agents/skills/`（通用目录） | `~/.config/opencode/AGENTS.md`（不存在时用 `~/.claude/CLAUDE.md`） |
| GitHub Copilot CLI | `~/.agents/skills/`（通用目录） | `~/.copilot/copilot-instructions.md` |
| Cursor | `~/.agents/skills/`（通用目录） | 无文件，需在 Cursor 设置的 Rules 中手动添加 |
| Kimi CLI | `~/.agents/skills/`（若已有 `~/.config/agents/skills/` 则装到这里） | 待确认，需手动配置 |
| Qwen Code | `~/.qwen/skills/` | `~/.qwen/QWEN.md` |

说明：

- `~/.agents/skills/` 是多个工具共同读取的通用目录，只需一份就能被上表中标注"通用目录"的工具同时读取。
- 部分工具（如 OpenCode、Cursor、Copilot）同时读取 `~/.claude/skills/` 和 `~/.agents/skills/`。两处都装了时，它们会看到两个同名 skill，内容完全相同，不影响使用。
- 表中路径均来自各工具的官方文档。其他支持 `SKILL.md` 的工具，可以手动把 `skill/ideology-values-guard/` 复制到它的 skills 目录。

## 安装参数

```bash
bash install.sh --target claude,codex   # 只装到指定工具（可选：claude codex gemini opencode copilot cursor kimi qwen all）
bash install.sh --always-on             # 同时设置"始终生效"（见下文），不再询问
bash install.sh --dry-run               # 预演：只打印会做什么，不写任何文件
```

Windows 对应为 `-Target`、`-AlwaysOn`、`-DryRun`。

安装脚本的行为：

1. 检测本机装了哪些 AI 工具，全部安装。一个都没检测到时，安装到 `~/.claude/skills/` 和通用目录 `~/.agents/skills/`。
2. 已存在同名目录时，先备份为 `ideology-values-guard.bak` 再覆盖。备份中的 `SKILL.md` 会改名为 `SKILL.md.bak`，避免被当成第二个 skill 加载。
3. 询问是否设置"始终生效"，**默认否**。
4. 打印安装位置、是否修改了全局文件，以及卸载方法。

## 手动安装

不想运行脚本的话，直接复制目录即可：

```bash
# Claude Code
mkdir -p ~/.claude/skills && cp -R skill/ideology-values-guard ~/.claude/skills/

# Codex / Gemini CLI / OpenCode / Copilot CLI / Cursor / Kimi CLI（通用目录）
mkdir -p ~/.agents/skills && cp -R skill/ideology-values-guard ~/.agents/skills/

# Qwen Code
mkdir -p ~/.qwen/skills && cp -R skill/ideology-values-guard ~/.qwen/skills/
```

## 让它始终生效

Skill 是否触发由模型根据 SKILL.md 中的描述（description 字段）决定。本 skill 的描述已写成"每个请求都使用"，但**仅靠 skill 无法保证 100% 触发**。如果要让它始终生效，需要在对应工具的全局指令文件末尾加上：

```
<!-- ideology-values-guard:start -->
处理任何请求前，先使用 ideology-values-guard skill。
<!-- ideology-values-guard:end -->
```

安装脚本会询问是否帮你追加这段内容（默认否），也可以用 `--always-on` 直接设置。卸载脚本只删除两个标记之间的内容，不动文件的其他部分。

## 禁用与卸载

- **临时禁用**：把已安装的 `ideology-values-guard` 目录改名或移走；如果设置过"始终生效"，也要删掉那段标记内容。
- **一键卸载**：在仓库目录中运行 `bash uninstall.sh`（Windows：`.\uninstall.ps1`），可加 `--dry-run` 预览。它会检查所有工具可能使用的目录，包括通过 `npx skills` 安装的副本和链接。
- **通过 npx 安装的**，也可以用 `npx skills remove ideology-values-guard -g` 卸载。
- **手动卸载**：删除上表中各位置下的 `ideology-values-guard` 目录，再删除全局指令文件中 `ideology-values-guard:start` 到 `ideology-values-guard:end` 之间的内容。
- 安装时产生的 `ideology-values-guard.bak` 备份不会被卸载脚本删除，可以手动删除。

## 自定义判定尺度

判定细则在 [`skill/ideology-values-guard/references/values-criteria.md`](skill/ideology-values-guard/references/values-criteria.md)。它把十二项价值观逐项列出"明显违背"和"不属于违背"的情形。你可以直接编辑**已安装目录**下的这个文件，按需放宽或收紧尺度，无需重新安装。

测试用例见 [`examples/test-prompts.md`](examples/test-prompts.md)。

## 已知局限

- Skill 本质是提示词指令，无法覆盖底层模型或 AI 工具自身的安全策略，也不能保证每次都被触发。
- 价值观判断由模型完成，存在误判（误拦或漏拦）。可以通过修改细则调整尺度。
- 本 skill 只影响安装了它的本地 AI 工具，对其他设备和用户没有任何作用。

## 仓库结构

```
skill/ideology-values-guard/        # 被安装的 skill 本体
├── SKILL.md
└── references/values-criteria.md
install.sh / install.ps1           # 安装
uninstall.sh / uninstall.ps1       # 卸载
examples/test-prompts.md           # 测试用例
```

## 许可证

[MIT 许可证](LICENSE)（许可证正文按惯例保留英文原文）
