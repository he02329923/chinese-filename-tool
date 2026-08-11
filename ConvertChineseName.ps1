param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('ToTraditional', 'ToSimplified')]
    [string]$Direction,

    [switch]$Quiet,

    [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)]
    [string[]]$Path
)

$ErrorActionPreference = 'Stop'

function Show-Result {
    param(
        [string]$Message,
        [string]$Title,
        [System.Windows.Forms.MessageBoxIcon]$Icon
    )

    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        $Icon
    ) | Out-Null
}

function Unescape-Unicode {
    param([string]$Value)
    return [System.Text.RegularExpressions.Regex]::Unescape($Value)
}

function Convert-ChineseText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,

        [Parameter(Mandatory = $true)]
        [string]$Mode
    )

    Add-Type -AssemblyName Microsoft.VisualBasic

    # Windows StrConv handles the basic character conversion. These phrase
    # replacements make common Taiwan-style filenames more natural.
    $toTraditionalPhrases = New-Object System.Collections.Specialized.OrderedDictionary
    $toTraditionalPhrases.Add((Unescape-Unicode '\u8F6F\u4EF6'), (Unescape-Unicode '\u8EDF\u9AD4'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u6587\u4EF6'), (Unescape-Unicode '\u6A94\u6848'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u7F51\u7EDC'), (Unescape-Unicode '\u7DB2\u8DEF'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u89C6\u9891'), (Unescape-Unicode '\u5F71\u7247'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u670D\u52A1\u5668'), (Unescape-Unicode '\u4F3A\u670D\u5668'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u6570\u636E\u5E93'), (Unescape-Unicode '\u8CC7\u6599\u5EAB'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u7A0B\u5E8F'), (Unescape-Unicode '\u7A0B\u5F0F'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u6253\u5370\u673A'), (Unescape-Unicode '\u5370\u8868\u6A5F'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u9F20\u6807'), (Unescape-Unicode '\u6ED1\u9F20'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u786C\u76D8'), (Unescape-Unicode '\u786C\u789F'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u5C4F\u5E55'), (Unescape-Unicode '\u87A2\u5E55'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u8D26\u6237'), (Unescape-Unicode '\u5E33\u6236'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u8D26\u53F7'), (Unescape-Unicode '\u5E33\u865F'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u4FE1\u606F'), (Unescape-Unicode '\u8CC7\u8A0A'))
    $toTraditionalPhrases.Add((Unescape-Unicode '\u6587\u4EF6\u5939'), (Unescape-Unicode '\u8CC7\u6599\u593E'))

    $toSimplifiedPhrases = New-Object System.Collections.Specialized.OrderedDictionary
    foreach ($pair in $toTraditionalPhrases.GetEnumerator()) {
        $toSimplifiedPhrases.Add($pair.Value, $pair.Key)
    }

    # LCID 2052 selects the Windows Chinese conversion table.
    if ($Mode -eq 'ToTraditional') {
        foreach ($pair in ($toTraditionalPhrases.GetEnumerator() | Sort-Object { $_.Key.Length } -Descending)) {
            $Text = $Text.Replace($pair.Key, $pair.Value)
        }

        return [Microsoft.VisualBasic.Strings]::StrConv(
            $Text,
            [Microsoft.VisualBasic.VbStrConv]::TraditionalChinese,
            2052
        )
    }

    foreach ($pair in ($toSimplifiedPhrases.GetEnumerator() | Sort-Object { $_.Key.Length } -Descending)) {
        $Text = $Text.Replace($pair.Key, $pair.Value)
    }

    return [Microsoft.VisualBasic.Strings]::StrConv(
        $Text,
        [Microsoft.VisualBasic.VbStrConv]::SimplifiedChinese,
        2052
    )
}

function Get-ParentDirectory {
    param([System.IO.FileSystemInfo]$Item)

    if ($Item.PSIsContainer) {
        if ($null -eq $Item.Parent) {
            return $null
        }
        return $Item.Parent.FullName
    }

    return $Item.DirectoryName
}

$renamed = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]
$errors = New-Object System.Collections.Generic.List[string]

foreach ($inputPath in $Path) {
    try {
        if ([string]::IsNullOrWhiteSpace($inputPath)) {
            continue
        }

        $item = Get-Item -LiteralPath $inputPath -Force -ErrorAction Stop
        $parent = Get-ParentDirectory -Item $item

        if ([string]::IsNullOrWhiteSpace($parent)) {
            $errors.Add("Cannot rename a filesystem root: $($item.FullName)")
            continue
        }

        $extension = ''
        $baseName = $item.Name

        if (-not $item.PSIsContainer) {
            $extension = [System.IO.Path]::GetExtension($item.Name)
            if ($extension.Length -gt 0) {
                $baseName = $item.Name.Substring(0, $item.Name.Length - $extension.Length)
            }
        }

        $convertedBaseName = Convert-ChineseText -Text $baseName -Mode $Direction
        $newName = $convertedBaseName + $extension

        if ($newName -eq $item.Name) {
            $skipped.Add("No change: $($item.Name)")
            continue
        }

        $targetPath = Join-Path -Path $parent -ChildPath $newName
        if (Test-Path -LiteralPath $targetPath) {
            $errors.Add("Name already exists: $newName")
            continue
        }

        Rename-Item -LiteralPath $item.FullName -NewName $newName -ErrorAction Stop
        $renamed.Add("$($item.Name) -> $newName")
    }
    catch {
        $errors.Add("$inputPath : $($_.Exception.Message)")
    }
}

if ($Quiet -and $errors.Count -eq 0) {
    exit 0
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("Renamed: $($renamed.Count)")
$lines.Add("Skipped: $($skipped.Count)")
$lines.Add("Errors: $($errors.Count)")

if ($renamed.Count -gt 0) {
    $lines.Add('')
    $lines.AddRange($renamed)
}

if ($errors.Count -gt 0) {
    $lines.Add('')
    $lines.AddRange($errors)
}

Add-Type -AssemblyName System.Windows.Forms

$icon = if ($errors.Count -gt 0) {
    [System.Windows.Forms.MessageBoxIcon]::Warning
} else {
    [System.Windows.Forms.MessageBoxIcon]::Information
}

Show-Result -Message ($lines -join [Environment]::NewLine) -Title 'Chinese filename conversion' -Icon $icon
