param(
    [string]$Query = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$rows = @(
    [pscustomobject]@{ Target = "all"; Category = "build"; Description = "Build the main tracked and local target set." }
    [pscustomobject]@{ Target = "help"; Category = "build"; Description = "Show this target list. Filter with Q=term, e.g. make help Q=flash." }
    [pscustomobject]@{ Target = "release"; Category = "release"; Description = "Build docs plus tracked release artifacts: HIMON, fnv1a-hbstr, test-flash, rom-append-calc." }
    [pscustomobject]@{ Target = "release-local"; Category = "release"; Description = "Build release plus local/private ROM composites." }
    [pscustomobject]@{ Target = "himon"; Category = "monitor"; Description = "Build current HIMON app S19 and ROM binary." }
    [pscustomobject]@{ Target = "himon-rom"; Category = "monitor"; Description = "Build HIMON linked at ROM address C000." }
    [pscustomobject]@{ Target = "himon-rom-bin"; Category = "monitor"; Description = "Build 32K 8000-FFFF bank image with HIMON at C000: BUILD/bin/himon-rom.bin." }
    [pscustomobject]@{ Target = "himon-str8-rom-bin"; Category = "monitor"; Description = "Build 32K bank image with HIMON at C000, STR8 at F000, RESET=F000: BUILD/bin/himon-str8-rom.bin." }
    [pscustomobject]@{ Target = "himon-rom-install-s19"; Category = "monitor"; Description = "Convert HIMON ROM BIN to S1/S9 install transport: BUILD/s19/himon-rom-install.s19." }
    [pscustomobject]@{ Target = "himon-str8-rom-install-s19"; Category = "monitor"; Description = "Convert primary HIMON+STR8 ROM BIN to S1/S9 install transport: BUILD/s19/himon-str8-rom-install.s19." }
    [pscustomobject]@{ Target = "himon-str8-himon-update-s19"; Category = "monitor"; Description = "Build C000-EFFF S1/S9 stream for STR8 U / UPDATE HIMON: BUILD/s19/himon-str8-himon-update.s19." }
    [pscustomobject]@{ Target = "rom-install-s19"; Category = "monitor"; Description = "Alias for himon-str8-rom-install-s19." }
    [pscustomobject]@{ Target = "himon-load"; Category = "monitor"; Description = "Build HIMON loadable S19 linked at C000." }
    [pscustomobject]@{ Target = "himon-load-bin"; Category = "monitor"; Description = "Build HIMON loadable binary image from the HIMON load S19." }
    [pscustomobject]@{ Target = "basic-himon-rom-bin"; Category = "rom"; Description = "Local composite with BASIC at 8000 and HIMON at C000." }
    [pscustomobject]@{ Target = "basic-forth-himon-rom-bin"; Category = "rom"; Description = "Local composite with BASIC at 8000, fig-Forth at A000, and HIMON at C000." }
    [pscustomobject]@{ Target = "str8"; Category = "test"; Description = "Build STR8 V0 F000 boot image and RAM proof image." }
    [pscustomobject]@{ Target = "str8-ram"; Category = "test"; Description = "Build RAM-launched STR8 bank-select/blank-check/copy/marker proof at 3000." }
    [pscustomobject]@{ Target = "fnv1a-hbstr"; Category = "test"; Description = "Build FNV-1a/HBSTR proving app." }
    [pscustomobject]@{ Target = "test-flash"; Category = "test"; Description = "Build flash command/install proving app." }
    [pscustomobject]@{ Target = "test-mon"; Category = "test"; Description = "Build monitor test app." }
    [pscustomobject]@{ Target = "test-ftdi-drv"; Category = "test"; Description = "Build FTDI driver test app." }
    [pscustomobject]@{ Target = "test-ftdi-hal"; Category = "test"; Description = "Build FTDI HAL test app." }
    [pscustomobject]@{ Target = "himon-search-static-proof"; Category = "test"; Description = "Build standalone static-linked RAM search proof at 3000." }
    [pscustomobject]@{ Target = "himon-search-proof"; Category = "test"; Description = "Build hash-resolved RAM search proof at 3000." }
    [pscustomobject]@{ Target = "himon-search-flash"; Category = "test"; Description = "Build low-flash K=05 S search command S19 at BBA2 for L F." }
    [pscustomobject]@{ Target = "life"; Category = "app"; Description = "Build Conway Life loadable S19/BIN at 2000." }
    [pscustomobject]@{ Target = "calc-9a00-fnv-proof"; Category = "app"; Description = "Build legacy CALC inline FNV scanner proof at 9A00; do not load with rom-append-calc." }
    [pscustomobject]@{ Target = "rom-append-calc"; Category = "app"; Description = "Build CALC command as a ROM append proof at B804." }
    [pscustomobject]@{ Target = "fig-forth"; Category = "local"; Description = "Generate and build local fig-Forth S19 at A000." }
    [pscustomobject]@{ Target = "fig-forth-src"; Category = "local"; Description = "Generate local WDC-flavored fig-Forth source." }
    [pscustomobject]@{ Target = "fig-forth-c000"; Category = "local"; Description = "Generate and build bootable local fig-Forth S19 at C000." }
    [pscustomobject]@{ Target = "fig-forth-str8-update-s19"; Category = "local"; Description = "Build C000-EFFF fig-Forth S1/S9 stream for STR8 U: BUILD/s19/fig-forth-str8-update.s19." }
    [pscustomobject]@{ Target = "msbasic-osi"; Category = "local"; Description = "Generate/build local OSI MS BASIC S19 and 8K binary at 8000." }
    [pscustomobject]@{ Target = "msbasic-osi-src"; Category = "local"; Description = "Generate local WDC-flavored OSI MS BASIC source." }
    [pscustomobject]@{ Target = "msbasic-osi-bin"; Category = "local"; Description = "Build local OSI MS BASIC 8000-9FFF slot binary." }
    [pscustomobject]@{ Target = "msbasic-osi-ram"; Category = "local"; Description = "Build local OSI MS BASIC RAM-loadable S19." }
    [pscustomobject]@{ Target = "msbasic-osi-c000"; Category = "local"; Description = "Generate and build bootable local OSI MS BASIC S19 at C000." }
    [pscustomobject]@{ Target = "msbasic-osi-str8-update-s19"; Category = "local"; Description = "Build C000-EFFF OSI MS BASIC S1/S9 stream for STR8 U: BUILD/s19/msbasic-osi-str8-update.s19." }
    [pscustomobject]@{ Target = "local-homes"; Category = "local"; Description = "Create ignored LOCAL source homes and provenance files." }
    [pscustomobject]@{ Target = "rom"; Category = "library"; Description = "Build shared ROM routine library." }
    [pscustomobject]@{ Target = "testing"; Category = "library"; Description = "Build shared testing support library." }
    [pscustomobject]@{ Target = "docs"; Category = "docs"; Description = "Regenerate source-derived docs." }
    [pscustomobject]@{ Target = "docs-watch"; Category = "docs"; Description = "Watch source and regenerate source-derived docs." }
    [pscustomobject]@{ Target = "call-order"; Category = "docs"; Description = "Regenerate DOC/GENERATED/CALL_ORDER.md." }
    [pscustomobject]@{ Target = "routine-contracts"; Category = "docs"; Description = "Regenerate DOC/GENERATED/ROUTINE_CONTRACTS.md." }
    [pscustomobject]@{ Target = "himon-routine-tree"; Category = "docs"; Description = "Regenerate DOC/GENERATED/HIMON_ROUTINE_TREE.md." }
    [pscustomobject]@{ Target = "routine-tree"; Category = "docs"; Description = "Alias for himon-routine-tree." }
    [pscustomobject]@{ Target = "routine-class-diagram"; Category = "docs"; Description = "Regenerate DOC/GENERATED/ROUTINE_CLASS_DIAGRAM.md." }
    [pscustomobject]@{ Target = "routine-prefix-map"; Category = "docs"; Description = "Regenerate DOC/GENERATED/ROUTINE_PREFIX_MAP.md." }
    [pscustomobject]@{ Target = "himon-support-map"; Category = "docs"; Description = "Regenerate DOC/GENERATED/HIMON_SUPPORT_MAP.md." }
    [pscustomobject]@{ Target = "himon-command-map"; Category = "docs"; Description = "Regenerate DOC/GENERATED/HIMON_COMMAND_MAP.md." }
    [pscustomobject]@{ Target = "hash-routine-map"; Category = "docs"; Description = "Regenerate DOC/GENERATED/HASH_ROUTINE_MAP.md." }
    [pscustomobject]@{ Target = "cmd-flow-map"; Category = "docs"; Description = "Regenerate DOC/GENERATED/CMD_FLOW_MAP.md." }
    [pscustomobject]@{ Target = "stack-depth-map"; Category = "docs"; Description = "Regenerate DOC/GENERATED/STACK_DEPTH_MAP.md for HIMON/STR8 stack high-water paths." }
    [pscustomobject]@{ Target = "interrupt-vector-map"; Category = "docs"; Description = "Regenerate DOC/GENERATED/INTERRUPT_VECTOR_MAP.md for IRQ/NMI/BRK vectors." }
    [pscustomobject]@{ Target = "irq-vector-map"; Category = "docs"; Description = "Alias for interrupt-vector-map." }
    [pscustomobject]@{ Target = "map-of-maps"; Category = "docs"; Description = "Regenerate DOC/GENERATED/MAP_OF_MAPS.md." }
    [pscustomobject]@{ Target = "routine-graph-insights"; Category = "docs"; Description = "Regenerate DOC/GENERATED/ROUTINE_GRAPH_INSIGHTS.md." }
    [pscustomobject]@{ Target = "routine-components"; Category = "docs"; Description = "Regenerate DOC/GENERATED/ROUTINE_COMPONENTS.md." }
    [pscustomobject]@{ Target = "routine-hash-comments"; Category = "docs"; Description = "Refresh generated routine hash comments in ASM files." }
    [pscustomobject]@{ Target = "docs-html"; Category = "docs"; Description = "Generate DOC/HTML static pages from the current Markdown docs snapshot." }
    [pscustomobject]@{ Target = "artifacts"; Category = "housekeeping"; Description = "Move sidecar artifacts into BUILD/{lst,sym,map,bin,s19}." }
    [pscustomobject]@{ Target = "bin-check"; Category = "housekeeping"; Description = "Check generated BIN files for expected ROM image size and reset-vector policy." }
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
