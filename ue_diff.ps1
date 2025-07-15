<#
~\.gitconfig

[diff "UE_Diff"]
    tool = UE_Diff_Tool
    binary = true
[difftool "UE_Diff_Tool"]
    cmd = powershell 'D:\\scripts\\ue_merge.ps1' "$REMOTE" "$LOCAL"

[merge "UE_Merge"]
    tool = UE_Merge_Tool
    binary = true
[mergetool "UE_Merge_Tool"]
    cmd = powershell 'D:\\scripts\\ue_merge.ps1' "$REMOTE" "$LOCAL" "$BASE" "$MERGED"
	keepBackup = true

[merge "UE_Compare_Only"]
    tool = UE_Compare_Only_Tool
    binary = true
[mergetool "UE_Compare_Only_Tool"]
    cmd = powershell 'D:\\scripts\\ue_merge.ps1' "$REMOTE" "$LOCAL"

#>

function Find-UProjectUpwards {
    param (
        [string]$Path
    )

    $CurrentPath = Split-Path -Path $Path -Parent

    while ($CurrentPath) {
        # Look for any .uproject file in the current directory
        $UProject = Get-ChildItem -Path $CurrentPath -Filter *.uproject -File -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($UProject) {
            return $UProject.FullName
        }

        # Go up one level
        $Parent = Split-Path -Path $CurrentPath -Parent
        if ($Parent -eq $CurrentPath) {
            break  # Reached the root
        }

        $CurrentPath = $Parent
    }

    return $null
}

for ($i = 0; $i -lt $args.length; $i++) {
    $args[$i] = Resolve-Path $args[$i]
}

$PROJECT_PATH = Find-UProjectUpwards -Path $args[0]
if (!$PROJECT_PATH) {
    Write-Output ".uproject not found!"
    return
}

if ($Env:UE_EDITOR_EXE_PATH) {
    $UE_EDITOR_EXE_PATH = $Env:UE_EDITOR_EXE_PATH
} else {
    $UE_EDITOR_EXE_PATH = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\EpicGames\Unreal Engine\5.2" -Name InstalledDirectory
    $UE_EDITOR_EXE_PATH = $UE_EDITOR_EXE_PATH + "\Engine\Binaries\Win64\UnrealEditor-Cmd.exe"
}

& $UE_EDITOR_EXE_PATH $PROJECT_PATH -diff $args

## The following is necessary when using `UnrealEditor.exe`
# Write-Host 'Press a key when returned from the merge editor...'
# $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
