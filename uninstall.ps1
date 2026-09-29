# 意识形态（ideology-values-guard）卸载脚本 — Windows PowerShell
#
# 在本仓库目录下运行：
#   powershell -ExecutionPolicy Bypass -File .\uninstall.ps1
#
# 本脚本只做以下几件事：
#   1. 删除各 AI 工具 skill 目录下的 ideology-values-guard\（包括用 npx skills 安装的副本和链接）
#   2. 删除全局指令文件中 ideology-values-guard:start / end 标记之间的内容（含标记本身，其他内容不动）
# 完全不联网。安装时产生的 .bak 备份不会被删除，会在结束时列出。
#
# 参数：
#   -DryRun       预演：只打印将要执行的操作，不写任何文件
#   -HomeDir DIR  把所有路径的根目录换成 DIR（测试用）

[CmdletBinding()]
param(
    [switch]$DryRun,
    [string]$HomeDir = $HOME
)

$ErrorActionPreference = "Stop"

$SkillName = "ideology-values-guard"
$MarkStart = "<!-- ideology-values-guard:start -->"
$MarkEnd   = "<!-- ideology-values-guard:end -->"

function P([string]$rel) { Join-Path $HomeDir $rel }

# 所有可能存放本 skill 的目录：install.ps1 使用的目录，以及 npx skills 等工具可能使用的目录
$SkillDirs = @(
    ".claude\skills", ".agents\skills", ".config\agents\skills", ".qwen\skills", ".codex\skills",
    ".gemini\skills", ".config\opencode\skills", ".copilot\skills", ".cursor\skills",
    ".kimi\skills", ".kimi-code\skills"
) | ForEach-Object { P $_ }

# 所有可能被追加过标记的全局指令文件
$GlobalFiles = @(
    ".claude\CLAUDE.md", ".codex\AGENTS.md", ".gemini\GEMINI.md", ".config\opencode\AGENTS.md",
    ".copilot\copilot-instructions.md", ".qwen\QWEN.md"
) | ForEach-Object { P $_ }

if ($DryRun) { Write-Host "[预演] 只打印操作，不写任何文件。" }

$Removed = @()
$Cleaned = @()
$Backups = @()

foreach ($dir in $SkillDirs) {
    $dest = Join-Path $dir $SkillName
    if (Test-Path $dest) {
        if ($DryRun) { Write-Host "[预演] 删除 $dest" }
        else {
            $item = Get-Item -Force $dest
            # 链接（npx skills 创建的符号链接或 junction）只删除链接本身，不递归进入目标
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { $item.Delete() }
            else { Remove-Item -Recurse -Force $dest }
            Write-Host "已删除 $dest"
        }
        $Removed += $dest
    }
    if (Test-Path "$dest.bak") { $Backups += "$dest.bak" }
}

foreach ($f in $GlobalFiles) {
    if (-not (Test-Path $f)) { continue }
    $lines = [IO.File]::ReadAllLines($f)
    if ($lines -notcontains $MarkStart) { continue }
    if ($lines -notcontains $MarkEnd) {
        Write-Host "警告：$f 中只有开始标记、没有结束标记，为安全起见不做修改，请手动删除。" -ForegroundColor Yellow
        continue
    }
    if ($DryRun) {
        Write-Host "[预演] 删除 $f 中 ideology-values-guard 标记之间的内容"
    } else {
        $out = New-Object System.Collections.Generic.List[string]
        $skip = $false
        foreach ($line in $lines) {
            if ($skip) { if ($line -eq $MarkEnd) { $skip = $false }; continue }
            if ($line -eq $MarkStart) {
                # 紧挨在开始标记前的一个空行是安装时加的，一并删除
                if ($out.Count -gt 0 -and $out[$out.Count - 1] -eq "") { $out.RemoveAt($out.Count - 1) }
                $skip = $true
                continue
            }
            $out.Add($line)
        }
        $text = if ($out.Count) { ($out -join "`n") + "`n" } else { "" }
        [IO.File]::WriteAllText($f, $text, (New-Object Text.UTF8Encoding $false))
        Write-Host "已清理 $f 中的 ideology-values-guard 标记内容。"
    }
    $Cleaned += $f
}

Write-Host ""
Write-Host "========== 卸载完成 =========="
if ($DryRun) { Write-Host "（预演模式：以上操作均未实际执行）" }
if ($Removed.Count) {
    Write-Host "已删除的 skill 目录："
    $Removed | ForEach-Object { Write-Host "  - $_" }
} else {
    Write-Host "未找到已安装的 ideology-values-guard 目录。"
}
if ($Cleaned.Count) {
    Write-Host "已清理的全局指令文件："
    $Cleaned | ForEach-Object { Write-Host "  - $_" }
} else {
    Write-Host "全局指令文件：无需修改。"
}
if ($Backups.Count) {
    Write-Host "以下是安装时留下的备份，未删除，如不需要可手动删除："
    $Backups | ForEach-Object { Write-Host "  - $_" }
}
