function Join-WithCurrentDir {
    param (
        [string]$SubPath
    )
    return Join-Path -Path (Get-Location) -ChildPath $SubPath
}

# Create gitconfig snippet from template
$template = @'

# Unreal Engine Diff BEGIN
[diff "UE_Diff"]
    tool = UE_Diff_Tool
    binary = true
[difftool "UE_Diff_Tool"]
    cmd = powershell '{{DIFF_TOOL_PATH}}' "$REMOTE" "$LOCAL"

[merge "UE_Merge"]
    tool = UE_Merge_Tool
    binary = true
[mergetool "UE_Merge_Tool"]
    cmd = powershell '{{DIFF_TOOL_PATH}}' "$REMOTE" "$LOCAL" "$BASE" "$MERGED"
	keepBackup = true

[merge "UE_Compare_Remote_Base"]
    tool = UE_Compare_Remote_Base_Tool
    binary = true
[mergetool "UE_Compare_Remote_Base_Tool"]
    cmd = powershell '{{DIFF_TOOL_PATH}}' "$BASE" "$REMOTE"

[merge "UE_Compare_Local_Base"]
    tool = UE_Compare_Local_Base_Tool
    binary = true
[mergetool "UE_Compare_Local_Base_Tool"]
    cmd = powershell '{{DIFF_TOOL_PATH}}' "$BASE" "$LOCAL"
# Unreal Engine Diff END
'@

$diffToolLocationForConfig = (Join-WithCurrentDir -SubPath "private\ue_diff_tool.ps1") -replace '\\', '\\'
$gitConfigText = $template -replace '{{DIFF_TOOL_PATH}}', $diffToolLocationForConfig

# Append to ~/.gitconfig
$gitConfigFile = "$HOME\.gitconfig"
if (-not (Test-Path $gitConfigFile)) {
    New-Item -Path $gitConfigFile -ItemType File -Force | Out-Null
} else {
    $gitConfigFileBackup = $gitConfigFile + '.ue_diff_backup';
    Copy-Item -Path $gitConfigFile $gitConfigFileBackup
    Write-Host "+ $gitConfigFile backed up to $gitConfigFileBackup"
}

Add-Content -Path $gitConfigFile -Value "`n$gitConfigText"

Write-Host "+ Appended configuration to $gitConfigFile"

# Modify PATH to include the public scripts
Write-Host "...modifying PATH"

$publicScriptsDir = Join-WithCurrentDir -SubPath 'public'
$PATH = [Environment]::GetEnvironmentVariable('PATH')
$PATH += ";$publicScriptsDir"
[Environment]::SetEnvironmentVariable('PATH', $PATH, 'user')

Write-Host "+ Added $publicScriptsDir to PATH, restart git-bash to use 'git_ue_diff*' scripts easily"
