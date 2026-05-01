param(
    [Parameter(Mandatory=$true)]
    [string]$Name,

    [Parameter(Mandatory=$true)]
    [string]$LocalHome,

    [string]$SourceRoot = "",
    [string[]]$SourcePath = @(),
    [string[]]$GeneratedPath = @(),
    [string]$ToolPath = "",
    [string]$Note = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-DisplayPath {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }
    if (Test-Path -LiteralPath $Path) {
        return (Resolve-Path -LiteralPath $Path).Path
    }
    return $Path
}

function Add-File-Facts {
    param(
        [System.Collections.Generic.List[string]]$Lines,
        [string]$Label,
        [string[]]$Paths
    )

    [void]$Lines.Add("")
    [void]$Lines.Add($Label)
    if (-not $Paths -or $Paths.Count -eq 0) {
        [void]$Lines.Add("  none")
        return
    }

    foreach ($path in $Paths) {
        if (Test-Path -LiteralPath $path -PathType Leaf) {
            $item = Get-Item -LiteralPath $path
            $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $path
            [void]$Lines.Add(("  path: {0}" -f $item.FullName))
            [void]$Lines.Add(("    bytes: {0}" -f $item.Length))
            [void]$Lines.Add(("    mtime_utc: {0}" -f $item.LastWriteTimeUtc.ToString("o")))
            [void]$Lines.Add(("    sha256: {0}" -f $hash.Hash))
        } elseif (Test-Path -LiteralPath $path -PathType Container) {
            $item = Get-Item -LiteralPath $path
            [void]$Lines.Add(("  dir: {0}" -f $item.FullName))
            [void]$Lines.Add(("    mtime_utc: {0}" -f $item.LastWriteTimeUtc.ToString("o")))
        } else {
            [void]$Lines.Add(("  missing: {0}" -f $path))
        }
    }
}

New-Item -ItemType Directory -Force -Path $LocalHome | Out-Null

$lines = [System.Collections.Generic.List[string]]::new()
[void]$lines.Add(("name: {0}" -f $Name))
[void]$lines.Add(("stamp_local: {0}" -f (Get-Date).ToString("o")))
[void]$lines.Add(("stamp_utc: {0}" -f ([DateTime]::UtcNow.ToString("o"))))
[void]$lines.Add(("home: {0}" -f (Resolve-DisplayPath $LocalHome)))
if (-not [string]::IsNullOrWhiteSpace($SourceRoot)) {
    [void]$lines.Add(("source_root: {0}" -f (Resolve-DisplayPath $SourceRoot)))
}
if (-not [string]::IsNullOrWhiteSpace($ToolPath)) {
    [void]$lines.Add(("tool: {0}" -f (Resolve-DisplayPath $ToolPath)))
}
if (-not [string]::IsNullOrWhiteSpace($Note)) {
    [void]$lines.Add(("note: {0}" -f $Note))
}

Add-File-Facts -Lines $lines -Label "source_paths:" -Paths $SourcePath
Add-File-Facts -Lines $lines -Label "generated_paths:" -Paths $GeneratedPath

$outPath = Join-Path $LocalHome "PROVENANCE.txt"
Set-Content -Path $outPath -Value $lines -Encoding ASCII
Write-Host ("Wrote provenance {0}" -f $outPath)
