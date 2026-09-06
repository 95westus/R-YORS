param([string]$Python = 'python')
$ErrorActionPreference = 'Stop'

function Run([string]$Exe, [string[]]$Arguments) {
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Exe exited $LASTEXITCODE" }
}

# The resident artifact is always checked first. The optional CHECK worker
# already exceeds the contiguous resident budget; test it in a separate host
# layout (CODE $8000, DATA $7080), never as an installable board image.
Run $Python @('-B', 'tools/check_asm_errors.py')
$fixture = 'BUILD/tmp/asm-errors-check'
New-Item -ItemType Directory -Force -Path $fixture | Out-Null
Copy-Item -LiteralPath 'ASM/asm-v1-flash.asm' -Destination "$fixture/wrapper.asm"
Copy-Item -LiteralPath 'ASM/asm-v1-core.asm' -Destination "$fixture/core.asm"
Run 'wdc02as' @('-G', '-L', '-S', '-W', '-I', 'BUILD', '-I', 'BUILD/inc',
    '-DASM_PACKAGE_CHECK_ENABLED', "$fixture/wrapper.asm")
Run 'wdc02as' @('-G', '-L', '-S', '-W', '-I', 'BUILD', '-I', 'BUILD/inc',
    '-DASM_RUNTIME_ONLY', '-DASM_FLASH_RUNTIME', '-DASM_PACKAGE_ENABLED',
    '-DASM_PACKAGE_CHECK_ENABLED', "$fixture/core.asm")
Run 'wdcln' @('-g', '-s', '-t', '-c8000', '-d7080', '-u5000', '-hm19', '-j',
    '-o', "$fixture/optional.s19", "$fixture/wrapper.obj", "$fixture/core.obj")
Run 'powershell' @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
    'tools/check_asm_flash_map.ps1', '-MapPath', "$fixture/optional.map")
Run $Python @('-B', 'tools/check_asm_errors.py', '--asm-image', "$fixture/optional.s19")
