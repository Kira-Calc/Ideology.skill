# 意识形态（ideology-values-guard）安装脚本 — Windows PowerShell
#
# 在本仓库目录下运行：
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
#
# 本脚本只做以下几件事：
#   1. 检测本机装了哪些 AI 工具
#   2. 把本仓库的 skill\ideology-values-guard\ 复制到这些工具读取 skill 的目录
#   3. 仅在你明确同意时，在全局指令文件末尾追加一段带标记的说明（默认不修改）
#   4. 打印安装位置与卸载方法
# 完全不联网，不收集任何信息。
#
# 参数：
#   -Target LIST  只安装到指定工具，可选：claude codex gemini opencode copilot cursor kimi qwen all
#                 （默认：本机检测到的全部工具）
#   -AlwaysOn     同时在全局指令文件末尾追加"始终使用本 skill"的说明（不再询问）
#   -DryRun       预演：只打印将要执行的操作，不写任何文件
#   -Source DIR   skill 来源的仓库目录（默认：本脚本所在目录）
#   -HomeDir DIR  把所有安装路径的根目录换成 DIR（测试用）

[CmdletBinding()]
param(
    [string[]]$Target = @(),
    [switch]$AlwaysOn,
    [switch]$DryRun,
    [string]$Source = $PSScriptRoot,
    [string]$HomeDir = $HOME
)

$ErrorActionPreference = "Stop"

$SkillName = "ideology-values-guard"
$MarkStart = "<!-- ideology-values-guard:start -->"
$MarkEnd   = "<!-- ideology-values-guard:end -->"
$MarkBody  = "处理任何请求前，先使用 ideology-values-guard skill。"
$AllTools  = @("claude", "codex", "gemini", "opencode", "copilot", "cursor", "kimi", "qwen")

function P([string]$rel) { Join-Path $HomeDir $rel }

$Labels = @{
    claude = "Claude Code"; codex = "Codex"; gemini = "Gemini CLI"; opencode = "OpenCode"
    copilot = "GitHub Copilot CLI"; cursor = "Cursor"; kimi = "Kimi CLI"; qwen = "Qwen Code"
}

function Test-Tool([string]$t) {
    $dirs = @{
        claude = ".claude"; codex = ".codex"; gemini = ".gemini"; opencode = ".config\opencode"
        copilot = ".copilot"; cursor = ".cursor"; kimi = ".kimi"; qwen = ".qwen"
    }
    $cmds = @{
        claude = "claude"; codex = "codex"; gemini = "gemini"; opencode = "opencode"
        copilot = "copilot"; cursor = "cursor-agent"; kimi = "kimi"; qwen = "qwen"
    }
    (Test-Path (P $dirs[$t])) -or [bool](Get-Command $cmds[$t] -ErrorAction SilentlyContinue)
}

# 每个工具读取 skill 的用户级目录（均来自各工具官方文档）。
# ~/.agents/skills 是通用目录，Codex、Gemini CLI、OpenCode、Copilot CLI、Cursor、Kimi CLI 都会读取，共用一份。
function Get-SkillsDir([string]$t) {
    switch ($t) {
        "claude" { P ".claude\skills" }
        "qwen"   { P ".qwen\skills" }
        "kimi"   {
            # Kimi CLI 中 ~/.config/agents/skills 优先于 ~/.agents/skills；前者不存在时不新建，以免遮住后者
            if (Test-Path (P ".config\agents\skills")) { P ".config\agents\skills" } else { P ".agents\skills" }
        }
        default  { P ".agents\skills" }
    }
}

# 每个工具的全局指令文件（用于可选的"始终生效"）。空字符串表示无法用文件配置。
function Get-GlobalFile([string]$t) {
    switch ($t) {
        "claude"   { P ".claude\CLAUDE.md" }
        "codex"    { P ".codex\AGENTS.md" }
        "gemini"   { P ".gemini\GEMINI.md" }
        "opencode" {
            # OpenCode 没有自己的 AGENTS.md 时会改读 ~/.claude/CLAUDE.md；不新建前者，以免遮住后者
            if (Test-Path (P ".config\opencode\AGENTS.md")) { P ".config\opencode\AGENTS.md" } else { P ".claude\CLAUDE.md" }
        }
        "copilot"  { P ".copilot\copilot-instructions.md" }
        "qwen"     { P ".qwen\QWEN.md" }
        "cursor"   { "" }  # Cursor 的全局规则在设置界面（Rules）中配置，不是文件
        "kimi"     { "" }  # 待确认：未查到 Kimi CLI 的全局指令文件位置
    }
}

function Join-Labels($tools) { ($tools | ForEach-Object { $Labels[$_] }) -join "、" }

$SrcSkill = Join-Path $Source "skill\$SkillName"
if (-not (Test-Path (Join-Path $SrcSkill "SKILL.md"))) {
    throw "找不到 $SrcSkill\SKILL.md。请在完整的仓库目录中运行本脚本，或用 -Source 指定仓库目录。"
}

$Interactive = [Environment]::UserInteractive -and -not [Console]::IsInputRedirected

# ---------- 确定安装目标 ----------

$Tools = @()
foreach ($raw in $Target) {
    foreach ($item in ($raw -split "[,\s]+" | Where-Object { $_ })) {
        $item = $item.ToLower()
        if ($item -eq "all") { $Tools += $AllTools }
        elseif ($AllTools -contains $item) { $Tools += $item }
        else { throw "未知的 Target：$item（可选 $($AllTools -join ' ') all）" }
    }
}
if ($Tools.Count -eq 0) {
    $Tools = @($AllTools | Where-Object { Test-Tool $_ })
    if ($Tools.Count -eq 0) {
        Write-Host "未检测到已知的 AI 工具，将安装到 ~/.claude/skills 和通用目录 ~/.agents/skills。"
        $Tools = @("claude", "codex")
    }
}
$Tools = @($Tools | Select-Object -Unique)
$Dirs  = @($Tools | ForEach-Object { Get-SkillsDir $_ } | Select-Object -Unique)

Write-Host "将为以下工具安装：$(Join-Labels $Tools)"
if ($DryRun) { Write-Host "[预演] 只打印操作，不写任何文件。" }

# ---------- 复制 skill ----------

foreach ($dir in $Dirs) {
    $dest = Join-Path $dir $SkillName
    $bak  = "$dest.bak"
    $existing = Get-Item -Force $dest -ErrorAction SilentlyContinue
    if ($existing -and ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        # 已有的是链接（例如 npx skills 创建的），内容在别处，只删除链接本身，不做备份
        Write-Host "已存在链接 $dest，将替换为独立副本。"
        if ($DryRun) { Write-Host "[预演] 删除链接 $dest" } else { $existing.Delete() }
    } elseif ($existing) {
        Write-Host "警告：已存在 $dest，将备份为 $bak 后覆盖。" -ForegroundColor Yellow
        if ($DryRun) {
            Write-Host "[预演] 备份 $dest -> $bak"
        } else {
            if (Test-Path $bak) {
                Write-Host "警告：旧备份 $bak 已存在，将被新备份替换。" -ForegroundColor Yellow
                $old = Get-Item -Force $bak
                if ($old.Attributes -band [IO.FileAttributes]::ReparsePoint) { $old.Delete() }
                else { Remove-Item -Recurse -Force $bak }
            }
            Move-Item $dest $bak
            # 备份中的 SKILL.md 改名，避免 AI 工具把备份当成第二个同名 skill 加载
            $bakSkill = Join-Path $bak "SKILL.md"
            if (Test-Path $bakSkill) { Rename-Item $bakSkill "SKILL.md.bak" }
        }
    }
    if ($DryRun) {
        Write-Host "[预演] 复制 $SrcSkill -> $dest"
    } else {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Copy-Item -Recurse $SrcSkill $dest
        Write-Host "已安装到 $dest"
    }
}

# ---------- 可选："始终生效" ----------

$GFiles = @()
$NoFileTools = @()
foreach ($t in $Tools) {
    $f = Get-GlobalFile $t
    if (-not $f) { $NoFileTools += $t; continue }
    if ((Test-Path $f) -and (Select-String -Path $f -SimpleMatch -Quiet $MarkStart)) {
        Write-Host "$f 中已有 ideology-values-guard 标记，不重复添加。"
        continue
    }
    if ($GFiles -notcontains $f) { $GFiles += $f }
}

$Modified = @()
if ($GFiles.Count -gt 0) {
    $doGlobal = $false
    if ($AlwaysOn) {
        $doGlobal = $true
    } elseif ($Interactive) {
        Write-Host ""
        Write-Host "仅靠 skill 无法保证每次都触发。可以在以下全局指令文件末尾追加一段带标记的说明，让它始终生效："
        $GFiles | ForEach-Object { Write-Host "  - $_" }
        $answer = Read-Host "是否追加？[y/N]"
        $doGlobal = $answer -match '^(y|yes)$'
    }

    if ($doGlobal) {
        foreach ($f in $GFiles) {
            if ($DryRun) {
                Write-Host "[预演] 在 $f 末尾追加带标记的说明"
            } else {
                New-Item -ItemType Directory -Force -Path (Split-Path $f) | Out-Null
                $prefix = if ((Test-Path $f) -and (Get-Item $f).Length -gt 0) { "`n" } else { "" }
                $block = "$prefix$MarkStart`n$MarkBody`n$MarkEnd`n"
                [IO.File]::AppendAllText($f, $block, (New-Object Text.UTF8Encoding $false))
                Write-Host "已在 $f 末尾追加说明。"
            }
            $Modified += $f
        }
    } else {
        Write-Host ""
        Write-Host "未修改全局指令文件。如需让本 skill 始终生效，可运行 .\install.ps1 -AlwaysOn，"
        Write-Host "或手动在以下文件末尾追加下面三行："
        $GFiles | ForEach-Object { Write-Host "  - $_" }
        Write-Host ""
        Write-Host "  $MarkStart"
        Write-Host "  $MarkBody"
        Write-Host "  $MarkEnd"
    }
}
if ($NoFileTools.Count -gt 0) {
    Write-Host "提示：$(Join-Labels $NoFileTools) 没有可自动修改的全局指令文件；如需始终生效，请在其设置中手动添加这句说明：$MarkBody"
}

# ---------- 总结 ----------

Write-Host ""
Write-Host "========== 安装完成 =========="
if ($DryRun) { Write-Host "（预演模式：以上操作均未实际执行）" }
Write-Host "已安装的工具：$(Join-Labels $Tools)"
Write-Host "安装位置："
$Dirs | ForEach-Object { Write-Host "  - $(Join-Path $_ $SkillName)" }
if ($Modified.Count -gt 0) {
    Write-Host "已修改的全局指令文件："
    $Modified | ForEach-Object { Write-Host "  - $_" }
} else {
    Write-Host "全局指令文件：未修改。"
}
Write-Host ""
Write-Host "卸载：在本仓库目录下运行 powershell -ExecutionPolicy Bypass -File .\uninstall.ps1"
