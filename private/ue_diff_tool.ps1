<#

This is a PowerShell script that can be used as a difftool or a mergetool from inside git.
It is hard-coded to use Unreal Engine 5.2 local installation, but it is easy to adjust to
different UE versions.

Configuration:

* ~\.gitconfig
==============

[diff "UE_Diff"]
    tool = UE_Diff_Tool
    binary = true
[difftool "UE_Diff_Tool"]
    cmd = powershell 'C:\\path-to\\ue_diff_tool.ps1' "$REMOTE" "$LOCAL"

[merge "UE_Merge"]
    tool = UE_Merge_Tool
    binary = true
[mergetool "UE_Merge_Tool"]
    cmd = powershell 'C:\\path-to\\ue_diff_tool.ps1' "$REMOTE" "$LOCAL" "$BASE" "$MERGED"
	keepBackup = true

[merge "UE_Compare_Remote_Base"]
    tool = UE_Compare_Remote_Base_Tool
    binary = true
[mergetool "UE_Compare_Remote_Base_Tool"]
    cmd = powershell 'C:\\path-to\\ue_diff_tool.ps1' "$BASE" "$REMOTE"

[merge "UE_Compare_Local_Base"]
    tool = UE_Compare_Local_Base_Tool
    binary = true
[mergetool "UE_Compare_Local_Base_Tool"]
    cmd = powershell 'C:\\path-to\\ue_diff_tool.ps1' "$BASE" "$LOCAL"

Usage:

* git-bash
==========

# REBASING A BRANCH
-------------------

# start local rebase
git checkout Dev_MyFeatureBranch  # being based on an older commit on Development, a.k.a Base
git rebase Development

# anytime you can check the state of rebase like this
git status

# now build the project for the project's default config (usually Development/Editor/Win64)
# there seems to be no option to tell the `-diff` command to use a different target or configuration

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

# being e.g. in `ProjectRoot/Plugins/PluginRoot`, you can diff whole dir or a single file
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

# Main

for ($i = 0; $i -lt $args.length; $i++) {
    try {
        if ($args[$i] -eq "nul") { continue }
        
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


if ($Env:UE_INSTALL_PATH) {
    $UE_EDITOR_EXE_PATH = $Env:UE_INSTALL_PATH
} else {
    # Unreal Engine executable auto-detection
    $UE_EDITOR_EXE_PATH = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\EpicGames\Unreal Engine\5.2" -Name InstalledDirectory
}
$UE_EDITOR_EXE_PATH = $UE_EDITOR_EXE_PATH + "\Engine\Binaries\Win64\UnrealEditor-Cmd.exe"


function Invoke-Diff {
    param (
        [string]$Left,
        [string]$Right
    )

    if ($Left -eq "nul") {
        Write-Host "    added: " (Split-Path $Right -leaf) " " -NoNewline -ForegroundColor DarkGreen
        Write-Host "[SHOWING DIFF OF ITSELF]" -BackgroundColor DarkGray -ForegroundColor Black
        & $UE_EDITOR_EXE_PATH $PROJECT_PATH -diff $Right $Right | out-null
        return
    }
    if ($Right -eq "nul") {
        Write-Host "  removed: " (Split-Path $Left -leaf) " " -NoNewline -ForegroundColor DarkRed
        Write-Host "[SHOWING DIFF OF ITSELF]" -BackgroundColor DarkGray -ForegroundColor Black
        & $UE_EDITOR_EXE_PATH $PROJECT_PATH -diff $Left $Left | out-null
        return
    }

    Write-Host " modified: " (Split-Path $Right -leaf) -ForegroundColor DarkBlue
    & $UE_EDITOR_EXE_PATH $PROJECT_PATH -diff $Left $Right | out-null
}

function Invoke-Merge {
    param (
        [string]$Remote,
        [string]$Local,
        [string]$Base,
        [string]$Merge
    )

    Write-Host "    merge: " $Base -ForegroundColor DarkYellow
    & $UE_EDITOR_EXE_PATH $PROJECT_PATH -diff $Remote $Local $Base $Merge | out-null
}


if ($args.length -eq 2) {
    Invoke-Diff -Left $args[0] -Right $args[1]
    return
}

if ($args.length -eq 4) {
    Invoke-Merge -Remote $args[0] -Local $args[1] -Base $args[2] -Merge $args[3]
    return
}

Write-Error "Incorrect arguments"
Write-Host $args
