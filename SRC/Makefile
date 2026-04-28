ASM := wdc02as
LIB := wdclib
LINKER := wdcln
ASFLAGS = -G -L -S -W -I $(BUILD_DIR) -I $(INC_DIR)
LINKFLAGS := -g -s -t -c1000 -hm19 -j -o
TEST_LINKFLAGS := -g -s -t -c2000 -hm19 -j -o
STASH_DIR := STASH
CORE_DIR := SESH
TEST_ROOT_DIR := TEST
APPS_DIR := $(TEST_ROOT_DIR)/apps
TEST_SUPPORT_DIR := $(TEST_ROOT_DIR)/support
LIB_SUBDIRS := $(STASH_DIR)/ftdi $(CORE_DIR)/ftdi $(TEST_ROOT_DIR)/ftdi $(TEST_ROOT_DIR)/util $(TEST_ROOT_DIR)/dev $(TEST_ROOT_DIR)/acia $(TEST_ROOT_DIR)/pia
BUILD_DIR := BUILD
OBJ_DIR := $(BUILD_DIR)/obj
INC_DIR := $(BUILD_DIR)/inc
LST_DIR := $(BUILD_DIR)/lst
SYM_DIR := $(BUILD_DIR)/sym
MAP_DIR := $(BUILD_DIR)/map
BIN_DIR := $(BUILD_DIR)/bin
S19_DIR := $(BUILD_DIR)/s19

# Module map:
# - rom.lib is built from:
#   - STASH/ftdi
#   - SESH/ftdi
#   - TEST/{ftdi,util,dev,acia,pia}

HIM_SUBDIR := $(APPS_DIR)/himon
HIM_SRC := $(HIM_SUBDIR)/himon.asm
HIM_OBJ := $(OBJ_DIR)/$(HIM_SUBDIR)/himon.obj
MON_SRC := $(HIM_SUBDIR)/mon.asm
MON_OBJ := $(OBJ_DIR)/$(HIM_SUBDIR)/mon.obj
HIM_S19 := $(S19_DIR)/himon.s19
HIM_LINKFLAGS := -g -s -t -c6000 -hm19 -j -o
HIM_ROM_S19 := $(S19_DIR)/himon-rom.s19
HIM_ROM_LINKFLAGS := -g -s -t -c8000 -hm19 -j -o
HIM_ROM_BIN := $(BIN_DIR)/himon.bin
HIMONIA_SRC := $(HIM_SUBDIR)/himonia.asm
HIMONIA_OBJ := $(OBJ_DIR)/$(HIM_SUBDIR)/himonia.obj
HIMONIA_S19 := $(S19_DIR)/himonia.s19
HIMONIA_LINKFLAGS := -g -s -t -c6000 -hm19 -j -o
HIMONIA_ROM_S19 := $(S19_DIR)/himonia-rom.s19
HIMONIA_ROM_LINKFLAGS := -g -s -t -c8000 -hm19 -j -o
HIMONIA_ROM_BIN := $(BIN_DIR)/himonia.bin
HIMONIA_F_SRC := $(HIM_SUBDIR)/himonia-f.asm
HIMONIA_F_OBJ := $(OBJ_DIR)/$(HIM_SUBDIR)/himonia-f.obj
HIMONIA_F_S19 := $(S19_DIR)/himonia-f.s19
HIMONIA_F_LINKFLAGS := -g -s -t -c6000 -hm19 -j -o
HIMONIA_F_ROM_S19 := $(S19_DIR)/himonia-f-rom.s19
HIMONIA_F_ROM_LINKFLAGS := -g -s -t -c8000 -hm19 -j -o
HIMONIA_F_ROM_BIN := $(BIN_DIR)/himonia-f.bin
FNV1A_HBSTR_SRC := $(HIM_SUBDIR)/fnv1a-hbstr.asm
FNV1A_HBSTR_OBJ := $(OBJ_DIR)/$(HIM_SUBDIR)/fnv1a-hbstr.obj
FNV1A_HBSTR_S19 := $(S19_DIR)/fnv1a-hbstr.s19
FNV1A_HBSTR_LINKFLAGS := -g -s -t -c6000 -hm19 -j -o
TMON_SRC := $(TEST_ROOT_DIR)/test-mon.asm
TMON_OBJ := $(OBJ_DIR)/$(TEST_ROOT_DIR)/test-mon.obj
TMON_S19 := $(S19_DIR)/test-mon.s19
TFTDI_SRC := $(TEST_ROOT_DIR)/test-ftdi-drv.asm
TFTDI_OBJ := $(OBJ_DIR)/$(TEST_ROOT_DIR)/test-ftdi-drv.obj
TFTDI_S19 := $(S19_DIR)/test-ftdi-drv.s19
TFHAL_SRC := $(TEST_ROOT_DIR)/test-ftdi-hal.asm
TFHAL_OBJ := $(OBJ_DIR)/$(TEST_ROOT_DIR)/test-ftdi-hal.obj
TFHAL_S19 := $(S19_DIR)/test-ftdi-hal.s19
LIFE_SRC := $(APPS_DIR)/life.asm
LIFE_OBJ := $(OBJ_DIR)/$(APPS_DIR)/life.obj
LIFE_S19 := $(S19_DIR)/life.s19
FTDI_DRV_SRC := $(STASH_DIR)/ftdi/ftdi-drv.asm
FTDI_DRV_INC := $(STASH_DIR)/ftdi/ftdi-drv.inc

ROM_EXTRA_SRC := $(wildcard $(TEST_ROOT_DIR)/ftdi-backend-debug.asm)
ROM_SRC := $(foreach d,$(LIB_SUBDIRS),$(wildcard $(d)/*.asm)) $(ROM_EXTRA_SRC)
APP_SRC := $(wildcard $(STASH_DIR)/*.asm) $(wildcard $(CORE_DIR)/*.asm) $(wildcard $(TEST_ROOT_DIR)/*.asm) $(wildcard $(APPS_DIR)/*.asm) $(wildcard $(HIM_SUBDIR)/*.asm) $(wildcard $(TEST_SUPPORT_DIR)/*.asm) $(wildcard $(TEST_ROOT_DIR)/ftdi/*.asm) $(wildcard $(TEST_ROOT_DIR)/dev/*.asm) $(wildcard $(TEST_ROOT_DIR)/acia/*.asm) $(wildcard $(TEST_ROOT_DIR)/pia/*.asm) $(wildcard $(TEST_ROOT_DIR)/util/*.asm)
ROM_OBJ := $(addprefix $(OBJ_DIR)/,$(ROM_SRC:.asm=.obj))
ROM_LIB := $(BUILD_DIR)\lib\rom.lib
TEST_LIB_SRC := $(wildcard $(TEST_SUPPORT_DIR)/*.asm)
TEST_LIB_OBJ := $(addprefix $(OBJ_DIR)/,$(TEST_LIB_SRC:.asm=.obj))
TEST_LIB := $(BUILD_DIR)\lib\testing.lib
CALL_ORDER := CALL_ORDER.md
CALL_ORDER_SRC := $(ROM_SRC) $(APP_SRC)
CALL_ORDER_GEN := tools/gen_call_order.ps1
ROUTINE_CONTRACTS := ROUTINE_CONTRACTS.md
ROUTINE_CONTRACTS_GEN := tools/gen_routine_contracts.ps1
ROUTINE_TREE := ROUTINE_TREE.md
ROUTINE_TREE_GEN := tools/gen_routine_tree.ps1
ROUTINE_CLASS_DIAGRAM := ROUTINE_CLASS_DIAGRAM.md
ROUTINE_CLASS_DIAGRAM_GEN := tools/gen_routine_class_diagram.ps1
ROUTINE_GRAPH_INSIGHTS := ROUTINE_GRAPH_INSIGHTS.md
ROUTINE_GRAPH_INSIGHTS_GEN := tools/gen_routine_graph_insights.ps1
ROUTINE_COMPONENTS := ROUTINE_COMPONENTS.md
ROUTINE_COMPONENTS_GEN := tools/gen_routine_components.ps1
ROUTINE_HASH_COMMENTS_GEN := tools/gen_routine_hash_comments.ps1
DOCS_GEN := tools/gen_docs.ps1
DOCS_WATCH := tools/watch_docs.ps1
CALL_MAP := ../DOC/GUIDES/CALL_MAP.md
CALL_MAP_OUT := DOC/GUIDES/CALL_MAP.md
CALL_MAP_GEN := tools/gen_call_map.ps1

# Optional local commands (override from CLI, e.g. make upload UPLOADER="tool --flash")
TERMINAL ?=
UPLOADER ?=

all: test-ftdi-drv himon

himon: $(ROM_LIB) $(HIM_S19) himon-rom-bin
	@echo "Built $(HIM_S19)."
	@$(MAKE) artifacts

himon-rom: $(ROM_LIB) $(HIM_ROM_S19)
	@echo "Built $(HIM_ROM_S19)."
	@$(MAKE) artifacts

himon-rom-bin: himon-rom
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_himon_rom_bin.ps1 -MapPath "$(MAP_DIR)/himon-rom.map" -S19Path "$(S19_DIR)/himon-rom.s19" -BinPath "$(HIM_ROM_BIN)" -TmpVecPath "$(BUILD_DIR)/tmp/himon-rom-vectors.bin" -NmiSymbol "SYS_VEC_ENTRY_NMI" -IrqSymbol "SYS_VEC_ENTRY_IRQ_MASTER" -ResetSymbol "START"
	powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(BIN_DIR)/himon-rom-vectors.bin') { Remove-Item -LiteralPath '$(BIN_DIR)/himon-rom-vectors.bin' -Force }"
	@echo "Built $(HIM_ROM_BIN)."

himonia: $(ROM_LIB) $(HIMONIA_S19) himonia-rom-bin
	@echo "Built $(HIMONIA_S19)."
	@$(MAKE) artifacts

himonia-rom: $(ROM_LIB) $(HIMONIA_ROM_S19)
	@echo "Built $(HIMONIA_ROM_S19)."
	@$(MAKE) artifacts

himonia-rom-bin: himonia-rom
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_himon_rom_bin.ps1 -MapPath "$(MAP_DIR)/himonia-rom.map" -S19Path "$(S19_DIR)/himonia-rom.s19" -BinPath "$(HIMONIA_ROM_BIN)" -TmpVecPath "$(BUILD_DIR)/tmp/himonia-rom-vectors.bin" -NmiSymbol "SYS_VEC_ENTRY_NMI" -IrqSymbol "SYS_VEC_ENTRY_IRQ_MASTER" -ResetSymbol "START"
	powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(BIN_DIR)/himonia-rom-vectors.bin') { Remove-Item -LiteralPath '$(BIN_DIR)/himonia-rom-vectors.bin' -Force }"
	@echo "Built $(HIMONIA_ROM_BIN)."

himonia-f: $(ROM_LIB) $(HIMONIA_F_S19) himonia-f-rom-bin
	@echo "Built $(HIMONIA_F_S19)."
	@$(MAKE) artifacts

himonia-f-rom: $(ROM_LIB) $(HIMONIA_F_ROM_S19)
	@echo "Built $(HIMONIA_F_ROM_S19)."
	@$(MAKE) artifacts

himonia-f-rom-bin: himonia-f-rom
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_himon_rom_bin.ps1 -MapPath "$(MAP_DIR)/himonia-f-rom.map" -S19Path "$(S19_DIR)/himonia-f-rom.s19" -BinPath "$(HIMONIA_F_ROM_BIN)" -TmpVecPath "$(BUILD_DIR)/tmp/himonia-f-rom-vectors.bin" -NmiSymbol "SYS_VEC_ENTRY_NMI" -IrqSymbol "SYS_VEC_ENTRY_IRQ_MASTER" -ResetSymbol "START"
	powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(BIN_DIR)/himonia-f-rom-vectors.bin') { Remove-Item -LiteralPath '$(BIN_DIR)/himonia-f-rom-vectors.bin' -Force }"
	@echo "Built $(HIMONIA_F_ROM_BIN)."

fnv1a-hbstr: $(ROM_LIB) $(FNV1A_HBSTR_S19)
	@echo "Built $(FNV1A_HBSTR_S19)."

test-mon: $(ROM_LIB) $(TEST_LIB) $(TMON_S19)
	@echo "Built $(TMON_S19)."
	@$(MAKE) artifacts

test-ftdi-drv: $(ROM_LIB) $(TEST_LIB) $(TFTDI_S19)
	@echo "Built $(TFTDI_S19)."
	@$(MAKE) artifacts

test-ftdi-gauntlet: test-ftdi-drv
	@echo "Alias: FTDI Driver Gauntlet -> test-ftdi-drv."

test-ftdi-hal: $(ROM_LIB) $(TEST_LIB) $(TFHAL_S19)
	@echo "Built $(TFHAL_S19)."
	@$(MAKE) artifacts

life: $(ROM_LIB) $(LIFE_S19)
	@echo "Built $(LIFE_S19)."
	@$(MAKE) artifacts

test-ftdi-init: test-ftdi-drv
	@echo "Alias: use 'make test-ftdi-drv'."

call-order: $(CALL_ORDER)
	@echo "Updated $(CALL_ORDER)."

call-map: $(CALL_MAP)
	@echo "Updated $(CALL_MAP_OUT)."

routine-contracts: $(ROUTINE_CONTRACTS)
	@echo "Updated $(ROUTINE_CONTRACTS)."

routine-tree: $(ROUTINE_TREE)
	@echo "Updated $(ROUTINE_TREE)."

routine-class-diagram: $(ROUTINE_CLASS_DIAGRAM)
	@echo "Updated $(ROUTINE_CLASS_DIAGRAM)."

routine-graph-insights: $(ROUTINE_GRAPH_INSIGHTS)
	@echo "Updated $(ROUTINE_GRAPH_INSIGHTS)."

routine-components: $(ROUTINE_COMPONENTS)
	@echo "Updated $(ROUTINE_COMPONENTS)."

routine-hash-comments: $(ROUTINE_HASH_COMMENTS_GEN) $(CALL_ORDER_SRC)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(ROUTINE_HASH_COMMENTS_GEN) -Src .
	@echo "Updated routine HASH comments in .asm files."

docs: $(CALL_ORDER) $(ROUTINE_CONTRACTS) $(ROUTINE_TREE) $(ROUTINE_CLASS_DIAGRAM) $(ROUTINE_GRAPH_INSIGHTS) $(ROUTINE_COMPONENTS)
	@echo "Updated docs: $(CALL_ORDER), $(ROUTINE_CONTRACTS), $(ROUTINE_TREE), $(ROUTINE_CLASS_DIAGRAM), $(ROUTINE_GRAPH_INSIGHTS), $(ROUTINE_COMPONENTS)."

docs-watch:
	powershell -NoProfile -ExecutionPolicy Bypass -File $(DOCS_WATCH) -Src .

# Build shared module library independently.
rom: $(ROM_LIB)
	@echo "Built $(ROM_LIB)."
	@$(MAKE) artifacts

rom-auto:
	$(MAKE) rom

rom-ftdi:
	$(MAKE) rom

rom-acia:
	$(MAKE) rom

testing: $(TEST_LIB)
	@echo "Built $(TEST_LIB)."

$(HIM_S19): $(HIM_OBJ) $(MON_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIM_LINKFLAGS) $(HIM_S19) $(HIM_OBJ) $(MON_OBJ) -L $(BUILD_DIR)\lib\rom

$(HIM_ROM_S19): $(HIM_OBJ) $(MON_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIM_ROM_LINKFLAGS) $(HIM_ROM_S19) $(HIM_OBJ) $(MON_OBJ) -L $(BUILD_DIR)\lib\rom

$(HIMONIA_S19): $(HIMONIA_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMONIA_LINKFLAGS) $(HIMONIA_S19) $(HIMONIA_OBJ) -L $(BUILD_DIR)\lib\rom

$(HIMONIA_ROM_S19): $(HIMONIA_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMONIA_ROM_LINKFLAGS) $(HIMONIA_ROM_S19) $(HIMONIA_OBJ) -L $(BUILD_DIR)\lib\rom

$(HIMONIA_F_S19): $(HIMONIA_F_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMONIA_F_LINKFLAGS) $(HIMONIA_F_S19) $(HIMONIA_F_OBJ) -L $(BUILD_DIR)\lib\rom

$(HIMONIA_F_ROM_S19): $(HIMONIA_F_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMONIA_F_ROM_LINKFLAGS) $(HIMONIA_F_ROM_S19) $(HIMONIA_F_OBJ) -L $(BUILD_DIR)\lib\rom

$(FNV1A_HBSTR_S19): $(FNV1A_HBSTR_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(FNV1A_HBSTR_LINKFLAGS) $(FNV1A_HBSTR_S19) $(FNV1A_HBSTR_OBJ) -L $(BUILD_DIR)\lib\rom

$(TMON_S19): $(TMON_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(TEST_LINKFLAGS) $(TMON_S19) $(TMON_OBJ) -L $(BUILD_DIR)\lib\rom -L $(BUILD_DIR)\lib\testing

$(TFTDI_S19): $(TFTDI_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(TEST_LINKFLAGS) $(TFTDI_S19) $(TFTDI_OBJ) -L $(BUILD_DIR)\lib\rom -L $(BUILD_DIR)\lib\testing

$(TFHAL_S19): $(TFHAL_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(TEST_LINKFLAGS) $(TFHAL_S19) $(TFHAL_OBJ) -L $(BUILD_DIR)\lib\rom -L $(BUILD_DIR)\lib\testing

$(LIFE_S19): $(LIFE_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(TEST_LINKFLAGS) $(LIFE_S19) $(LIFE_OBJ) -L $(BUILD_DIR)\lib\rom
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(LIFE_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9032000DC'; Set-Content -Path $$p -Value $$lines"

$(FTDI_DRV_INC): $(FTDI_DRV_SRC)
	@if not exist $(subst /,\,$(dir $(FTDI_DRV_INC))) mkdir $(subst /,\,$(dir $(FTDI_DRV_INC)))
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$src = '$(FTDI_DRV_SRC)'; $$dst = '$(FTDI_DRV_INC)'; $$defs = Select-String -Path $$src -Pattern '^\s*XDEF\s+PIN_FTDI_[A-Z0-9_]+' | ForEach-Object { [Regex]::Match($$_.Line, 'PIN_FTDI_[A-Z0-9_]+').Value } | Select-Object -Unique; $$lines = @('; -------------------------------------------------------------------------','; ftdi-drv.inc','; Public include interface for FTDI L0 driver entry points.','; AUTO-GENERATED by Makefile from STASH/ftdi/ftdi-drv.asm.','; -------------------------------------------------------------------------','') + ($$defs | ForEach-Object { ('                        XREF            ' + $$_) }); Set-Content -Path $$dst -Value $$lines"

$(TFTDI_OBJ): $(FTDI_DRV_INC)

$(ROM_LIB): $(ROM_OBJ)
	@if not exist $(subst /,\,$(BUILD_DIR)\lib) mkdir $(subst /,\,$(BUILD_DIR)\lib)
	@if exist $(ROM_LIB) del /f $(ROM_LIB)
	$(LIB) -A $(ROM_LIB) $(ROM_OBJ)
	@if exist LIB.TMP move /Y LIB.TMP $(ROM_LIB)

$(TEST_LIB): $(TEST_LIB_OBJ)
	@if not exist $(subst /,\,$(BUILD_DIR)\lib) mkdir $(subst /,\,$(BUILD_DIR)\lib)
	@if exist $(TEST_LIB) del /f $(TEST_LIB)
	$(LIB) -A $(TEST_LIB) $(TEST_LIB_OBJ)
	@if exist LIB.TMP move /Y LIB.TMP $(TEST_LIB)

$(OBJ_DIR)/%.obj: %.asm
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	@if exist $(subst /,\,$*.obj) move /Y $(subst /,\,$*.obj) $(subst /,\,$@)

$(CALL_ORDER): $(CALL_ORDER_SRC) $(CALL_ORDER_GEN)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(CALL_ORDER_GEN) -Src . -Out $(CALL_ORDER)

$(CALL_MAP): $(CALL_ORDER_SRC) $(CALL_MAP_GEN)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(CALL_MAP_GEN) -Src .. -Out $(CALL_MAP_OUT)

$(ROUTINE_CONTRACTS): $(CALL_ORDER_SRC) $(ROUTINE_CONTRACTS_GEN)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(ROUTINE_CONTRACTS_GEN) -Src . -Out $(ROUTINE_CONTRACTS)

$(ROUTINE_TREE): $(CALL_ORDER_SRC) $(ROUTINE_TREE_GEN)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(ROUTINE_TREE_GEN) -Src . -Out $(ROUTINE_TREE)

$(ROUTINE_CLASS_DIAGRAM): $(CALL_ORDER_SRC) $(ROUTINE_CLASS_DIAGRAM_GEN)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(ROUTINE_CLASS_DIAGRAM_GEN) -Src . -Out $(ROUTINE_CLASS_DIAGRAM)

$(ROUTINE_GRAPH_INSIGHTS): $(CALL_ORDER_SRC) $(ROUTINE_GRAPH_INSIGHTS_GEN)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(ROUTINE_GRAPH_INSIGHTS_GEN) -Src . -Out $(ROUTINE_GRAPH_INSIGHTS)

$(ROUTINE_COMPONENTS): $(CALL_ORDER_SRC) $(ROUTINE_COMPONENTS_GEN)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(ROUTINE_COMPONENTS_GEN) -Src . -Out $(ROUTINE_COMPONENTS)

artifacts:
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$pairs = @(@{Ext='lst';Dir='$(LST_DIR)'},@{Ext='sym';Dir='$(SYM_DIR)'},@{Ext='map';Dir='$(MAP_DIR)'},@{Ext='bin';Dir='$(BIN_DIR)'},@{Ext='s19';Dir='$(S19_DIR)'}); foreach ($$p in $$pairs) { New-Item -ItemType Directory -Force -Path $$p.Dir | Out-Null }; foreach ($$p in $$pairs) { $$src = @('$(APP_DIR)'); if ($$p.Ext -ne 's19') { $$src += '$(S19_DIR)' }; $$dst = (Resolve-Path $$p.Dir).Path; Get-ChildItem -Recurse -File -Path $$src -Filter ('*.' + $$p.Ext) | Where-Object { $$_.DirectoryName -ne $$dst } | ForEach-Object { Move-Item -LiteralPath $$_.FullName -Destination (Join-Path $$p.Dir $$_.Name) -Force }; Get-ChildItem -File -Path . -Filter ('*.' + $$p.Ext) | ForEach-Object { Move-Item -LiteralPath $$_.FullName -Destination (Join-Path $$p.Dir $$_.Name) -Force } }"
	@echo "Moved sidecar artifacts into $(BUILD_DIR)/{lst,sym,map,bin,s19}."

clean:
	-del /f *.obj *.lst *.sym *.map *.bin >nul 2>nul
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Recurse -File -Path '$(APP_DIR)' -Include *.obj,*.lst,*.sym,*.map,*.bin | Remove-Item -Force -ErrorAction SilentlyContinue"
	@if exist $(BUILD_DIR) rmdir /s /q $(BUILD_DIR)
	@rem keep generated artifacts under BUILD between normal builds

realclean: clean
	-del /f *.lib *.s19 LIB.TMP >nul 2>nul

upload:
ifeq ($(strip $(UPLOADER)),)
	@echo "Set UPLOADER and rerun, e.g. make upload UPLOADER=\"your_uploader_command $(TFTDI_S19)\""
else
	$(UPLOADER)
endif

term:
ifeq ($(strip $(TERMINAL)),)
	@echo "Set TERMINAL and rerun, e.g. make term TERMINAL=\"your_terminal_tool $(TFTDI_S19)\""
else
	$(TERMINAL)
endif

.PHONY: all himon himon-rom himon-rom-bin himonia himonia-rom himonia-rom-bin himonia-f himonia-f-rom himonia-f-rom-bin fnv1a-hbstr test-mon test-ftdi-drv test-ftdi-gauntlet test-ftdi-hal life test-ftdi-init call-order call-map routine-contracts routine-tree routine-class-diagram routine-graph-insights routine-components routine-hash-comments docs docs-watch rom rom-auto rom-ftdi rom-acia testing artifacts clean realclean upload term
