<#

* ~\.gitconfig
==============

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


* git-bash
==========

# REBASING A BRANCH
-------------------

# start local rebase
git checkout Dev_MyFeatureBranch # being based on an older commit on Development, a.k.a Base
git rebase Development

# anytime you can check the state of rebase like this
git status

# now build the project for the project's default config (usually Development/Editor/Win64)
# the configuration to diff against can be overriden with env var `UE_DIFF_ARGS` like:
# UE_DIFF_ARGS=-platform=Win64 -target=Editor -configuration=Development

# when there are conflicts in .uasset files, you want to examine the changes on Development 
# against changes on the Dev_My... branch and then accept one or the other (or merge manually)

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

# to restart the file's merging again (to get to the state before `git checkout --theirs/--ours; git add`)
git checkout --merge

# to finish the rebase
git rebase --continue
# this pushes changes to the remote branch on Azure
git push origin --force

# to abort the rebase and get to the state before `git rebase Development`
git rebase --abort


# DIFFING TWO CHANGESETS
------------------------

# being e.g. in `VVRBuilderPlayground/Plugins/VVRBuilderSystem`, you can diff whole dir or a single file
TMPDIR=$(realpath ./Content) git difftool -y -t UE_Diff_Tool topcommitid..parentcommitid -- Content/Dir/[File.uasset]

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

function Invoke-Diff {
    param (
        [string]$UE_exe,
        [string]$Project,
        [string]$Left,
        [string]$Right
    )

    Write-Host "  diff: " -NoNewline
    Write-Host $Left "<->" $Right
    
    & $UE_exe $Project $Env:UE_DIFF_ARGS -diff $Left $Right
}

function Invoke-Merge {
    param (
        [string]$UE_exe,
        [string]$Project,
        [string]$Remote,
        [string]$Local,
        [string]$Base,
        [string]$Merge
    )

    Write-Host "  merge: " -NoNewline
    Write-Host $Base

    & $UE_exe $Project $Env:UE_DIFF_ARGS -diff $Remote $Local $Base $Merge
}

# Main

if ($args[0] -eq "nul") {
    return
}

for ($i = 0; $i -lt $args.length; $i++) {
    try {
        $args[$i] = Resolve-Path $args[$i]

        if (!$PROJECT_PATH) {
            $PROJECT_PATH = $args[$i]
        }
    }
    catch {
        Write-Error "Failed to resolve arg: " $args[$i]
        return
    }
}

if (!$PROJECT_PATH) {
    Write-Error "missing readable arguments"
    return
}

$PROJECT_PATH = Find-UProjectUpwards -Path $PROJECT_PATH
if (!$PROJECT_PATH) {
    Write-Host ".uproject not found! Source:" -NoNewline
    Write-Host $args[0]
    return
}

if ($Env:UE_EDITOR_EXE_PATH) {
    $UE_EDITOR_EXE_PATH = $Env:UE_EDITOR_EXE_PATH
} else {
    $UE_EDITOR_EXE_PATH = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\EpicGames\Unreal Engine\5.2" -Name InstalledDirectory
    $UE_EDITOR_EXE_PATH = $UE_EDITOR_EXE_PATH + "\Engine\Binaries\Win64\UnrealEditor-Cmd.exe"
}

if ($args.length -eq 2) {
    Invoke-Diff -UE_exe $UE_EDITOR_EXE_PATH -Project $PROJECT_PATH -Left $args[0] -Right $args[1]
    return
}

if ($args.length -eq 2) {
    Invoke-Merge -UE_exe $UE_EDITOR_EXE_PATH -Project $PROJECT_PATH -Remote $args[0] -Local $args[1] -Base $args[2] -Merge $args[3]
    return
}

Write-Error "Incorrect arguments"
Write-Host $args
