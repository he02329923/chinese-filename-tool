$ErrorActionPreference = 'Stop'

$baseKey = [Microsoft.Win32.Registry]::CurrentUser
$roots = @(
    'Software\Classes\*',
    'Software\Classes\Directory'
)

foreach ($root in $roots) {
    foreach ($name in @('ConvertChinese.ToTraditional', 'ConvertChinese.ToSimplified')) {
        $menuPath = "$root\shell\$name"
        try {
            $baseKey.DeleteSubKeyTree($menuPath, $false)
        }
        catch [System.ArgumentException] {
            # The entry was already absent.
        }
    }
}

Write-Host 'Context menu entries removed.'
