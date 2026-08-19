param(
    [string]$Str8nHome = "../../STR8-N",
    [string]$ManifestPath = "../../STR8-N/BUILD/str8n-manifest.json",
    [string]$LockPath = "INTEGRATION/str8n.lock.json",
    [string]$ImportedContractPath = "BUILD/inc/str8n-public.inc",
    [string]$ReceiptPath = "BUILD/integration/str8n-receipt.json",
    [switch]$RequireClean
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([string]$Message) { throw "external STR8-N check: $Message" }

function Assert-Equal($Actual, $Expected, [string]$Label) {
    if ([string]$Actual -cne [string]$Expected) {
        Fail "$Label is '$Actual'; expected '$Expected'"
    }
}

function Resolve-Artifact([string]$Root, [string]$RelativePath) {
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    $full = [IO.Path]::GetFullPath((Join-Path $Root $RelativePath))
    if (-not $full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        Fail "artifact escapes STR8N_HOME: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
        Fail "artifact is missing: $full"
    }
    return $full
}

foreach ($path in @($ManifestPath, $LockPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "missing input $path" }
}

$manifest = Get-Content -Raw -LiteralPath $ManifestPath | ConvertFrom-Json
$lock = Get-Content -Raw -LiteralPath $LockPath | ConvertFrom-Json

Assert-Equal $manifest.schema $lock.manifestSchema 'manifest schema'
Assert-Equal $manifest.project $lock.project 'project'
Assert-Equal $manifest.version $lock.version 'version'
Assert-Equal $manifest.repository $lock.repository 'repository'
if ($RequireClean -and [bool]$manifest.dirty) { Fail 'release manifest reports a dirty STR8-N worktree' }

$topPath = Resolve-Artifact $Str8nHome $manifest.artifacts.topSector.file
$contractPath = Resolve-Artifact $Str8nHome $manifest.artifacts.publicContract.file
$topHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $topPath).Hash
$contractHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $contractPath).Hash
Assert-Equal $topHash $manifest.artifacts.topSector.sha256 'top-sector file hash versus manifest'
Assert-Equal $contractHash $manifest.artifacts.publicContract.sha256 'public-contract file hash versus manifest'
Assert-Equal $topHash $lock.artifacts.topSectorSha256 'locked top-sector hash'
Assert-Equal $contractHash $lock.artifacts.publicContractSha256 'locked public-contract hash'

Assert-Equal $manifest.artifacts.topSector.size 4096 'top-sector size in manifest'
Assert-Equal $manifest.artifacts.topSector.cpuStart 'F000' 'top-sector start'
Assert-Equal $manifest.artifacts.topSector.cpuEnd 'FFFF' 'top-sector end'
foreach ($name in @('residentStart','residentEnd','unusedMargin','directoryStart','directoryEnd','configurationStart','configurationEnd','vectorsStart','vectorsEnd')) {
    Assert-Equal $manifest.layout.$name $lock.layout.$name "layout.$name"
}
foreach ($name in @('ramVersion','himonApLinkStart','himonApLinkEnd','bankJumpSig0','bankJumpSig1','bankLastJump','bankJumpSignature','bankCount','bankNone','bankSelectService','selectorEntry','selectorEnd','recordService','recordVersion','recordCapabilities','residentVersion','residentCapabilities')) {
    Assert-Equal $manifest.abi.$name $lock.abi.$name "abi.$name"
}

[byte[]]$top = [IO.File]::ReadAllBytes($topPath)
if ($top.Length -ne 4096) { Fail "top-sector file has $($top.Length) bytes; expected 4096" }
if ($top[0] -ne 0x4C) { Fail 'top sector does not begin with a JMP opcode' }
if ($top[0x0C] -ne 0x53 -or $top[0x0D] -ne 0x52 -or
        $top[0x0E] -ne [int]$manifest.abi.recordVersion -or
        $top[0x0F] -ne [int]$manifest.abi.recordCapabilities) {
    Fail 'top-sector record-service face does not match the manifest'
}
for ($offset = 0x0FB0; $offset -le 0x0FF9; $offset++) {
    if ($top[$offset] -ne 0xFF) { Fail ('fresh top-sector metadata byte +${0:X3} is not erased' -f $offset) }
}
if ($top[0x0FFC] -ne 0x00 -or $top[0x0FFD] -ne 0xF0) {
    Fail ('RESET vector is ${0:X2}{1:X2}; expected $F000' -f $top[0x0FFD], $top[0x0FFC])
}

$contractParent = Split-Path -Parent $ImportedContractPath
if ($contractParent) { New-Item -ItemType Directory -Force -Path $contractParent | Out-Null }
Copy-Item -LiteralPath $contractPath -Destination $ImportedContractPath -Force

$receipt = [ordered]@{
    schema = 1
    project = $manifest.project
    version = $manifest.version
    sourceCommit = $manifest.commit
    sourceDirty = [bool]$manifest.dirty
    topSectorSha256 = $topHash
    publicContractSha256 = $contractHash
}
$receiptParent = Split-Path -Parent $ReceiptPath
if ($receiptParent) { New-Item -ItemType Directory -Force -Path $receiptParent | Out-Null }
[IO.File]::WriteAllText($ReceiptPath, (($receipt | ConvertTo-Json -Depth 4) + [Environment]::NewLine), [Text.Encoding]::UTF8)

Write-Host ('STR8-N EXTERNAL      = PASS; {0} {1}' -f $manifest.version, $manifest.commit.Substring(0, 8))
Write-Host ('STR8-N TOP SHA-256   = {0}' -f $topHash)
Write-Host ('STR8-N ABI SHA-256   = {0}' -f $contractHash)
Write-Host ('STR8-N PUBLIC ABI    = {0}' -f $ImportedContractPath)
