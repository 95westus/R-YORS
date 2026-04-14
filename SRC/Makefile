ASM := wdc02as
LIB := wdclib
LINKER := wdcln
ASFLAGS := -G -L -S -W
LINKFLAGS := -g -s -t -c1000 -hm19 -j -o
LIB_DIR := LIB
APP_DIR := TEST
LIB_SUBDIRS := $(LIB_DIR)/acia $(LIB_DIR)/pia $(LIB_DIR)/ftdi $(LIB_DIR)/util $(LIB_DIR)/dev
BUILD_DIR := BUILD
OBJ_DIR := $(BUILD_DIR)/obj
LST_DIR := $(BUILD_DIR)/lst
SYM_DIR := $(BUILD_DIR)/sym
MAP_DIR := $(BUILD_DIR)/map
BIN_DIR := $(BUILD_DIR)/bin
S19_DIR := $(BUILD_DIR)/s19

# Module map:
# - rom.lib is built from:
#   - grouped subsystem modules under LIB/{ftdi,util,dev,acia,pia}
# - lowlevel-test.s19 is the final image (lowlevel-test.obj + rom.lib)

#TEST_SRC := lowlevel-test.asm
#TEST_OBJ := lowlevel-test.obj
#TEST_S19 := lowlevel-test.s19

TEST_SRC := $(APP_DIR)/test-backend.asm
TEST_OBJ := $(OBJ_DIR)/$(APP_DIR)/test-backend.obj
TEST_S19 := $(S19_DIR)/test-backend.s19

CMD_SRC := $(APP_DIR)/cmd.asm
CMD_OBJ := $(OBJ_DIR)/$(APP_DIR)/cmd.obj
CMD_S19 := $(S19_DIR)/cmd.s19
DUMP_SRC := $(APP_DIR)/dump.asm
DUMP_OBJ := $(OBJ_DIR)/$(APP_DIR)/dump.obj
DUMP_S19 := $(S19_DIR)/dump.s19
MON_SRC := $(APP_DIR)/monitor.asm
MON_OBJ := $(OBJ_DIR)/$(APP_DIR)/monitor.obj
MON_S19 := $(S19_DIR)/monitor.s19
HIM_SRC := $(APP_DIR)/himon.asm
HIM_OBJ := $(OBJ_DIR)/$(APP_DIR)/himon.obj
HIM_S19 := $(S19_DIR)/himon.s19
TMON_SRC := $(APP_DIR)/test-mon.asm
TMON_OBJ := $(OBJ_DIR)/$(APP_DIR)/test-mon.obj
TMON_S19 := $(S19_DIR)/test-mon.s19
TMON_LINKFLAGS := -g -s -t -c5000 -hm19 -j -o

ROM_SRC := $(foreach d,$(LIB_SUBDIRS),$(wildcard $(d)/*.asm))
ROM_OBJ := $(addprefix $(OBJ_DIR)/,$(ROM_SRC:.asm=.obj))
ROM_LIB := rom.lib
CALL_ORDER := CALL_ORDER.md
CALL_ORDER_SRC := $(ROM_SRC) $(wildcard $(APP_DIR)/*.asm)
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

# Optional local commands (override from CLI, e.g. make upload UPLOADER="tool --flash")
TERMINAL ?=
UPLOADER ?=

all: test-backend cmd dump monitor himon

#lowlevel-test: $(ROM_LIB) $(TEST_S19)
#	@echo "Build complete. Use 'make term' to connect to the device or 'make upload' to flash."

test-backend: $(ROM_LIB) $(TEST_S19)
	@echo "Build complete. Use 'make term' to connect to the device or 'make upload' to flash."
	@$(MAKE) artifacts

backend-test: test-backend

cmd: $(ROM_LIB) $(CMD_S19)
	@echo "Built $(CMD_S19)."
	@$(MAKE) artifacts

dump: $(ROM_LIB) $(DUMP_S19)
	@echo "Built $(DUMP_S19)."
	@$(MAKE) artifacts

monitor: $(ROM_LIB) $(MON_S19)
	@echo "Built $(MON_S19)."
	@$(MAKE) artifacts

himon: $(ROM_LIB) $(HIM_S19)
	@echo "Built $(HIM_S19)."
	@$(MAKE) artifacts

test-mon: $(ROM_LIB) $(TMON_S19)
	@echo "Built $(TMON_S19)."
	@$(MAKE) artifacts

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
	@echo "Updated routine RHID comments in .asm files."

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

$(TEST_S19): $(TEST_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(LINKFLAGS) $(TEST_S19) $(TEST_OBJ) -L rom

$(CMD_S19): $(CMD_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(LINKFLAGS) $(CMD_S19) $(CMD_OBJ) -L rom

$(DUMP_S19): $(DUMP_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(LINKFLAGS) $(DUMP_S19) $(DUMP_OBJ) -L rom

$(MON_S19): $(MON_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(LINKFLAGS) $(MON_S19) $(MON_OBJ) -L rom

$(HIM_S19): $(HIM_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(LINKFLAGS) $(HIM_S19) $(HIM_OBJ) -L rom

$(TMON_S19): $(TMON_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(TMON_LINKFLAGS) $(TMON_S19) $(TMON_OBJ) -L rom

$(ROM_LIB): $(ROM_OBJ)
	@if exist $(ROM_LIB) del /f $(ROM_LIB)
	$(LIB) -A $(ROM_LIB) $(ROM_OBJ)
	@if exist LIB.TMP move /Y LIB.TMP $(ROM_LIB)

$(OBJ_DIR)/%.obj: %.asm
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	@if exist $(subst /,\,$*.obj) move /Y $(subst /,\,$*.obj) $(subst /,\,$@)

$(CALL_ORDER): $(CALL_ORDER_SRC) $(CALL_ORDER_GEN)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(CALL_ORDER_GEN) -Src . -Out $(CALL_ORDER)

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
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$pairs = @(@{Ext='lst';Dir='$(LST_DIR)'},@{Ext='sym';Dir='$(SYM_DIR)'},@{Ext='map';Dir='$(MAP_DIR)'},@{Ext='bin';Dir='$(BIN_DIR)'},@{Ext='s19';Dir='$(S19_DIR)'}); foreach ($$p in $$pairs) { New-Item -ItemType Directory -Force -Path $$p.Dir | Out-Null }; foreach ($$p in $$pairs) { Get-ChildItem -Recurse -File -Path '$(LIB_DIR)','$(APP_DIR)' -Filter ('*.' + $$p.Ext) | ForEach-Object { Move-Item -LiteralPath $$_.FullName -Destination (Join-Path $$p.Dir $$_.Name) -Force }; Get-ChildItem -File -Path . -Filter ('*.' + $$p.Ext) | ForEach-Object { Move-Item -LiteralPath $$_.FullName -Destination (Join-Path $$p.Dir $$_.Name) -Force } }"
	@echo "Moved sidecar artifacts into $(BUILD_DIR)/{lst,sym,map,bin,s19}."

clean:
	-del /f *.obj *.lst *.sym *.map *.bin >nul 2>nul
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Get-ChildItem -Recurse -File -Path '$(LIB_DIR)','$(APP_DIR)' -Include *.obj,*.lst,*.sym,*.map,*.bin | Remove-Item -Force -ErrorAction SilentlyContinue"
	@if exist $(BUILD_DIR) rmdir /s /q $(BUILD_DIR)
	@rem keep test.s19 and rom.lib between normal builds

realclean: clean
	-del /f *.lib *.s19 LIB.TMP >nul 2>nul

upload:
ifeq ($(strip $(UPLOADER)),)
	@echo "Set UPLOADER and rerun, e.g. make upload UPLOADER=\"your_uploader_command $(TEST_S19)\""
else
	$(UPLOADER)
endif

term:
ifeq ($(strip $(TERMINAL)),)
	@echo "Set TERMINAL and rerun, e.g. make term TERMINAL=\"your_terminal_tool $(TEST_S19)\""
else
	$(TERMINAL)
endif

.PHONY: all test test-backend backend-test cmd dump monitor himon test-mon call-order routine-contracts routine-tree routine-class-diagram routine-graph-insights routine-components routine-hash-comments docs docs-watch rom rom-auto rom-ftdi rom-acia artifacts clean realclean upload term
