param (
    [Parameter(Mandatory=$true, HelpMessage="Provide full path to Git\bin\bash.exe")]
    [string]$GitBashExePath
)

function Join-WithCurrentDir {
    param (
        [string]$SubPath
    )
    return Join-Path -Path (Get-Location) -ChildPath $SubPath
}

# Step 1: Validate Git Bash path
if (-not (Test-Path $GitBashExePath)) {
    Write-Error "Provided Git Bash path does not exist: $GitBashExePath"
    exit 1
}

# Step 2: Create gitconfig snippet from template
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

$DiffToolForConfigLocation = (Join-WithCurrentDir -SubPath "private\ue_diff_tool.ps1") -replace '\\', '\\'
$gitConfigText = $template -replace '{{DIFF_TOOL_PATH}}', $DiffToolForConfigLocation

# Step 3: Append to ~/.gitconfig
$gitConfigFile = "$HOME\.gitconfig"
if (-not (Test-Path $gitConfigFile)) {
    New-Item -Path $gitConfigFile -ItemType File -Force | Out-Null
} else {
    $gitConfigFileBackup = $gitConfigFile + '.ue_diff_backup';
    Copy-Item -Path $gitConfigFile $gitConfigFileBackup -Confirm
}

Add-Content -Path $gitConfigFile -Value "`n$gitConfigText"

Write-Host "+ Appended configuration to $gitConfigFile"

# Step 4: Locate writable directory in Git Bash PATH
$bashPathOutput = & "$GitBashExePath" -lc 'echo $PATH'
$bashPaths = $bashPathOutput -split ':' | Where-Object { $_ -match '^/' }

$targetDir = $null
foreach ($path in $bashPaths) {
    $winPath = & "$GitBashExePath" -lc "cygpath -w '$path'"
    if ((Test-Path $winPath) -and ((Get-Item $winPath).Attributes -notmatch 'ReadOnly')) {
        try {
            $testFile = Join-Path $winPath "._test_$(Get-Random)"
            New-Item -Path $testFile -ItemType File -Force | Out-Null
            Remove-Item $testFile -Force
            $targetDir = $winPath
            break
        } catch {}
    }
}

if (-not $targetDir) {
    Write-Error "No writable Git Bash PATH directory found."
    exit 1
}

# Step 5: Copy and chmod +x the bash scripts

$publicDir = Join-WithCurrentDir -SubPath "public"
$BashScriptPaths = Get-ChildItem -Path $publicDir -File | ForEach-Object { $_.FullName }

foreach ($script in $BashScriptPaths) {
    $dest = Join-Path $targetDir (Split-Path $script -Leaf)
    Copy-Item $script -Destination $dest -Force

    $bashDest = & "$GitBashExePath" -lc "cygpath '$dest'"
    & "$GitBashExePath" -lc "chmod +x '$bashDest'"
    Write-Host "+ Installed script to `$PATH: $dest"
}
