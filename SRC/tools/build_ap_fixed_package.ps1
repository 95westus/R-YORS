param(
  [Parameter(Mandatory = $true)][string]$S19Path,
  [Parameter(Mandatory = $true)][string]$MapPath,
  [Parameter(Mandatory = $true)][string]$PackagePath,
  [int]$BaseAddress = 0x4800,
  [string]$EntrySymbol = "START",
  [string]$ExportName = "START"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-ArtifactPath {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string[]]$FallbackRoots = @()
  )

  if (Test-Path -LiteralPath $Path) {
    return (Resolve-Path -LiteralPath $Path).Path
  }

  foreach ($root in $FallbackRoots) {
    $candidate = Join-Path $root (Split-Path -Leaf $Path)
    if (Test-Path -LiteralPath $candidate) {
      return (Resolve-Path -LiteralPath $candidate).Path
    }
  }

  throw "missing artifact: $Path"
}

function Get-SymbolAddress {
  param(
    [Parameter(Mandatory = $true)][string]$ResolvedMapPath,
    [Parameter(Mandatory = $true)][string]$Symbol
  )

  $patterns = @(
    "^\s*([0-9A-Fa-f]{4,8})\s+.*\b$([regex]::Escape($Symbol))\b",
    "^\s*$([regex]::Escape($Symbol))\s+([0-9A-Fa-f]{4,8})\b"
  )

  foreach ($line in Get-Content -LiteralPath $ResolvedMapPath) {
    foreach ($pattern in $patterns) {
      if ($line -match $pattern) {
        return ([Convert]::ToInt32($matches[1], 16) -band 0xFFFF)
      }
    }
  }

  throw "symbol '$Symbol' not found in $ResolvedMapPath"
}

function ConvertFrom-HexByte {
  param([Parameter(Mandatory = $true)][string]$Text)
  return [byte][Convert]::ToInt32($Text, 16)
}

function Read-S19Data {
  param([Parameter(Mandatory = $true)][string]$ResolvedS19Path)

  $data = @{}
  $lineNumber = 0

  foreach ($line in Get-Content -LiteralPath $ResolvedS19Path) {
    $lineNumber++
    $trimmed = $line.Trim()
    if ($trimmed.Length -eq 0) {
      continue
    }
    if (-not $trimmed.StartsWith("S")) {
      throw "${ResolvedS19Path}:$lineNumber is not an S-record"
    }

    $recordType = $trimmed.Substring(1, 1)
    if ($recordType -notin @("1", "2", "3", "7", "8", "9")) {
      continue
    }

    $count = ConvertFrom-HexByte $trimmed.Substring(2, 2)
    $expectedChars = 4 + ($count * 2)
    if ($trimmed.Length -lt $expectedChars) {
      throw "${ResolvedS19Path}:$lineNumber is truncated"
    }

    $bytes = New-Object byte[] ($count + 1)
    $bytes[0] = ConvertFrom-HexByte $trimmed.Substring(2, 2)
    for ($i = 0; $i -lt $count; $i++) {
      $bytes[$i + 1] = ConvertFrom-HexByte $trimmed.Substring(4 + ($i * 2), 2)
    }

    $sum = 0
    foreach ($byte in $bytes) {
      $sum = ($sum + [int]$byte) -band 0xFF
    }
    if ($sum -ne 0xFF) {
      throw "${ResolvedS19Path}:$lineNumber checksum failed"
    }

    if ($recordType -in @("7", "8", "9")) {
      continue
    }

    $addressBytes =
      if ($recordType -eq "1") { 2 }
      elseif ($recordType -eq "2") { 3 }
      else { 4 }

    $address = 0
    for ($i = 0; $i -lt $addressBytes; $i++) {
      $address = ($address * 0x100) + [int]$bytes[$i + 1]
    }
    $address = $address -band 0xFFFF

    $payloadCount = $count - $addressBytes - 1
    for ($i = 0; $i -lt $payloadCount; $i++) {
      $absolute = ($address + $i) -band 0xFFFF
      $value = $bytes[1 + $addressBytes + $i]
      if ($data.ContainsKey($absolute) -and ([byte]$data[$absolute]) -ne $value) {
        throw "${ResolvedS19Path}:$lineNumber conflicts at address $("{0:X4}" -f $absolute)"
      }
      $data[$absolute] = $value
    }
  }

  return $data
}

function Get-BodyBytes {
  param(
    [Parameter(Mandatory = $true)]$Data,
    [int]$Base,
    [int]$End
  )

  if ($End -le $Base) {
    throw "empty body range $("{0:X4}" -f $Base)-$("{0:X4}" -f $End)"
  }

  $length = $End - $Base
  $body = New-Object byte[] $length
  for ($i = 0; $i -lt $length; $i++) {
    $address = ($Base + $i) -band 0xFFFF
    if (-not $Data.ContainsKey($address)) {
      throw "S19 has a gap at address $("{0:X4}" -f $address)"
    }
    $body[$i] = [byte]$Data[$address]
  }

  return $body
}

function Get-Fnv1a32 {
  param([Parameter(Mandatory = $true)][byte[]]$Bytes)

  $hash = [uint64]2166136261
  foreach ($byte in $Bytes) {
    $hash = (($hash -bxor [uint64]$byte) * [uint64]16777619) -band [uint64]4294967295
  }

  return [uint32]$hash
}

function Get-Pack40Code {
  param([char]$Char)

  if ($Char -ge 'A' -and $Char -le 'Z') {
    return ([int][char]$Char - [int][char]'A' + 1)
  }
  if ($Char -ge '0' -and $Char -le '9') {
    return ([int][char]$Char - [int][char]'0' + 27)
  }
  if ($Char -eq '_') {
    return 37
  }
  if ($Char -eq '?') {
    return 38
  }
  if ($Char -eq '.') {
    return 39
  }

  throw "export name '$ExportName' contains unsupported PACK40 character '$Char'"
}

function Get-Pack40NameBytes {
  param([Parameter(Mandatory = $true)][string]$Name)

  $upper = $Name.ToUpperInvariant()
  $bytes = New-Object 'System.Collections.Generic.List[byte]'

  for ($i = 0; $i -lt $upper.Length; $i += 3) {
    $codes = @(0, 0, 0)
    for ($j = 0; $j -lt 3; $j++) {
      if (($i + $j) -lt $upper.Length) {
        $codes[$j] = Get-Pack40Code $upper[$i + $j]
      }
    }

    $value = (($codes[0] * 40) + $codes[1]) * 40 + $codes[2]
    $bytes.Add([byte]($value -band 0xFF))
    $bytes.Add([byte](($value -shr 8) -band 0xFF))
  }

  return $bytes.ToArray()
}

function Add-Byte {
  param(
    [Parameter(Mandatory = $true)]$List,
    [int]$Value
  )
  $List.Add([byte]($Value -band 0xFF))
}

function Add-WordLe {
  param(
    [Parameter(Mandatory = $true)]$List,
    [int]$Value
  )
  Add-Byte $List $Value
  Add-Byte $List ($Value -shr 8)
}

function Add-Bytes {
  param(
    [Parameter(Mandatory = $true)]$List,
    [Parameter(Mandatory = $true)][byte[]]$Bytes
  )
  foreach ($byte in $Bytes) {
    Add-Byte $List $byte
  }
}

$scriptDir = Split-Path -Parent $PSCommandPath
$srcDir = Split-Path -Parent $scriptDir
$s19Dir = Join-Path $srcDir "BUILD\s19"
$mapDir = Join-Path $srcDir "BUILD\map"

$resolvedS19 = Resolve-ArtifactPath $S19Path @($s19Dir)
$resolvedMap = Resolve-ArtifactPath $MapPath @($s19Dir, $mapDir)
$resolvedPackage = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PackagePath)
$packageDir = Split-Path -Parent $resolvedPackage
if ($packageDir -and -not (Test-Path -LiteralPath $packageDir)) {
  New-Item -ItemType Directory -Force -Path $packageDir | Out-Null
}

$base = $BaseAddress -band 0xFFFF
$entryAddress = Get-SymbolAddress $resolvedMap $EntrySymbol
$endAddress = Get-SymbolAddress $resolvedMap "_END_DATA"

if ($entryAddress -lt $base -or $entryAddress -ge $endAddress) {
  throw "entry $EntrySymbol=$("{0:X4}" -f $entryAddress) is outside body $("{0:X4}" -f $base)-$("{0:X4}" -f $endAddress)"
}
if ($endAddress -gt 0x10000) {
  throw "body end address is outside 16-bit memory"
}

$data = Read-S19Data $resolvedS19
$body = Get-BodyBytes $data $base $endAddress
$bodyLength = $body.Length
if ($bodyLength -gt 0xFFFF) {
  throw "body is too large for AP package: $bodyLength bytes"
}

$hash = Get-Fnv1a32 $body
$entryOffset = $entryAddress - $base
$exportNameUpper = $ExportName.ToUpperInvariant()
$exportNameBytes = Get-Pack40NameBytes $exportNameUpper
$exportRecordLength = 2 + 2 + 1 + $exportNameBytes.Length
if ($exportRecordLength -gt 0xFF) {
  throw "export record is too large: $exportRecordLength bytes"
}

$sections = New-Object 'System.Collections.Generic.List[byte]'

Add-Byte $sections ([byte][char]'S')
Add-Byte $sections 0x0B
Add-Byte $sections 0x01
Add-WordLe $sections $base
Add-WordLe $sections $endAddress
Add-WordLe $sections $bodyLength
Add-Byte $sections ($hash -band 0xFF)
Add-Byte $sections (($hash -shr 8) -band 0xFF)
Add-Byte $sections (($hash -shr 16) -band 0xFF)
Add-Byte $sections (($hash -shr 24) -band 0xFF)

Add-Byte $sections ([byte][char]'R')
Add-Byte $sections 0x01
Add-Byte $sections 0x00

Add-Byte $sections ([byte][char]'E')
Add-Byte $sections $exportRecordLength
Add-Byte $sections 0x01
Add-Byte $sections $exportRecordLength
Add-WordLe $sections $entryOffset
Add-Byte $sections $exportNameUpper.Length
Add-Bytes $sections $exportNameBytes

Add-Byte $sections ([byte][char]'I')
Add-Byte $sections 0x02
Add-Byte $sections 0x00
Add-Byte $sections 0x02

Add-Byte $sections ([byte][char]'B')
Add-WordLe $sections $bodyLength
Add-Bytes $sections $body

$totalLength = 5 + $sections.Count
if ($totalLength -gt 0xFFFF) {
  throw "AP package is too large: $totalLength bytes"
}

$package = New-Object 'System.Collections.Generic.List[byte]'
Add-Byte $package ([byte][char]'A')
Add-Byte $package ([byte][char]'P')
Add-Byte $package 0x01
Add-WordLe $package $totalLength
Add-Bytes $package $sections.ToArray()

[System.IO.File]::WriteAllBytes($resolvedPackage, $package.ToArray())

$head = ($package.ToArray() | Select-Object -First 24 | ForEach-Object { "{0:X2}" -f $_ }) -join " "
Write-Host ("AP package built: {0}" -f $resolvedPackage)
Write-Host ("  body: `${0}-`${1} len=`${2}" -f ("{0:X4}" -f $base), ("{0:X4}" -f $endAddress), ("{0:X4}" -f $bodyLength))
Write-Host ("  entry/export: {0} @ `${1} offset=`${2}" -f $exportNameUpper, ("{0:X4}" -f $entryAddress), ("{0:X4}" -f $entryOffset))
Write-Host ("  fnv32: `${0}" -f ("{0:X8}" -f $hash))
Write-Host ("  package length: `${0}" -f ("{0:X4}" -f $totalLength))
Write-Host ("  head: $head")
