param(
    [Parameter(Mandatory = $true)][string]$PackagePath,
    [Parameter(Mandatory = $true)][string]$BinPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $PackagePath -PathType Leaf)) {
    throw "Missing AP package: $PackagePath"
}
[byte[]]$package = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $PackagePath))
if ($package.Length -lt 5 -or $package.Length -gt 0x1000) {
    throw ('AP package length ${0:X4} is outside $0005-$1000' -f $package.Length)
}
if ($package[0] -ne [byte][char]'A' -or
        $package[1] -ne [byte][char]'P' -or $package[2] -ne 2) {
    throw 'Carrier input is not an AP v2 envelope'
}
$declared = [int]$package[3] -bor ([int]$package[4] -shl 8)
if ($declared -ne $package.Length) {
    throw ('AP declared length ${0:X4} does not match file length ${1:X4}' -f
        $declared, $package.Length)
}

[byte[]]$sector = New-Object byte[] 0x1000
for ($i = 0; $i -lt $sector.Length; $i++) { $sector[$i] = 0xFF }
[Array]::Copy($package, 0, $sector, 0, $package.Length)
$parent = Split-Path -Parent $BinPath
if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
[IO.File]::WriteAllBytes($BinPath, $sector)

$tailUsed = 0
for ($i = $package.Length; $i -lt 0x1000; $i++) {
    if ($sector[$i] -ne 0xFF) { $tailUsed++ }
}
if ($tailUsed -ne 0) { throw 'Carrier sector padding is not erased' }
Write-Host ('AP carrier sector built: {0}' -f (Resolve-Path -LiteralPath $BinPath))
Write-Host ('  envelope: $0000-${0:X4} length=${1:X4}' -f ($package.Length - 1), $package.Length)
Write-Host '  sector:   $0000-$0FFF length=$1000; erased tail verified'
