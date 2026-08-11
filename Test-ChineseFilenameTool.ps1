$ErrorActionPreference = 'Stop'

function U {
    param([string]$Value)
    return [System.Text.RegularExpressions.Regex]::Unescape($Value)
}

$tool = Join-Path $PSScriptRoot 'ChineseFilenameTool.exe'
$testDirectory = Join-Path $env:TEMP 'ChineseFilenameToolTest'

if (Test-Path -LiteralPath $testDirectory) {
    Remove-Item -LiteralPath $testDirectory -Recurse -Force
}

New-Item -Path $testDirectory -ItemType Directory -Force | Out-Null
$simplifiedFile = Join-Path $testDirectory (U '\u8F6F\u4EF6 \u6587\u4EF6.txt')
$traditionalFile = Join-Path $testDirectory (U '\u8EDF\u9AD4 \u6A94\u6848.txt')
$simplifiedFolder = Join-Path $testDirectory (U '\u6587\u4EF6\u5939')
$traditionalFolder = Join-Path $testDirectory (U '\u8CC7\u6599\u593E')

New-Item -Path $simplifiedFile -ItemType File | Out-Null
New-Item -Path $simplifiedFolder -ItemType Directory | Out-Null

$process = Start-Process -FilePath $tool -ArgumentList @('--to-traditional', '--quiet', ('"' + $simplifiedFile + '"'), ('"' + $simplifiedFolder + '"')) -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "EXE traditional conversion failed: $($process.ExitCode)" }
if (-not (Test-Path -LiteralPath (Join-Path $testDirectory (U '\u8EDF\u9AD4 \u6A94\u6848.txt')))) { throw 'Traditional filename was not created.' }
if (-not (Test-Path -LiteralPath $traditionalFolder -PathType Container)) { throw 'Traditional folder was not created.' }

$process = Start-Process -FilePath $tool -ArgumentList @('--to-simplified', '--quiet', ('"' + $traditionalFile + '"')) -Wait -PassThru
if ($process.ExitCode -ne 0) { throw "EXE simplified conversion failed: $($process.ExitCode)" }
if (-not (Test-Path -LiteralPath (Join-Path $testDirectory (U '\u8F6F\u4EF6 \u6587\u4EF6.txt')))) { throw 'Simplified filename was not created.' }

Remove-Item -LiteralPath $testDirectory -Recurse -Force
Write-Host 'EXE conversion tests passed.'
