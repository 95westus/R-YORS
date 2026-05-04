function Ensure-BinFirstByte {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [byte]$Sentinel = 0x00,
        [byte[]]$Prefix,
        [switch]$Quiet
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "BIN file not found: $Path"
    }

    [byte[]]$bin = [System.IO.File]::ReadAllBytes($Path)
    if ($bin.Length -le 0) {
        throw "BIN file is empty: $Path"
    }

    $changed = $false
    if ($bin[0] -eq 0xFF) {
        if (-not $Prefix -or $Prefix.Count -eq 0) {
            $Prefix = @($Sentinel)
        }
        if ($Prefix.Count -gt $bin.Length) {
            throw "BIN prefix is longer than file: $Path"
        }

        for ($i = 0; $i -lt $Prefix.Count; $i++) {
            if ($bin[$i] -ne 0xFF -and $bin[$i] -ne $Prefix[$i]) {
                throw ("Cannot write BIN first-byte prefix at offset {0}: existing {1:X2}, prefix {2:X2}" -f $i, $bin[$i], $Prefix[$i])
            }
        }

        for ($i = 0; $i -lt $Prefix.Count; $i++) {
            $bin[$i] = $Prefix[$i]
        }
        [System.IO.File]::WriteAllBytes($Path, $bin)
        $changed = $true
    }

    $headCount = [Math]::Min(16, $bin.Length)
    $head = @()
    for ($i = 0; $i -lt $headCount; $i++) {
        $head += ("{0:X2}" -f $bin[$i])
    }

    if (-not $Quiet) {
        Write-Host ("BIN first bytes          = {0}" -f ($head -join " "))
        if ($changed) {
            $prefixText = ($Prefix | ForEach-Object { "{0:X2}" -f $_ }) -join " "
            Write-Host ("BIN first-byte prefix    = wrote {0} at offset 0 for burner compatibility" -f $prefixText)
        } else {
            Write-Host ("BIN first-byte prefix    = offset 0 already {0:X2}" -f $bin[0])
        }
    }
}
