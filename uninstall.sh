#!/usr/bin/env bash
# 意识形态（ideology-values-guard）卸载脚本 — macOS / Linux
#
# 在本仓库目录下运行：
#   bash uninstall.sh
#
# 本脚本只做以下几件事：
#   1. 删除各 AI 工具 skill 目录下的 ideology-values-guard/（包括用 npx skills 安装的副本和链接）
#   2. 删除全局指令文件中 ideology-values-guard:start / end 标记之间的内容（含标记本身，其他内容不动）
# 完全不联网。安装时产生的 .bak 备份不会被删除，会在结束时列出。
#
# 参数：
#   --dry-run   预演：只打印将要执行的操作，不写任何文件
#   --home DIR  把所有路径的根目录从 $HOME 换成 DIR（测试用）

set -euo pipefail

SKILL_NAME="ideology-values-guard"
MARK_START="<!-- ideology-values-guard:start -->"
MARK_END="<!-- ideology-values-guard:end -->"

DRY_RUN=0
HOME_DIR="${HOME}"

usage() {
  sed -n '2,15p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

info() { printf '%s\n' "$*"; }
warn() { printf '警告：%s\n' "$*" >&2; }
die()  { printf '错误：%s\n' "$*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)  DRY_RUN=1; shift ;;
    --home)     [ $# -ge 2 ] || die "--home 需要参数"; HOME_DIR="$2"; shift 2 ;;
    --home=*)   HOME_DIR="${1#*=}"; shift ;;
    -h|--help)  usage; exit 0 ;;
    *) die "未知参数：${1}（使用 --help 查看用法）" ;;
  esac
done

# 所有可能存放本 skill 的目录：install.sh 使用的目录，以及 npx skills 等工具可能使用的目录
SKILL_DIRS=(
  "$HOME_DIR/.claude/skills"
  "$HOME_DIR/.agents/skills"
  "$HOME_DIR/.config/agents/skills"
  "$HOME_DIR/.qwen/skills"
  "$HOME_DIR/.codex/skills"
  "$HOME_DIR/.gemini/skills"
  "$HOME_DIR/.config/opencode/skills"
  "$HOME_DIR/.copilot/skills"
  "$HOME_DIR/.cursor/skills"
  "$HOME_DIR/.kimi/skills"
  "$HOME_DIR/.kimi-code/skills"
)

# 所有可能被追加过标记的全局指令文件
GLOBAL_FILES=(
  "$HOME_DIR/.claude/CLAUDE.md"
  "$HOME_DIR/.codex/AGENTS.md"
  "$HOME_DIR/.gemini/GEMINI.md"
  "$HOME_DIR/.config/opencode/AGENTS.md"
  "$HOME_DIR/.copilot/copilot-instructions.md"
  "$HOME_DIR/.qwen/QWEN.md"
)

[ "$DRY_RUN" -eq 1 ] && info "[预演] 只打印操作，不写任何文件。"

REMOVED=()
CLEANED=()
BACKUPS=()

for dir in "${SKILL_DIRS[@]}"; do
  dest="$dir/$SKILL_NAME"
  if [ -e "$dest" ] || [ -L "$dest" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      info "[预演] 删除 $dest"
    else
      rm -rf "$dest"
      info "已删除 $dest"
    fi
    REMOVED+=("$dest")
  fi
  if [ -e "$dest.bak" ] || [ -L "$dest.bak" ]; then BACKUPS+=("$dest.bak"); fi
done

for f in "${GLOBAL_FILES[@]}"; do
  [ -f "$f" ] || continue
  grep -qF "$MARK_START" "$f" || continue
  if ! grep -qF "$MARK_END" "$f"; then
    warn "${f} 中只有开始标记、没有结束标记，为安全起见不做修改，请手动删除。"
    continue
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    info "[预演] 删除 $f 中 ideology-values-guard 标记之间的内容"
  else
    tmp="$(mktemp)"
    # 删除标记块；紧挨在开始标记前的一个空行是安装时加的，一并删除
    awk -v s="$MARK_START" -v e="$MARK_END" '
      skip { if ($0 == e) skip = 0; next }
      $0 == s { held = 0; skip = 1; next }
      held { print ""; held = 0 }
      $0 == "" { held = 1; next }
      { print }
      END { if (held) print "" }
    ' "$f" > "$tmp"
    # 用 cat 回写，保留原文件的权限
    cat "$tmp" > "$f"
    rm -f "$tmp"
    info "已清理 $f 中的 ideology-values-guard 标记内容。"
  fi
  CLEANED+=("$f")
done

info ""
info "========== 卸载完成 =========="
[ "$DRY_RUN" -eq 1 ] && info "（预演模式：以上操作均未实际执行）"
if [ ${#REMOVED[@]} -gt 0 ]; then
  info "已删除的 skill 目录："
  for d in "${REMOVED[@]}"; do info "  - $d"; done
else
  info "未找到已安装的 ideology-values-guard 目录。"
fi
if [ ${#CLEANED[@]} -gt 0 ]; then
  info "已清理的全局指令文件："
  for f in "${CLEANED[@]}"; do info "  - $f"; done
else
  info "全局指令文件：无需修改。"
fi
if [ ${#BACKUPS[@]} -gt 0 ]; then
  info "以下是安装时留下的备份，未删除，如不需要可手动删除："
  for b in "${BACKUPS[@]}"; do info "  - $b"; done
fi
