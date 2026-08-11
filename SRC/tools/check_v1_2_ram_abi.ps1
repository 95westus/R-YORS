Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$files = @(
    'STR8/str8.asm',
    'STR8/str8-worker.asm',
    'STR8/str8-jump-eq.inc',
    'STR8/str8-ram-abi.inc',
    'HIMON/himon.asm',
    'ASM/asm-v1-core.asm',
    '../DOC/GUIDES/ASM/SAMPLES/str8n-v1.2-bank-maint-2000.a',
    '../DOC/GUIDES/ASM/SAMPLES/str8n-v1.2-bank-crc-all-3000.a',
    '../DOC/GUIDES/ASM/SAMPLES/str8n-v1.2-flash-bank-read-ap-2000.a',
    '../DOC/GUIDES/ASM/SAMPLES/str8n-v1.2-flash-bank-dump-ap-2000.a',
    '../DOC/GUIDES/ASM/SAMPLES/asm-session-report-v1.2-ap-2000.a',
    '../DOC/GUIDES/ASM/SAMPLES/str8n-v1.2-topwr-transient-3000.a',
    'PROOFS/str8n-v1.2-record-phase1-proof.asm'
)
$pattern = '\$(?:1A|1B|1C|1D|1E|1F)[0-9A-Fa-f]{2}(?![0-9A-Fa-f])'
$violations = [System.Collections.Generic.List[string]]::new()
foreach ($path in $files) {
    foreach ($match in Select-String -LiteralPath $path -Pattern $pattern) {
        $code = ($match.Line -split ';',2)[0]
        if ($code -notmatch $pattern) { continue }
        if ($code -match 'ASM_LOW_TABLE_END' -or $code -match 'USER FREE') { continue }
        $violations.Add(('{0}:{1}: {2}' -f $path,$match.LineNumber,$match.Line.Trim()))
    }
}
if ($violations.Count) { throw ("v1.2 active source allocates user low RAM:`n" + ($violations -join "`n")) }
Write-Host 'V1.2 RAM ABI CHECK = PASS; $1A00-$1FFF is user-free'
