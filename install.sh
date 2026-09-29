#!/usr/bin/env bash
# 意识形态（ideology-values-guard）安装脚本 — macOS / Linux
#
# 在本仓库目录下运行：
#   bash install.sh
#
# 本脚本只做以下几件事：
#   1. 检测本机装了哪些 AI 工具
#   2. 把本仓库的 skill/ideology-values-guard/ 复制到这些工具读取 skill 的目录
#   3. 仅在你明确同意时，在全局指令文件末尾追加一段带标记的说明（默认不修改）
#   4. 打印安装位置与卸载方法
# 完全不联网，不收集任何信息。
#
# 参数：
#   --target LIST  只安装到指定工具，逗号分隔，可选：
#                  claude codex gemini opencode copilot cursor kimi qwen all
#                  （默认：本机检测到的全部工具）
#   --always-on    同时在全局指令文件末尾追加"始终使用本 skill"的说明（不再询问）
#   --dry-run      预演：只打印将要执行的操作，不写任何文件
#   --source DIR   skill 来源的仓库目录（默认：本脚本所在目录）
#   --home DIR     把所有安装路径的根目录从 $HOME 换成 DIR（测试用）

set -euo pipefail

SKILL_NAME="ideology-values-guard"
MARK_START="<!-- ideology-values-guard:start -->"
MARK_END="<!-- ideology-values-guard:end -->"
MARK_BODY="处理任何请求前，先使用 ideology-values-guard skill。"
ALL_TOOLS=(claude codex gemini opencode copilot cursor kimi qwen)

TARGETS=()
DRY_RUN=0
ALWAYS_ON=0
SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="${HOME}"

usage() {
  sed -n '2,21p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

info() { printf '%s\n' "$*"; }
warn() { printf '警告：%s\n' "$*" >&2; }
die()  { printf '错误：%s\n' "$*" >&2; exit 1; }

# contains VALUE ITEM...：VALUE 是否在 ITEM 列表中
contains() {
  local v="$1" x
  shift
  for x in "$@"; do [ "$x" = "$v" ] && return 0; done
  return 1
}

add_targets() {
  local item
  IFS=', ' read -r -a _items <<< "$1"
  for item in "${_items[@]}"; do
    [ -n "$item" ] || continue
    case "$item" in
      claude|codex|gemini|opencode|copilot|cursor|kimi|qwen) TARGETS+=("$item") ;;
      all) TARGETS+=("${ALL_TOOLS[@]}") ;;
      *) die "未知的 --target：${item}（可选 ${ALL_TOOLS[*]} all）" ;;
    esac
  done
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)    [ $# -ge 2 ] || die "--target 需要参数"; add_targets "$2"; shift 2 ;;
    --target=*)  add_targets "${1#*=}"; shift ;;
    --always-on) ALWAYS_ON=1; shift ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --source)    [ $# -ge 2 ] || die "--source 需要参数"; SOURCE="$2"; shift 2 ;;
    --source=*)  SOURCE="${1#*=}"; shift ;;
    --home)      [ $# -ge 2 ] || die "--home 需要参数"; HOME_DIR="$2"; shift 2 ;;
    --home=*)    HOME_DIR="${1#*=}"; shift ;;
    -h|--help)   usage; exit 0 ;;
    *) die "未知参数：${1}（使用 --help 查看用法）" ;;
  esac
done

SRC_SKILL="$SOURCE/skill/$SKILL_NAME"
[ -f "$SRC_SKILL/SKILL.md" ] || die "找不到 ${SRC_SKILL}/SKILL.md。请在完整的仓库目录中运行本脚本，或用 --source 指定仓库目录。"

# 标准输入是终端时才进行交互
INTERACTIVE=0
if [ -t 0 ]; then INTERACTIVE=1; fi

# ---------- 各 AI 工具的信息 ----------

label() {
  case "$1" in
    claude)   printf 'Claude Code' ;;
    codex)    printf 'Codex' ;;
    gemini)   printf 'Gemini CLI' ;;
    opencode) printf 'OpenCode' ;;
    copilot)  printf 'GitHub Copilot CLI' ;;
    cursor)   printf 'Cursor' ;;
    kimi)     printf 'Kimi CLI' ;;
    qwen)     printf 'Qwen Code' ;;
  esac
}

labels() {
  local t out=""
  for t in "$@"; do out="${out}$(label "$t")、"; done
  printf '%s' "${out%、}"
}

detect() {
  case "$1" in
    claude)   [ -d "$HOME_DIR/.claude" ]          || command -v claude       >/dev/null 2>&1 ;;
    codex)    [ -d "$HOME_DIR/.codex" ]           || command -v codex        >/dev/null 2>&1 ;;
    gemini)   [ -d "$HOME_DIR/.gemini" ]          || command -v gemini       >/dev/null 2>&1 ;;
    opencode) [ -d "$HOME_DIR/.config/opencode" ] || command -v opencode     >/dev/null 2>&1 ;;
    copilot)  [ -d "$HOME_DIR/.copilot" ]         || command -v copilot      >/dev/null 2>&1 ;;
    cursor)   [ -d "$HOME_DIR/.cursor" ]          || command -v cursor-agent >/dev/null 2>&1 ;;
    kimi)     [ -d "$HOME_DIR/.kimi" ]            || command -v kimi         >/dev/null 2>&1 ;;
    qwen)     [ -d "$HOME_DIR/.qwen" ]            || command -v qwen         >/dev/null 2>&1 ;;
  esac
}

# 每个工具读取 skill 的用户级目录（均来自各工具官方文档）。
# ~/.agents/skills 是通用目录，Codex、Gemini CLI、OpenCode、Copilot CLI、Cursor、Kimi CLI 都会读取，
# 这些工具共用一份，避免同一个 skill 被复制多份。
skills_dir() {
  case "$1" in
    claude) printf '%s\n' "$HOME_DIR/.claude/skills" ;;
    qwen)   printf '%s\n' "$HOME_DIR/.qwen/skills" ;;
    kimi)
      # Kimi CLI 的通用目录中 ~/.config/agents/skills 优先于 ~/.agents/skills（两者只读其一）。
      # 前者已存在时装到前者；否则装到 ~/.agents/skills，不新建前者，以免遮住 ~/.agents/skills 中的其他 skill。
      if [ -d "$HOME_DIR/.config/agents/skills" ]; then
        printf '%s\n' "$HOME_DIR/.config/agents/skills"
      else
        printf '%s\n' "$HOME_DIR/.agents/skills"
      fi
      ;;
    *) printf '%s\n' "$HOME_DIR/.agents/skills" ;;
  esac
}

# 每个工具的全局指令文件（用于可选的"始终生效"）。空字符串表示无法用文件配置。
global_file() {
  case "$1" in
    claude) printf '%s\n' "$HOME_DIR/.claude/CLAUDE.md" ;;
    codex)  printf '%s\n' "$HOME_DIR/.codex/AGENTS.md" ;;
    gemini) printf '%s\n' "$HOME_DIR/.gemini/GEMINI.md" ;;
    opencode)
      # OpenCode 没有 ~/.config/opencode/AGENTS.md 时会改读 ~/.claude/CLAUDE.md；不新建前者，以免遮住后者。
      if [ -f "$HOME_DIR/.config/opencode/AGENTS.md" ]; then
        printf '%s\n' "$HOME_DIR/.config/opencode/AGENTS.md"
      else
        printf '%s\n' "$HOME_DIR/.claude/CLAUDE.md"
      fi
      ;;
    copilot) printf '%s\n' "$HOME_DIR/.copilot/copilot-instructions.md" ;;
    qwen)    printf '%s\n' "$HOME_DIR/.qwen/QWEN.md" ;;
    cursor)  printf '' ;;  # Cursor 的全局规则在设置界面（Rules）中配置，不是文件
    kimi)    printf '' ;;  # 待确认：未查到 Kimi CLI 的全局指令文件位置
  esac
}

# ---------- 确定安装目标 ----------

if [ ${#TARGETS[@]} -eq 0 ]; then
  for t in "${ALL_TOOLS[@]}"; do
    if detect "$t"; then TARGETS+=("$t"); fi
  done
  if [ ${#TARGETS[@]} -eq 0 ]; then
    info "未检测到已知的 AI 工具，将安装到 ~/.claude/skills 和通用目录 ~/.agents/skills。"
    TARGETS=(claude codex)
  fi
fi

TOOLS=()
for t in "${TARGETS[@]}"; do
  contains "$t" "${TOOLS[@]:-}" || TOOLS+=("$t")
done

DIRS=()
for t in "${TOOLS[@]}"; do
  d="$(skills_dir "$t")"
  contains "$d" "${DIRS[@]:-}" || DIRS+=("$d")
done

info "将为以下工具安装：$(labels "${TOOLS[@]}")"
[ "$DRY_RUN" -eq 1 ] && info "[预演] 只打印操作，不写任何文件。"

# ---------- 复制 skill ----------

for dir in "${DIRS[@]}"; do
  dest="$dir/$SKILL_NAME"
  bak="$dest.bak"
  if [ -L "$dest" ]; then
    # 已有的是链接（例如 npx skills 创建的），内容在别处，只删除链接本身，不做备份
    info "已存在链接 ${dest}，将替换为独立副本。"
    if [ "$DRY_RUN" -eq 1 ]; then info "[预演] 删除链接 $dest"; else rm -f "$dest"; fi
  elif [ -e "$dest" ]; then
    warn "已存在 ${dest}，将备份为 ${bak} 后覆盖。"
    if [ "$DRY_RUN" -eq 1 ]; then
      info "[预演] 备份 $dest -> $bak"
    else
      if [ -e "$bak" ] || [ -L "$bak" ]; then
        warn "旧备份 ${bak} 已存在，将被新备份替换。"
        rm -rf "$bak"
      fi
      mv "$dest" "$bak"
      # 备份中的 SKILL.md 改名，避免 AI 工具把备份当成第二个同名 skill 加载
      if [ -f "$bak/SKILL.md" ]; then mv "$bak/SKILL.md" "$bak/SKILL.md.bak"; fi
    fi
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[预演] 复制 $SRC_SKILL -> $dest"
  else
    mkdir -p "$dir"
    cp -R "$SRC_SKILL" "$dest"
    info "已安装到 $dest"
  fi
done

# ---------- 可选："始终生效" ----------

GFILES=()
NO_FILE_TOOLS=()
for t in "${TOOLS[@]}"; do
  f="$(global_file "$t")"
  if [ -z "$f" ]; then
    NO_FILE_TOOLS+=("$t")
  elif [ -f "$f" ] && grep -qF "$MARK_START" "$f"; then
    info "$f 中已有 ideology-values-guard 标记，不重复添加。"
  else
    contains "$f" "${GFILES[@]:-}" || GFILES+=("$f")
  fi
done

MODIFIED=()
if [ ${#GFILES[@]} -gt 0 ]; then
  do_global=0
  if [ "$ALWAYS_ON" -eq 1 ]; then
    do_global=1
  elif [ "$INTERACTIVE" -eq 1 ]; then
    info ""
    info "仅靠 skill 无法保证每次都触发。可以在以下全局指令文件末尾追加一段带标记的说明，让它始终生效："
    for f in "${GFILES[@]}"; do info "  - $f"; done
    printf '是否追加？[y/N]：'
    read -r answer || answer=""
    case "$answer" in y|Y|yes|YES) do_global=1 ;; esac
  fi

  if [ "$do_global" -eq 1 ]; then
    for f in "${GFILES[@]}"; do
      if [ "$DRY_RUN" -eq 1 ]; then
        info "[预演] 在 $f 末尾追加带标记的说明"
      else
        mkdir -p "$(dirname "$f")"
        sep=""
        if [ -s "$f" ]; then sep=$'\n'; fi
        printf '%s%s\n%s\n%s\n' "$sep" "$MARK_START" "$MARK_BODY" "$MARK_END" >> "$f"
        info "已在 $f 末尾追加说明。"
      fi
      MODIFIED+=("$f")
    done
  else
    info ""
    info "未修改全局指令文件。如需让本 skill 始终生效，可运行 bash install.sh --always-on，"
    info "或手动在以下文件末尾追加下面三行："
    for f in "${GFILES[@]}"; do info "  - $f"; done
    info ""
    info "  $MARK_START"
    info "  $MARK_BODY"
    info "  $MARK_END"
  fi
fi
if [ ${#NO_FILE_TOOLS[@]} -gt 0 ]; then
  info "提示：$(labels "${NO_FILE_TOOLS[@]}") 没有可自动修改的全局指令文件；如需始终生效，请在其设置中手动添加这句说明：${MARK_BODY}"
fi

# ---------- 总结 ----------

info ""
info "========== 安装完成 =========="
[ "$DRY_RUN" -eq 1 ] && info "（预演模式：以上操作均未实际执行）"
info "已安装的工具：$(labels "${TOOLS[@]}")"
info "安装位置："
for dir in "${DIRS[@]}"; do info "  - $dir/$SKILL_NAME"; done
if [ ${#MODIFIED[@]} -gt 0 ]; then
  info "已修改的全局指令文件："
  for f in "${MODIFIED[@]}"; do info "  - $f"; done
else
  info "全局指令文件：未修改。"
fi
info ""
info "卸载：在本仓库目录下运行 bash uninstall.sh"
