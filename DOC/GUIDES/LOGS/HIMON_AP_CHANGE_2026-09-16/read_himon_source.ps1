# Expand the AP extraction includes at their assembly positions. Other include
# owners retain their existing checker-specific handling. Missing/cyclic AP
# includes fail closed; a move cannot silently select an obsolete checker path.
function Read-HimonSource {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [string]$SourceRoot = '',
        [string[]]$Parents = @()
    )
    $full = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
    if (-not $SourceRoot) { $SourceRoot = Split-Path -Parent (Split-Path -Parent $full) }
    if ($Parents -contains $full) { throw "Cyclic HIMON/AP include: $full" }
    $text = [IO.File]::ReadAllText($full)
    $pattern = '(?m)^[ \t]*INCLUDE[ \t]+"(AP/[^"\r\n]+\.inc|HIMON/himon-ap-adapter\.inc)"[ \t]*\r?$'
    return [regex]::Replace($text, $pattern, {
        param($match)
        Read-HimonSource -Path (Join-Path $SourceRoot $match.Groups[1].Value) `
            -SourceRoot $SourceRoot -Parents @($Parents + $full)
    })
}
