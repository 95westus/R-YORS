param(
    [string]$Query = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$rows = @(
    [pscustomobject]@{ Target = "all"; Category = "build"; Description = "Build the main tracked and local target set." }
    [pscustomobject]@{ Target = "release"; Category = "release"; Description = "Build docs plus tracked release artifacts: HIMON, fnv1a-hbstr, test-flash, rom-append-calc." }
    [pscustomobject]@{ Target = "release-local"; Category = "release"; Description = "Build release plus local/private ROM composites." }
    [pscustomobject]@{ Target = "himon"; Category = "monitor"; Description = "Build current HIMON app S19 and ROM binary." }
    [pscustomobject]@{ Target = "himon-rom"; Category = "monitor"; Description = "Build HIMON linked at ROM address D000." }
    [pscustomobject]@{ Target = "himon-rom-bin"; Category = "monitor"; Description = "Build 32K HIMON ROM image: BUILD/bin/himon-rom.bin." }
    [pscustomobject]@{ Target = "basic-himon-rom-bin"; Category = "rom"; Description = "Build BASIC plus HIMON 32K ROM image." }
    [pscustomobject]@{ Target = "basic-forth-himon-rom-bin"; Category = "rom"; Description = "Build BASIC plus FORTH plus HIMON 32K ROM image." }
    [pscustomobject]@{ Target = "himonia"; Category = "reference"; Description = "Build historical compact Himonia monitor reference." }
    [pscustomobject]@{ Target = "himonia-rom"; Category = "reference"; Description = "Build Himonia reference linked at ROM address D000." }
    [pscustomobject]@{ Target = "himonia-rom-bin"; Category = "reference"; Description = "Build 32K Himonia reference ROM image." }
    [pscustomobject]@{ Target = "fnv1a-hbstr"; Category = "test"; Description = "Build FNV-1a/HBSTR proving app." }
    [pscustomobject]@{ Target = "test-flash"; Category = "test"; Description = "Build flash command/install proving app." }
    [pscustomobject]@{ Target = "test-mon"; Category = "test"; Description = "Build monitor test app." }
    [pscustomobject]@{ Target = "test-ftdi-drv"; Category = "test"; Description = "Build FTDI driver test app." }
    [pscustomobject]@{ Target = "test-ftdi-hal"; Category = "test"; Description = "Build FTDI HAL test app." }
    [pscustomobject]@{ Target = "life"; Category = "app"; Description = "Build Conway Life app." }
    [pscustomobject]@{ Target = "microchess"; Category = "app"; Description = "Build MicroChess at A900." }
    [pscustomobject]@{ Target = "rom-append-calc"; Category = "app"; Description = "Build CALC command as a ROM append proof at 9A00." }
    [pscustomobject]@{ Target = "fig-forth"; Category = "local"; Description = "Generate and build local fig-Forth S19." }
    [pscustomobject]@{ Target = "fig-forth-src"; Category = "local"; Description = "Generate local WDC-flavored fig-Forth source." }
    [pscustomobject]@{ Target = "msbasic-osi"; Category = "local"; Description = "Generate/build local OSI MS BASIC S19 and binary." }
    [pscustomobject]@{ Target = "msbasic-osi-src"; Category = "local"; Description = "Generate local WDC-flavored OSI MS BASIC source." }
    [pscustomobject]@{ Target = "msbasic-osi-bin"; Category = "local"; Description = "Build local OSI MS BASIC binary." }
    [pscustomobject]@{ Target = "msbasic-osi-ram"; Category = "local"; Description = "Build local OSI MS BASIC RAM-loadable S19." }
    [pscustomobject]@{ Target = "local-homes"; Category = "local"; Description = "Create ignored LOCAL source homes and provenance files." }
    [pscustomobject]@{ Target = "rom"; Category = "library"; Description = "Build shared ROM routine library." }
    [pscustomobject]@{ Target = "testing"; Category = "library"; Description = "Build shared testing support library." }
    [pscustomobject]@{ Target = "docs"; Category = "docs"; Description = "Regenerate source-derived docs." }
    [pscustomobject]@{ Target = "docs-watch"; Category = "docs"; Description = "Watch source and regenerate source-derived docs." }
    [pscustomobject]@{ Target = "call-order"; Category = "docs"; Description = "Regenerate DOC/GENERATED/CALL_ORDER.md." }
    [pscustomobject]@{ Target = "routine-contracts"; Category = "docs"; Description = "Regenerate DOC/GENERATED/ROUTINE_CONTRACTS.md." }
    [pscustomobject]@{ Target = "routine-tree"; Category = "docs"; Description = "Regenerate DOC/GENERATED/ROUTINE_TREE.md." }
    [pscustomobject]@{ Target = "routine-class-diagram"; Category = "docs"; Description = "Regenerate DOC/GENERATED/ROUTINE_CLASS_DIAGRAM.md." }
    [pscustomobject]@{ Target = "routine-graph-insights"; Category = "docs"; Description = "Regenerate DOC/GENERATED/ROUTINE_GRAPH_INSIGHTS.md." }
    [pscustomobject]@{ Target = "routine-components"; Category = "docs"; Description = "Regenerate DOC/GENERATED/ROUTINE_COMPONENTS.md." }
    [pscustomobject]@{ Target = "routine-hash-comments"; Category = "docs"; Description = "Refresh generated routine hash comments in ASM files." }
    [pscustomobject]@{ Target = "artifacts"; Category = "housekeeping"; Description = "Move sidecar artifacts into BUILD/{lst,sym,map,bin,s19}." }
    [pscustomobject]@{ Target = "clean"; Category = "housekeeping"; Description = "Remove generated app-side files and BUILD." }
    [pscustomobject]@{ Target = "realclean"; Category = "housekeeping"; Description = "Clean plus root temporary linker artifacts." }
    [pscustomobject]@{ Target = "upload"; Category = "external"; Description = "Run UPLOADER command if provided." }
    [pscustomobject]@{ Target = "term"; Category = "external"; Description = "Run TERMINAL command if provided." }
)

if (-not [string]::IsNullOrWhiteSpace($Query)) {
    $needle = [Regex]::Escape($Query)
    $rows = $rows | Where-Object {
        $_.Target -match $needle -or
        $_.Category -match $needle -or
        $_.Description -match $needle
    }
}

Write-Host "make targets"
Write-Host "usage: make help"
Write-Host "       make help Q=flash"
Write-Host ""

if (($rows | Measure-Object).Count -eq 0) {
    Write-Host "No targets matched '$Query'."
    exit 0
}

$rows |
    Sort-Object Category, Target |
    Format-Table -AutoSize Target, Category, Description
