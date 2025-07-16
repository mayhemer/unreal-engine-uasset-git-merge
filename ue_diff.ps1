<#
------------
~\.gitconfig

[diff "UE_Diff"]
    tool = UE_Diff_Tool
    binary = true
[difftool "UE_Diff_Tool"]
    cmd = powershell 'D:\\scripts\\ue_diff.ps1' "$REMOTE" "$LOCAL"

[merge "UE_Merge"]
    tool = UE_Merge_Tool
    binary = true
[mergetool "UE_Merge_Tool"]
    cmd = powershell 'D:\\scripts\\ue_diff.ps1' "$REMOTE" "$LOCAL" "$BASE" "$MERGED"
	keepBackup = true

[merge "UE_Compare_Remote_Base"]
    tool = UE_Compare_Remote_Base_Tool
    binary = true
[mergetool "UE_Compare_Remote_Base_Tool"]
    cmd = powershell 'D:\\scripts\\ue_diff.ps1' "$BASE" "$REMOTE"

[merge "UE_Compare_Local_Base"]
    tool = UE_Compare_Local_Base_Tool
    binary = true
[mergetool "UE_Compare_Local_Base_Tool"]
    cmd = powershell 'D:\\scripts\\ue_diff.ps1' "$BASE" "$LOCAL"

----
git-bash

# start local rebase
git checkout Dev_MyFeatureBranch # being based on an older commit on Development, a.k.a Base
git rebase Development

# now build the project for the project's default config (usually Development/Editor/Win64)
# the configuration to diff against can be overriden with env var `UE_DIFF_ARGS` like:
# UE_DIFF_ARGS=-platform=Win64 -target=Editor -configuration=Development

# ! note that now, during merging the rebase, REMOTE and LOCAL are backwards !
# LOCAL is Dev_MyFeatureBranch, and REMOTE is Development 

# to view a diff of changes between the current up-to-date Development and Base
# a.k.a, what others pushed to the Development branch in the meantime
yes no | git mergetool -t UE_Compare_Local_Base_Tool Path/Conflicting_File.uasset

# to accept the changes on Development and effectively throwing away my own changes
git checkout --ours Path/Conflicting_File.uasset
git add Path/Conflicting_File.uasset

# to view a diff of changes between Dev_MyFeatureBranch and Base
# a.k.a, what the authror of the branch being rebased made - my changes
yes no | git mergetool -t UE_Compare_Remote_Base_Tool Path/Conflicting_File.uasset

# to override changes on Development with my own changes
git checkout --theirs Path/Conflicting_File.uasset
git add Path/Conflicting_File.uasset

# to restart the file's merging again (to get to the state before checkout --theirs/--ours)
git checkout --merge
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

& $UE_EDITOR_EXE_PATH $PROJECT_PATH $Env:UE_DIFF_ARGS -diff $args
