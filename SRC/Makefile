ASM := wdc02as
LIB := wdclib
LINKER := wdcln
ASFLAGS = -G -L -S -W -I $(BUILD_DIR) -I $(INC_DIR)
LINKFLAGS := -g -s -t -c1000 -hm19 -j -o
TEST_LINKFLAGS := -g -s -t -c2000 -hm19 -j -o
TFLASH_LINKFLAGS := -g -s -t -c3000 -hm19 -j -o
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
ROM_BIN_STAMP_DEFAULT := $(shell powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-ddTHH-mm'")
ROM_BIN_STAMP ?= $(ROM_BIN_STAMP_DEFAULT)
ROM_BIN_ARCHIVE_DIR := ROM_IMAGES
PYTHON ?= python

LOCAL_ROOT ?= ../LOCAL
LOCAL_PROVENANCE := tools/write_local_provenance.ps1
BASIC_PROGRAMS_HOME ?= $(LOCAL_ROOT)/basic-programs
FIG_FORTH_HOME ?= $(LOCAL_ROOT)/fig-forth
FIG_FORTH_INPUT ?= $(FIG_FORTH_HOME)/source/ff6502.html
MSBASIC_HOME ?= $(LOCAL_ROOT)/msbasic
MSBASIC_SRC_ROOT ?= $(MSBASIC_HOME)/source
WDCMONV2_HOME ?= $(LOCAL_ROOT)/wdcmonv2
S3X_HOME ?= $(LOCAL_ROOT)/s3x

# Module map:
# - rom.lib is built from:
#   - STASH/ftdi
#   - SESH/ftdi
#   - TEST/{ftdi,util,dev,acia,pia}

HIM_SUBDIR := $(APPS_DIR)/himon
STR8_SUBDIR := $(APPS_DIR)/str8
HIMONIA_SRC := $(HIM_SUBDIR)/himonia.asm
HIMONIA_OBJ := $(OBJ_DIR)/$(HIM_SUBDIR)/himonia.obj
HIMONIA_S19 := $(S19_DIR)/himonia.s19
HIMONIA_LINKFLAGS := -g -s -t -c6000 -hm19 -j -o
HIMONIA_ROM_S19 := $(S19_DIR)/himonia-rom.s19
HIMONIA_ROM_LINKFLAGS := -g -s -t -cD000 -hm19 -j -o
HIMONIA_ROM_BIN := $(BIN_DIR)/himonia.bin
HIMON_SRC := $(HIM_SUBDIR)/himon.asm
HIMON_OBJ := $(OBJ_DIR)/$(HIM_SUBDIR)/himon.obj
HIMON_ROM_OBJ := $(OBJ_DIR)/$(HIM_SUBDIR)/himon-rom.obj
HIMON_S19 := $(S19_DIR)/himon.s19
HIMON_LINKFLAGS := -g -s -t -c6000 -hm19 -j -o
HIMON_ROM_S19 := $(S19_DIR)/himon-rom.s19
HIMON_ROM_LINKFLAGS := -g -s -t -cD000 -hm19 -j -o
HIMON_ROM_BIN := $(BIN_DIR)/himon-rom.bin
BASIC_HIMON_ROM_BIN := $(BIN_DIR)/basic-himon-rom.bin
BASIC_FORTH_HIMON_ROM_BIN := $(BIN_DIR)/basic-forth-himon-rom.bin
FNV1A_HBSTR_SRC := $(HIM_SUBDIR)/fnv1a-hbstr.asm
FNV1A_HBSTR_OBJ := $(OBJ_DIR)/$(HIM_SUBDIR)/fnv1a-hbstr.obj
FNV1A_HBSTR_S19 := $(S19_DIR)/fnv1a-hbstr.s19
FNV1A_HBSTR_LINKFLAGS := -g -s -t -c6000 -hm19 -j -o
STR8_SRC := $(STR8_SUBDIR)/str8.asm
STR8_OBJ := $(OBJ_DIR)/$(STR8_SUBDIR)/str8.obj
STR8_S19 := $(S19_DIR)/str8-f800.s19
STR8_LINKFLAGS := -g -s -t -cF800 -hm19 -j -o
TMON_SRC := $(TEST_ROOT_DIR)/test-mon.asm
TMON_OBJ := $(OBJ_DIR)/$(TEST_ROOT_DIR)/test-mon.obj
TMON_S19 := $(S19_DIR)/test-mon.s19
TFTDI_SRC := $(TEST_ROOT_DIR)/test-ftdi-drv.asm
TFTDI_OBJ := $(OBJ_DIR)/$(TEST_ROOT_DIR)/test-ftdi-drv.obj
TFTDI_S19 := $(S19_DIR)/test-ftdi-drv.s19
TFHAL_SRC := $(TEST_ROOT_DIR)/test-ftdi-hal.asm
TFHAL_OBJ := $(OBJ_DIR)/$(TEST_ROOT_DIR)/test-ftdi-hal.obj
TFHAL_S19 := $(S19_DIR)/test-ftdi-hal.s19
TFLASH_SRC := $(TEST_ROOT_DIR)/test-flash.asm
TFLASH_OBJ := $(OBJ_DIR)/$(TEST_ROOT_DIR)/test-flash.obj
TFLASH_S19 := $(S19_DIR)/test-flash.s19
LIFE_SRC := $(APPS_DIR)/life.asm
LIFE_OBJ := $(OBJ_DIR)/$(APPS_DIR)/life.obj
LIFE_S19 := $(S19_DIR)/life.s19
MICROCHESS_SRC := $(APPS_DIR)/microchess.asm
MICROCHESS_OBJ := $(OBJ_DIR)/$(APPS_DIR)/microchess.obj
MICROCHESS_S19 := $(S19_DIR)/microchess-a900.s19
MICROCHESS_LINKFLAGS := -g -s -t -cA900 -hm19 -j -o
ROM_APPEND_CALC_SRC := $(APPS_DIR)/rom-append-calc.asm
ROM_APPEND_CALC_OBJ := $(OBJ_DIR)/$(APPS_DIR)/rom-append-calc.obj
ROM_APPEND_CALC_S19 := $(S19_DIR)/rom-append-calc-9a00.s19
ROM_APPEND_CALC_LINKFLAGS := -g -s -t -c9A00 -hm19 -j -o
FIG_FORTH_SRC := $(FIG_FORTH_HOME)/generated/fig-forth.asm
FIG_FORTH_OBJ := $(OBJ_DIR)/LOCAL/fig-forth/fig-forth.obj
FIG_FORTH_S19 := $(S19_DIR)/fig-forth-9000.s19
FIG_FORTH_LINKFLAGS := -g -s -t -c9000 -hm19 -j -o
MSBASIC_OSI_GEN := tools/emit_msbasic_osi_wdc.py
# Local-only source/generator home. Nothing under $(LOCAL_ROOT) is tracked.
MSBASIC_OSI_SRC := $(MSBASIC_HOME)/generated/osi-basic.asm
MSBASIC_OSI_OBJ := $(OBJ_DIR)/LOCAL/msbasic/osi-basic.obj
MSBASIC_OSI_S19 := $(S19_DIR)/msbasic-osi.s19
MSBASIC_OSI_LINKFLAGS := -g -s -t -cB000 -hm19 -j -o
MSBASIC_OSI_BIN := $(BIN_DIR)/msbasic-osi-fnv-b000-8k.bin
MSBASIC_OSI_RAM_S19 := $(S19_DIR)/msbasic-osi-ram.s19
MSBASIC_OSI_RAM_LINKFLAGS := -g -s -t -c4000 -hm19 -j -o
FTDI_DRV_SRC := $(STASH_DIR)/ftdi/ftdi-drv.asm
FTDI_DRV_INC := $(STASH_DIR)/ftdi/ftdi-drv.inc

ROM_EXTRA_SRC := $(wildcard $(TEST_ROOT_DIR)/ftdi-backend-debug.asm)
ROM_SRC := $(foreach d,$(LIB_SUBDIRS),$(wildcard $(d)/*.asm)) $(ROM_EXTRA_SRC)
APP_SRC := $(wildcard $(STASH_DIR)/*.asm) $(wildcard $(CORE_DIR)/*.asm) $(wildcard $(TEST_ROOT_DIR)/*.asm) $(wildcard $(APPS_DIR)/*.asm) $(wildcard $(HIM_SUBDIR)/*.asm) $(wildcard $(STR8_SUBDIR)/*.asm) $(wildcard $(TEST_SUPPORT_DIR)/*.asm) $(wildcard $(TEST_ROOT_DIR)/ftdi/*.asm) $(wildcard $(TEST_ROOT_DIR)/dev/*.asm) $(wildcard $(TEST_ROOT_DIR)/acia/*.asm) $(wildcard $(TEST_ROOT_DIR)/pia/*.asm) $(wildcard $(TEST_ROOT_DIR)/util/*.asm)
ROM_OBJ := $(addprefix $(OBJ_DIR)/,$(ROM_SRC:.asm=.obj))
ROM_LIB := $(BUILD_DIR)\lib\rom.lib
TEST_LIB_SRC := $(wildcard $(TEST_SUPPORT_DIR)/*.asm)
TEST_LIB_OBJ := $(addprefix $(OBJ_DIR)/,$(TEST_LIB_SRC:.asm=.obj))
TEST_LIB := $(BUILD_DIR)\lib\testing.lib
DOC_GENERATED_DIR := ../DOC/GENERATED
CALL_ORDER := $(DOC_GENERATED_DIR)/CALL_ORDER.md
CALL_ORDER_SRC := $(ROM_SRC) $(APP_SRC)
ROUTINE_CONTRACTS := $(DOC_GENERATED_DIR)/ROUTINE_CONTRACTS.md
ROUTINE_TREE := $(DOC_GENERATED_DIR)/ROUTINE_TREE.md
ROUTINE_CLASS_DIAGRAM := $(DOC_GENERATED_DIR)/ROUTINE_CLASS_DIAGRAM.md
ROUTINE_GRAPH_INSIGHTS := $(DOC_GENERATED_DIR)/ROUTINE_GRAPH_INSIGHTS.md
ROUTINE_COMPONENTS := $(DOC_GENERATED_DIR)/ROUTINE_COMPONENTS.md
GENERATED_DOCS := $(CALL_ORDER) $(ROUTINE_CONTRACTS) $(ROUTINE_TREE) $(ROUTINE_CLASS_DIAGRAM) $(ROUTINE_GRAPH_INSIGHTS) $(ROUTINE_COMPONENTS)
ROUTINE_HASH_COMMENTS_GEN := tools/gen_routine_hash_comments.ps1
DOCS_GEN := tools/gen_docs.ps1
DOCS_WATCH := tools/watch_docs.ps1
HELP_GEN := tools/show_make_help.ps1
HELP_QUERY := $(if $(Q),$(Q),$(SEARCH))

# Optional local commands (override from CLI, e.g. make upload UPLOADER="tool --flash")
TERMINAL ?=
UPLOADER ?=

ALL_TARGETS := \
	himonia \
	himon \
	str8 \
	basic-himon-rom-bin \
	basic-forth-himon-rom-bin \
	fnv1a-hbstr \
	test-mon \
	test-ftdi-drv \
	test-ftdi-hal \
	test-flash \
	life \
	microchess \
	rom-append-calc \
	fig-forth \
	msbasic-osi \
	msbasic-osi-ram

RELEASE_TARGETS ?= \
	himon \
	fnv1a-hbstr \
	test-flash \
	rom-append-calc

RELEASE_LOCAL_TARGETS ?= \
	basic-himon-rom-bin \
	basic-forth-himon-rom-bin

all: $(ALL_TARGETS)

help:
	powershell -NoProfile -ExecutionPolicy Bypass -File $(HELP_GEN) -Query "$(HELP_QUERY)"

release: docs $(RELEASE_TARGETS)
	@$(MAKE) artifacts
	@echo "Release build complete."
	@echo "Tracked-source release targets: $(RELEASE_TARGETS)"
	@echo "Primary monitor binary: $(HIMON_ROM_BIN)"
	@echo "Primary monitor S19: $(HIMON_ROM_S19)"
	@echo "Stamped ROM archive dir: $(ROM_BIN_ARCHIVE_DIR)"
	powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(ROM_BIN_ARCHIVE_DIR)') { Get-ChildItem -LiteralPath '$(ROM_BIN_ARCHIVE_DIR)' -Filter '*.bin' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 8 | ForEach-Object { '  ' + $$_.Name } }"

release-local: release $(RELEASE_LOCAL_TARGETS)
	@$(MAKE) artifacts
	@echo "Local/private release build complete."
	@echo "Local release targets: $(RELEASE_LOCAL_TARGETS)"

himonia: $(ROM_LIB) $(HIMONIA_S19) himonia-rom-bin
	@echo "Built $(HIMONIA_S19)."
	@$(MAKE) artifacts

himonia-rom: $(ROM_LIB) $(HIMONIA_ROM_S19)
	@echo "Built $(HIMONIA_ROM_S19)."
	@$(MAKE) artifacts

himonia-rom-bin: himonia-rom
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_himon_rom_bin.ps1 -MapPath "$(MAP_DIR)/himonia-rom.map" -S19Path "$(S19_DIR)/himonia-rom.s19" -BinPath "$(HIMONIA_ROM_BIN)" -TmpVecPath "$(BUILD_DIR)/tmp/himonia-rom-vectors.bin" -NmiSymbol "SYS_VEC_ENTRY_NMI" -IrqSymbol "SYS_VEC_ENTRY_IRQ_MASTER" -ResetSymbol "START"
	powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(BIN_DIR)/himonia-rom-vectors.bin') { Remove-Item -LiteralPath '$(BIN_DIR)/himonia-rom-vectors.bin' -Force }"
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/stamp_rom_bin.ps1 -SourcePath "$(HIMONIA_ROM_BIN)" -OutDir "$(ROM_BIN_ARCHIVE_DIR)" -Stamp "$(ROM_BIN_STAMP)"
	@echo "Built $(HIMONIA_ROM_BIN)."

himon: $(ROM_LIB) $(HIMON_S19) himon-rom-bin
	@echo "Built $(HIMON_S19)."
	@$(MAKE) artifacts

himon-rom: $(ROM_LIB) $(HIMON_ROM_S19)
	@echo "Built $(HIMON_ROM_S19)."
	@$(MAKE) artifacts

himon-rom-bin: himon-rom
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_himon_rom_bin.ps1 -MapPath "$(MAP_DIR)/himon-rom.map" -S19Path "$(S19_DIR)/himon-rom.s19" -BinPath "$(HIMON_ROM_BIN)" -TmpVecPath "$(BUILD_DIR)/tmp/himon-rom-vectors.bin" -NmiSymbol "SYS_VEC_ENTRY_NMI" -IrqSymbol "SYS_VEC_ENTRY_IRQ_MASTER" -ResetSymbol "START"
	powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(BIN_DIR)/himon-rom-vectors.bin') { Remove-Item -LiteralPath '$(BIN_DIR)/himon-rom-vectors.bin' -Force }"
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/stamp_rom_bin.ps1 -SourcePath "$(HIMON_ROM_BIN)" -OutDir "$(ROM_BIN_ARCHIVE_DIR)" -Stamp "$(ROM_BIN_STAMP)"
	@echo "Built $(HIMON_ROM_BIN)."

basic-himon-rom-bin: $(BASIC_HIMON_ROM_BIN)
	@echo "Built $(BASIC_HIMON_ROM_BIN)."

basic-forth-himon-rom-bin: $(BASIC_FORTH_HIMON_ROM_BIN)
	@echo "Built $(BASIC_FORTH_HIMON_ROM_BIN)."

fnv1a-hbstr: $(ROM_LIB) $(FNV1A_HBSTR_S19)
	@echo "Built $(FNV1A_HBSTR_S19)."

str8: $(STR8_S19)
	@echo "Built $(STR8_S19)."
	@$(MAKE) artifacts

test-mon: $(ROM_LIB) $(TEST_LIB) $(TMON_S19)
	@echo "Built $(TMON_S19)."
	@$(MAKE) artifacts

test-ftdi-drv: $(ROM_LIB) $(TEST_LIB) $(TFTDI_S19)
	@echo "Built $(TFTDI_S19)."
	@$(MAKE) artifacts

test-ftdi-hal: $(ROM_LIB) $(TEST_LIB) $(TFHAL_S19)
	@echo "Built $(TFHAL_S19)."
	@$(MAKE) artifacts

test-flash: $(ROM_LIB) $(TFLASH_S19)
	@echo "Built $(TFLASH_S19)."
	@$(MAKE) artifacts

life: $(ROM_LIB) $(LIFE_S19)
	@echo "Built $(LIFE_S19)."
	@$(MAKE) artifacts

microchess: $(ROM_LIB) $(MICROCHESS_S19)
	@echo "Built $(MICROCHESS_S19)."
	@$(MAKE) artifacts

rom-append-calc: $(ROM_LIB) $(ROM_APPEND_CALC_S19)
	@echo "Built $(ROM_APPEND_CALC_S19)."
	@$(MAKE) artifacts

fig-forth: $(ROM_LIB) $(FIG_FORTH_S19)
	@echo "Built $(FIG_FORTH_S19)."
	@$(MAKE) artifacts

fig-forth-src: $(FIG_FORTH_SRC)
	@echo "Built local $(FIG_FORTH_SRC)."

msbasic-osi: $(MSBASIC_OSI_S19) $(MSBASIC_OSI_BIN)
	@echo "Built $(MSBASIC_OSI_S19) and $(MSBASIC_OSI_BIN)."

msbasic-osi-src: $(MSBASIC_OSI_SRC)
	@echo "Built local $(MSBASIC_OSI_SRC)."

msbasic-osi-bin: $(MSBASIC_OSI_BIN)
	@echo "Built $(MSBASIC_OSI_BIN)."

msbasic-osi-ram: $(MSBASIC_OSI_RAM_S19)
	@echo "Built $(MSBASIC_OSI_RAM_S19)."

call-order: $(CALL_ORDER)
	@echo "Updated $(CALL_ORDER)."

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

docs: $(GENERATED_DOCS)
	@echo "Updated docs: $(GENERATED_DOCS)."

docs-watch:
	powershell -NoProfile -ExecutionPolicy Bypass -File $(DOCS_WATCH) -Src . -OutDir $(DOC_GENERATED_DIR)

local-homes:
	@if not exist $(subst /,\,$(BASIC_PROGRAMS_HOME)) mkdir $(subst /,\,$(BASIC_PROGRAMS_HOME))
	@if not exist $(subst /,\,$(FIG_FORTH_HOME)) mkdir $(subst /,\,$(FIG_FORTH_HOME))
	@if not exist $(subst /,\,$(MSBASIC_HOME)) mkdir $(subst /,\,$(MSBASIC_HOME))
	@if not exist $(subst /,\,$(WDCMONV2_HOME)) mkdir $(subst /,\,$(WDCMONV2_HOME))
	@if not exist $(subst /,\,$(S3X_HOME)) mkdir $(subst /,\,$(S3X_HOME))
	powershell -NoProfile -ExecutionPolicy Bypass -File $(LOCAL_PROVENANCE) -Name "basic-programs" -LocalHome "$(BASIC_PROGRAMS_HOME)" -SourcePath "$(BASIC_PROGRAMS_HOME)" -Note "Local .BAS programs live here and are intentionally ignored."
	powershell -NoProfile -ExecutionPolicy Bypass -File $(LOCAL_PROVENANCE) -Name "fig-forth" -LocalHome "$(FIG_FORTH_HOME)" -SourcePath "$(FIG_FORTH_INPUT)" -GeneratedPath "$(FIG_FORTH_SRC)" -ToolPath "tools/emit_fig_forth_wdc.ps1" -Note "Local fig-Forth source/generated files; intentionally ignored."
	powershell -NoProfile -ExecutionPolicy Bypass -File $(LOCAL_PROVENANCE) -Name "msbasic" -LocalHome "$(MSBASIC_HOME)" -SourceRoot "$(MSBASIC_SRC_ROOT)" -GeneratedPath "$(MSBASIC_OSI_SRC)" -ToolPath "$(MSBASIC_OSI_GEN)" -Note "Local MS BASIC source/generated files; intentionally ignored."
	powershell -NoProfile -ExecutionPolicy Bypass -File $(LOCAL_PROVENANCE) -Name "wdcmonv2" -LocalHome "$(WDCMONV2_HOME)" -SourcePath "$(WDCMONV2_HOME)" -Note "Local WDCMONv2 sources/binaries live here and are intentionally ignored."
	powershell -NoProfile -ExecutionPolicy Bypass -File $(LOCAL_PROVENANCE) -Name "s3x" -LocalHome "$(S3X_HOME)" -SourcePath "$(S3X_HOME)" -Note "Local s3x material lives here and is intentionally ignored."

# Build shared module library independently.
rom: $(ROM_LIB)
	@echo "Built $(ROM_LIB)."
	@$(MAKE) artifacts

testing: $(TEST_LIB)
	@echo "Built $(TEST_LIB)."

$(HIMONIA_S19): $(HIMONIA_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMONIA_LINKFLAGS) $(HIMONIA_S19) $(HIMONIA_OBJ) -L $(BUILD_DIR)\lib\rom

$(HIMONIA_ROM_S19): $(HIMONIA_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMONIA_ROM_LINKFLAGS) $(HIMONIA_ROM_S19) $(HIMONIA_OBJ) -L $(BUILD_DIR)\lib\rom

$(HIMON_S19): $(HIMON_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMON_LINKFLAGS) $(HIMON_S19) $(HIMON_OBJ) -L $(BUILD_DIR)\lib\rom

$(HIMON_ROM_S19): $(HIMON_ROM_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMON_ROM_LINKFLAGS) $(HIMON_ROM_S19) $(HIMON_ROM_OBJ) -L $(BUILD_DIR)\lib\rom

$(FNV1A_HBSTR_S19): $(FNV1A_HBSTR_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(FNV1A_HBSTR_LINKFLAGS) $(FNV1A_HBSTR_S19) $(FNV1A_HBSTR_OBJ) -L $(BUILD_DIR)\lib\rom

$(STR8_S19): $(STR8_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(STR8_LINKFLAGS) $(STR8_S19) $(STR8_OBJ) -L $(BUILD_DIR)\lib\rom
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(STR8_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S903F80004'; Set-Content -Path $$p -Value $$lines"

$(TMON_S19): $(TMON_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(TEST_LINKFLAGS) $(TMON_S19) $(TMON_OBJ) -L $(BUILD_DIR)\lib\rom -L $(BUILD_DIR)\lib\testing

$(TFTDI_S19): $(TFTDI_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(TEST_LINKFLAGS) $(TFTDI_S19) $(TFTDI_OBJ) -L $(BUILD_DIR)\lib\rom -L $(BUILD_DIR)\lib\testing

$(TFHAL_S19): $(TFHAL_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(TEST_LINKFLAGS) $(TFHAL_S19) $(TFHAL_OBJ) -L $(BUILD_DIR)\lib\rom -L $(BUILD_DIR)\lib\testing

$(TFLASH_S19): $(TFLASH_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(TFLASH_LINKFLAGS) $(TFLASH_S19) $(TFLASH_OBJ) -L $(BUILD_DIR)\lib\rom
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(TFLASH_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9033000CC'; Set-Content -Path $$p -Value $$lines"

$(LIFE_S19): $(LIFE_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(TEST_LINKFLAGS) $(LIFE_S19) $(LIFE_OBJ) -L $(BUILD_DIR)\lib\rom
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(LIFE_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9032000DC'; Set-Content -Path $$p -Value $$lines"

$(MICROCHESS_S19): $(MICROCHESS_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(MICROCHESS_LINKFLAGS) $(MICROCHESS_S19) $(MICROCHESS_OBJ) -L $(BUILD_DIR)\lib\rom
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(MICROCHESS_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S903A9084B'; Set-Content -Path $$p -Value $$lines"

$(ROM_APPEND_CALC_S19): $(ROM_APPEND_CALC_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(ROM_APPEND_CALC_LINKFLAGS) $(ROM_APPEND_CALC_S19) $(ROM_APPEND_CALC_OBJ) -L $(BUILD_DIR)\lib\rom
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(ROM_APPEND_CALC_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9039A085A'; Set-Content -Path $$p -Value $$lines"

$(FIG_FORTH_S19): $(FIG_FORTH_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(FIG_FORTH_LINKFLAGS) $(FIG_FORTH_S19) $(FIG_FORTH_OBJ) -L $(BUILD_DIR)\lib\rom
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(FIG_FORTH_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S903900864'; Set-Content -Path $$p -Value $$lines"

$(FIG_FORTH_SRC):
	@if not exist $(subst /,\,$(dir $(FIG_FORTH_SRC))) mkdir $(subst /,\,$(dir $(FIG_FORTH_SRC)))
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/emit_fig_forth_wdc.ps1 -SourcePath "$(FIG_FORTH_INPUT)" -OutPath "$(FIG_FORTH_SRC)"
	powershell -NoProfile -ExecutionPolicy Bypass -File $(LOCAL_PROVENANCE) -Name "fig-forth" -LocalHome "$(FIG_FORTH_HOME)" -SourcePath "$(FIG_FORTH_INPUT)" -GeneratedPath "$(FIG_FORTH_SRC)" -ToolPath "tools/emit_fig_forth_wdc.ps1" -Note "Generated local WDC-flavored fig-Forth source."

$(MSBASIC_OSI_S19): $(MSBASIC_OSI_OBJ)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(MSBASIC_OSI_LINKFLAGS) $(MSBASIC_OSI_S19) $(MSBASIC_OSI_OBJ)
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$map = if (Test-Path -LiteralPath '$(S19_DIR)/msbasic-osi.map') { '$(S19_DIR)/msbasic-osi.map' } elseif (Test-Path -LiteralPath '$(MAP_DIR)/msbasic-osi.map') { '$(MAP_DIR)/msbasic-osi.map' } else { throw 'msbasic-osi.map not found' }; $$m = Select-String -Path $$map -Pattern '^\s*([0-9A-Fa-f]{8})\s+COLD_START\s*$$' | Select-Object -First 1; if (-not $$m) { throw 'COLD_START not found in map' }; $$addr = [Convert]::ToInt32($$m.Matches[0].Groups[1].Value.Substring(4), 16); $$sum = 3 + (($$addr -shr 8) -band 255) + ($$addr -band 255); $$chk = ($$sum -bxor 255) -band 255; $$rec = ('S903{0:X4}{1:X2}' -f $$addr, $$chk); $$lines = Get-Content -Path '$(MSBASIC_OSI_S19)'; $$lines[-1] = $$rec; Set-Content -Path '$(MSBASIC_OSI_S19)' -Value $$lines"

$(MSBASIC_OSI_BIN): $(MSBASIC_OSI_S19) tools/build_msbasic_osi_bin.ps1
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_msbasic_osi_bin.ps1 -MapPath "$(S19_DIR)/msbasic-osi.map" -S19Path "$(MSBASIC_OSI_S19)" -BinPath "$(MSBASIC_OSI_BIN)"
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/stamp_rom_bin.ps1 -SourcePath "$(MSBASIC_OSI_BIN)" -OutDir "$(ROM_BIN_ARCHIVE_DIR)" -Stamp "$(ROM_BIN_STAMP)"

$(BASIC_HIMON_ROM_BIN): $(MSBASIC_OSI_S19) $(HIMON_ROM_S19) tools/build_basic_himon_rom_bin.ps1
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_basic_himon_rom_bin.ps1 -MsbasicMapPath "$(S19_DIR)/msbasic-osi.map" -MsbasicS19Path "$(MSBASIC_OSI_S19)" -HimonMapPath "$(S19_DIR)/himon-rom.map" -HimonS19Path "$(HIMON_ROM_S19)" -BinPath "$(BASIC_HIMON_ROM_BIN)" -TmpVecPath "$(BUILD_DIR)/tmp/basic-himon-rom-vectors.bin"
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/stamp_rom_bin.ps1 -SourcePath "$(BASIC_HIMON_ROM_BIN)" -OutDir "$(ROM_BIN_ARCHIVE_DIR)" -Stamp "$(ROM_BIN_STAMP)"

$(BASIC_FORTH_HIMON_ROM_BIN): $(MICROCHESS_S19) $(FIG_FORTH_S19) $(MSBASIC_OSI_S19) $(HIMON_ROM_S19) tools/build_basic_forth_himon_rom_bin.ps1
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_basic_forth_himon_rom_bin.ps1 -MicrochessMapPath "$(S19_DIR)/microchess-a900.map" -MicrochessS19Path "$(MICROCHESS_S19)" -ForthMapPath "$(S19_DIR)/fig-forth-9000.map" -ForthS19Path "$(FIG_FORTH_S19)" -MsbasicMapPath "$(S19_DIR)/msbasic-osi.map" -MsbasicS19Path "$(MSBASIC_OSI_S19)" -HimonMapPath "$(S19_DIR)/himon-rom.map" -HimonS19Path "$(HIMON_ROM_S19)" -BinPath "$(BASIC_FORTH_HIMON_ROM_BIN)"
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/stamp_rom_bin.ps1 -SourcePath "$(BASIC_FORTH_HIMON_ROM_BIN)" -OutDir "$(ROM_BIN_ARCHIVE_DIR)" -Stamp "$(ROM_BIN_STAMP)"

$(MSBASIC_OSI_RAM_S19): $(MSBASIC_OSI_OBJ)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(MSBASIC_OSI_RAM_LINKFLAGS) $(MSBASIC_OSI_RAM_S19) $(MSBASIC_OSI_OBJ)
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$map = if (Test-Path -LiteralPath '$(S19_DIR)/msbasic-osi-ram.map') { '$(S19_DIR)/msbasic-osi-ram.map' } elseif (Test-Path -LiteralPath '$(MAP_DIR)/msbasic-osi-ram.map') { '$(MAP_DIR)/msbasic-osi-ram.map' } else { throw 'msbasic-osi-ram.map not found' }; $$m = Select-String -Path $$map -Pattern '^\s*([0-9A-Fa-f]{8})\s+COLD_START\s*$$' | Select-Object -First 1; if (-not $$m) { throw 'COLD_START not found in map' }; $$addr = [Convert]::ToInt32($$m.Matches[0].Groups[1].Value.Substring(4), 16); $$sum = 3 + (($$addr -shr 8) -band 255) + ($$addr -band 255); $$chk = ($$sum -bxor 255) -band 255; $$rec = ('S903{0:X4}{1:X2}' -f $$addr, $$chk); $$lines = Get-Content -Path '$(MSBASIC_OSI_RAM_S19)'; $$lines[-1] = $$rec; Set-Content -Path '$(MSBASIC_OSI_RAM_S19)' -Value $$lines"

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

$(MSBASIC_OSI_SRC):
	@if not exist $(subst /,\,$(dir $(MSBASIC_OSI_SRC))) mkdir $(subst /,\,$(dir $(MSBASIC_OSI_SRC)))
	$(PYTHON) $(MSBASIC_OSI_GEN) --source-root "$(MSBASIC_SRC_ROOT)" --out "$(MSBASIC_OSI_SRC)"
	powershell -NoProfile -ExecutionPolicy Bypass -File $(LOCAL_PROVENANCE) -Name "msbasic" -LocalHome "$(MSBASIC_HOME)" -SourceRoot "$(MSBASIC_SRC_ROOT)" -GeneratedPath "$(MSBASIC_OSI_SRC)" -ToolPath "$(MSBASIC_OSI_GEN)" -Note "Generated local WDC-flavored OSI MS BASIC source."

$(MSBASIC_OSI_OBJ): $(MSBASIC_OSI_SRC) $(HIMON_ROM_S19) tools/patch_msbasic_himon_addrs.ps1
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/patch_msbasic_himon_addrs.ps1 -SourcePath "$(MSBASIC_OSI_SRC)" -MapPath "$(S19_DIR)/himon-rom.map"
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	@if exist $(subst /,\,$(<:.asm=.obj)) move /Y $(subst /,\,$(<:.asm=.obj)) $(subst /,\,$@)

$(FIG_FORTH_OBJ): $(FIG_FORTH_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	@if exist $(subst /,\,$(<:.asm=.obj)) move /Y $(subst /,\,$(<:.asm=.obj)) $(subst /,\,$@)

$(HIMON_ROM_OBJ): $(HIMON_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) -DROM_ABI $<
	@if exist $(subst /,\,$(<:.asm=.obj)) move /Y $(subst /,\,$(<:.asm=.obj)) $(subst /,\,$@)

$(OBJ_DIR)/%.obj: %.asm
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	@if exist $(subst /,\,$*.obj) move /Y $(subst /,\,$*.obj) $(subst /,\,$@)

$(GENERATED_DOCS): $(CALL_ORDER_SRC) $(DOCS_GEN)
	powershell -NoProfile -ExecutionPolicy Bypass -Command "New-Item -ItemType Directory -Force -Path '$(DOC_GENERATED_DIR)' | Out-Null"
	powershell -NoProfile -ExecutionPolicy Bypass -File $(DOCS_GEN) -Src . -OutDir $(DOC_GENERATED_DIR)

artifacts:
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$pairs = @(@{Ext='lst';Dir='$(LST_DIR)'},@{Ext='sym';Dir='$(SYM_DIR)'},@{Ext='map';Dir='$(MAP_DIR)'},@{Ext='bin';Dir='$(BIN_DIR)'},@{Ext='s19';Dir='$(S19_DIR)'}); foreach ($$p in $$pairs) { New-Item -ItemType Directory -Force -Path $$p.Dir | Out-Null }; foreach ($$p in $$pairs) { $$src = @('$(APPS_DIR)'); if ($$p.Ext -ne 's19') { $$src += '$(S19_DIR)' }; $$dst = (Resolve-Path $$p.Dir).Path; Get-ChildItem -Recurse -File -Path $$src -Filter ('*.' + $$p.Ext) | Where-Object { $$_.DirectoryName -ne $$dst } | ForEach-Object { Move-Item -LiteralPath $$_.FullName -Destination (Join-Path $$p.Dir $$_.Name) -Force }; Get-ChildItem -File -Path . -Filter ('*.' + $$p.Ext) | ForEach-Object { Move-Item -LiteralPath $$_.FullName -Destination (Join-Path $$p.Dir $$_.Name) -Force } }"
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

.PHONY: all help release release-local himonia himonia-rom himonia-rom-bin himon himon-rom himon-rom-bin basic-himon-rom-bin basic-forth-himon-rom-bin fnv1a-hbstr str8 test-mon test-ftdi-drv test-ftdi-hal test-flash life microchess rom-append-calc fig-forth fig-forth-src msbasic-osi msbasic-osi-src msbasic-osi-bin msbasic-osi-ram local-homes call-order routine-contracts routine-tree routine-class-diagram routine-graph-insights routine-components routine-hash-comments docs docs-watch rom testing artifacts clean realclean upload term
