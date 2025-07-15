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

$UE_PATH = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\EpicGames\Unreal Engine\5.2" -Name InstalledDirectory
$UE_PATH = $UE_PATH + "\Engine\Binaries\Win64\UnrealEditor.exe"

& $UE_PATH $PROJECT_PATH -diff $args
Write-Host 'Press a key when returned from the merge editor...'
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
