param(
    [string]$SourcePath = "../LOCAL/msbasic/generated/osi-basic.asm",
    [string]$OutPath = "../LOCAL/msbasic/generated/osi-basic-c000.asm"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SourcePath)) {
    throw "Generated OSI BASIC source not found: $SourcePath"
}

[string[]]$lines = Get-Content -Path $SourcePath
$out = New-Object System.Collections.Generic.List[string]

for ($i = 0; $i -lt $lines.Count; $i++) {
    if (
        $i + 3 -lt $lines.Count -and
        $lines[$i].Trim() -eq "MSBASIC_FNV:" -and
        $lines[$i + 1].Trim().StartsWith("DB") -and
        $lines[$i + 2].Trim() -eq "MSBASIC_ENTRY:" -and
        $lines[$i + 3].Trim() -eq "JMP             COLD_START"
    ) {
        $out.Add("START:")
        $out.Add("                        JMP             COLD_START")
        $out.Add($lines[$i])
        $out.Add($lines[$i + 1])
        $out.Add($lines[$i + 2])
        $out.Add($lines[$i + 3])
        $i += 3
        continue
    }

    if (
        $i + 5 -lt $lines.Count -and
        $lines[$i].Trim() -eq "MSBASIC_MONISCNTC:" -and
        $lines[$i + 1].Trim() -eq "MONISCNTC:" -and
        $lines[$i + 2].Trim() -eq "JSR             MSBASIC_GET_CTRL_C_ADDR" -and
        $lines[$i + 3].Trim() -eq "BCC             MSBASIC_MONISCNTC_DONE" -and
        $lines[$i + 4].Trim() -eq "JMP             CONTROL_C_TYPED" -and
        $lines[$i + 5].Trim() -eq "MSBASIC_MONISCNTC_DONE:"
    ) {
        $out.Add($lines[$i])
        $out.Add($lines[$i + 1])
        $out.Add("                        CLC")
        $out.Add("                        RTS")
        $i += 6
        continue
    }

    $out.Add($lines[$i])
}

$parent = Split-Path -Parent $OutPath
if ($parent) {
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
}

[System.IO.File]::WriteAllLines($OutPath, $out, [System.Text.Encoding]::ASCII)
Write-Host ("Generated C000 OSI BASIC source = {0}" -f $OutPath)
