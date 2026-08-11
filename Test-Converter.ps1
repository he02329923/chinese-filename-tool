$ErrorActionPreference = 'Stop'

$converter = Join-Path $PSScriptRoot 'ConvertChineseName.ps1'
$testDirectory = Join-Path $env:TEMP 'ChineseFilenameConverterTest'

function U {
    param([string]$Value)
    return [System.Text.RegularExpressions.Regex]::Unescape($Value)
}

if (Test-Path -LiteralPath $testDirectory) {
    Remove-Item -LiteralPath $testDirectory -Recurse -Force
}

New-Item -Path $testDirectory -ItemType Directory -Force | Out-Null
New-Item -Path (Join-Path $testDirectory (U '\u8F6F\u4EF6 \u6587\u4EF6 \u8BA1\u7B97\u673A.txt')) -ItemType File | Out-Null
New-Item -Path (Join-Path $testDirectory (U '\u7DB2\u8DEF \u9AD4\u9A57.txt')) -ItemType File | Out-Null
New-Item -Path (Join-Path $testDirectory (U '\u6587\u4EF6\u5939')) -ItemType Directory | Out-Null
New-Item -Path (Join-Path $testDirectory (U '\u8EDF\u9AD4 \u6A94\u6848.txt')) -ItemType File | Out-Null

& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $converter -Direction ToTraditional -Quiet -Path (Join-Path $testDirectory (U '\u8F6F\u4EF6 \u6587\u4EF6 \u8BA1\u7B97\u673A.txt'))
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $converter -Direction ToSimplified -Quiet -Path (Join-Path $testDirectory (U '\u7DB2\u8DEF \u9AD4\u9A57.txt'))
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $converter -Direction ToTraditional -Quiet -Path (Join-Path $testDirectory (U '\u6587\u4EF6\u5939'))
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $converter -Direction ToSimplified -Quiet -Path (Join-Path $testDirectory (U '\u8EDF\u9AD4 \u6A94\u6848.txt'))

$expectedTraditional = Join-Path $testDirectory (U '\u8EDF\u9AD4 \u6A94\u6848 \u8A08\u7B97\u6A5F.txt')
$expectedSimplified = Join-Path $testDirectory (U '\u7F51\u7EDC \u4F53\u9A8C.txt')
$expectedTraditionalDirectory = Join-Path $testDirectory (U '\u8CC7\u6599\u593E')
$expectedSimplifiedPhrase = Join-Path $testDirectory (U '\u8F6F\u4EF6 \u6587\u4EF6.txt')

if (-not (Test-Path -LiteralPath $expectedTraditional)) {
    throw "Traditional conversion test failed: $expectedTraditional"
}
if (-not (Test-Path -LiteralPath $expectedSimplified)) {
    throw "Simplified conversion test failed: $expectedSimplified"
}
if (-not (Test-Path -LiteralPath $expectedTraditionalDirectory -PathType Container)) {
    throw "Directory conversion test failed: $expectedTraditionalDirectory"
}
if (-not (Test-Path -LiteralPath $expectedSimplifiedPhrase)) {
    throw "Simplified phrase conversion test failed: $expectedSimplifiedPhrase"
}

Remove-Item -LiteralPath $testDirectory -Recurse -Force
Write-Host 'Converter tests passed.'
