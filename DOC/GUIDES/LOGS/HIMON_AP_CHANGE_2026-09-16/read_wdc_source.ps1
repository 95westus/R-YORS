# Preserve source line numbers while excluding branches with literal IF 0/1.
# Other build conditions remain conservative; this is not a linked stack proof.
function Read-ActiveSourceLines {
    param([string]$Path, [string]$Text)
    $sourceLines = if ($PSBoundParameters.ContainsKey('Text')) { $Text -split '\r?\n' } else { [IO.File]::ReadAllLines($Path) }
    $frames = [Collections.Generic.List[object]]::new()
    $active = $true
    for ($index = 0; $index -lt $sourceLines.Count; $index++) {
        $code = ($sourceLines[$index] -split ';', 2)[0].Trim()
        if ($code -match '^(IF|IFDEF|IFNDEF)\s+(.+)$') {
            $known = $matches[1] -eq 'IF' -and $matches[2] -match '^\$?0*([01])$'
            $value = -not $known -or $matches[1] -eq '1'
            $frames.Add([pscustomobject]@{ Parent=$active; Known=$known; Value=$value })
            $active = $active -and $value
        } elseif ($code -eq 'ELSE' -and $frames.Count -gt 0) {
            $frame = $frames[$frames.Count - 1]
            $active = $frame.Parent -and (-not $frame.Known -or -not $frame.Value)
        } elseif ($code -eq 'ENDIF' -and $frames.Count -gt 0) {
            $active = $frames[$frames.Count - 1].Parent
            $frames.RemoveAt($frames.Count - 1)
        }
        if (-not $active) { $sourceLines[$index] = '' }
    }
    if ($frames.Count -ne 0) { throw "Unbalanced conditional source: $Path" }
    return ,$sourceLines
}

