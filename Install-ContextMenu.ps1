$ErrorActionPreference = 'Stop'

$converterPath = Join-Path -Path $PSScriptRoot -ChildPath 'ConvertChineseName.ps1'
if (-not (Test-Path -LiteralPath $converterPath)) {
    throw "Missing converter script: $converterPath"
}

function New-UnicodeString {
    param([int[]]$CodePoint)
    return (-join ($CodePoint | ForEach-Object { [char]$_ }))
}

$traditionalLabel = New-UnicodeString @(0x8F49, 0x63DB, 0x6A94, 0x540D, 0x70BA, 0x7E41, 0x9AD4, 0x4E2D, 0x6587)
$simplifiedLabel = New-UnicodeString @(0x8F49, 0x63DB, 0x6A94, 0x540D, 0x70BA, 0x7C21, 0x9AD4, 0x4E2D, 0x6587)

function Install-MenuEntry {
    param(
        [string]$Root,
        [string]$Name,
        [string]$Label,
        [string]$Direction
    )

    $baseKey = [Microsoft.Win32.Registry]::CurrentUser
    $menuPath = "$Root\shell\$Name"
    $command = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + $converterPath + '" -Direction "' + $Direction + '" -Path "%1"'
    $menuKey = $baseKey.CreateSubKey($menuPath)

    try {
        $menuKey.SetValue('', $Label, [Microsoft.Win32.RegistryValueKind]::String)
        $menuKey.SetValue('MultiSelectModel', 'Player', [Microsoft.Win32.RegistryValueKind]::String)
        $commandKey = $menuKey.CreateSubKey('command')
        try {
            $commandKey.SetValue('', $command, [Microsoft.Win32.RegistryValueKind]::String)
        }
        finally {
            $commandKey.Close()
        }
    }
    finally {
        $menuKey.Close()
    }
}

$roots = @(
    'Software\Classes\*',
    'Software\Classes\Directory'
)

foreach ($root in $roots) {
    Install-MenuEntry -Root $root -Name 'ConvertChinese.ToTraditional' -Label $traditionalLabel -Direction 'ToTraditional'
    Install-MenuEntry -Root $root -Name 'ConvertChinese.ToSimplified' -Label $simplifiedLabel -Direction 'ToSimplified'
}

Write-Host 'Context menu installed for files and folders.'
Write-Host 'If Explorer does not refresh immediately, restart Explorer or sign out and in.'
