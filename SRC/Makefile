ASM := wdc02as
LIB := wdclib
LINKER := wdcln
ASFLAGS = -G -L -S -W -I $(BUILD_DIR) -I $(INC_DIR)
LINKFLAGS := -g -s -t -c1000 -hm19 -j -o
TEST_LINKFLAGS := -g -s -t -c2000 -hm19 -j -o
TFLASH_LINKFLAGS := -g -s -t -c3000 -hm19 -j -o
LIB_DIR := LIB
HIMON_DIR := HIMON
STR8_DIR := STR8
TESTS_DIR := TESTS
PROOFS_DIR := PROOFS
APPS_DIR := APPS
ASM_DIR := ASM
TEST_SUPPORT_DIR := $(TESTS_DIR)/support
LIB_SUBDIRS := $(LIB_DIR)/ftdi $(LIB_DIR)/util $(LIB_DIR)/dev $(LIB_DIR)/acia $(LIB_DIR)/pia
BUILD_DIR := BUILD
OBJ_DIR := $(BUILD_DIR)/obj
INC_DIR := $(BUILD_DIR)/inc
LST_DIR := $(BUILD_DIR)/lst
SYM_DIR := $(BUILD_DIR)/sym
MAP_DIR := $(BUILD_DIR)/map
BIN_DIR := $(BUILD_DIR)/bin
S19_DIR := $(BUILD_DIR)/s19
ROM_BIN_STAMP_DEFAULT := $(shell powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-ddTHH:mmK'")
ROM_BIN_STAMP ?= $(ROM_BIN_STAMP_DEFAULT)
ROM_BIN_ARCHIVE_DIR := ROM_IMAGES
HIMON_VISIBLE_STAMP ?=
HIMON_VISIBLE_STAMP_ARG := $(if $(HIMON_VISIBLE_STAMP),-Stamp "$(HIMON_VISIBLE_STAMP)",)
PYTHON ?= python

LOCAL_ROOT ?= ../LOCAL
LOCAL_PROVENANCE := tools/write_local_provenance.ps1
ASMTEST_CHECK := tools/check_asmtest_3000.ps1
ASM_OPCODE_AUDIT := tools/check_asm_opcode_coverage.ps1
HIMON_VERSION_STAMP := tools/stamp_himon_version.ps1
FIG_FORTH_HIMON_PATCH := tools/patch_fig_forth_himon_addrs.ps1
HIMON_VERSION_INC := $(INC_DIR)/himon-version.inc
BASIC_PROGRAMS_HOME ?= $(LOCAL_ROOT)/basic-programs
FIG_FORTH_HOME ?= $(LOCAL_ROOT)/fig-forth
FIG_FORTH_INPUT ?= $(FIG_FORTH_HOME)/source/ff6502.html
MSBASIC_HOME ?= $(LOCAL_ROOT)/msbasic
MSBASIC_SRC_ROOT ?= $(MSBASIC_HOME)/source
WDCMONV2_HOME ?= $(LOCAL_ROOT)/wdcmonv2
S3X_HOME ?= $(LOCAL_ROOT)/s3x

# Module map:
# - rom.lib is built from:
#   - LIB/{ftdi,util,dev,acia,pia}
#   - TESTS/ftdi-backend-debug.asm

HIM_SUBDIR := $(HIMON_DIR)
STR8_SUBDIR := $(STR8_DIR)
HIMON_SRC := $(HIM_SUBDIR)/himon.asm
HIMON_INC := $(wildcard $(HIM_SUBDIR)/*.inc)
HIMON_OBJ := $(OBJ_DIR)/$(HIM_SUBDIR)/himon-c000.obj
HIMON_ROM_OBJ := $(OBJ_DIR)/$(HIM_SUBDIR)/himon-rom-c000.obj
HIMON_S19 := $(S19_DIR)/himon-c000.s19
HIMON_LINKFLAGS := -g -s -t -cC000 -hm19 -j -o
HIMON_ROM_S19 := $(S19_DIR)/himon-rom-c000.s19
HIMON_ROM_LINKFLAGS := -g -s -t -cC000 -hm19 -j -o
HIMON_ROM_BIN := $(BIN_DIR)/himon-rom-c000.bin
HIMON_STR8_ROM_BIN := $(BIN_DIR)/himon-str8-rom.bin
HIMON_ROM_INSTALL_S19 := $(S19_DIR)/himon-rom-c000-install-8000.s19
HIMON_STR8_ROM_INSTALL_S19 := $(S19_DIR)/himon-str8-rom-install.s19
HIMON_STR8_HIMON_UPDATE_S19 := $(S19_DIR)/himon-str8-himon-update.s19
STR8_TOP_STAGE_S19 := $(S19_DIR)/str8-top-stage-0a00.s19
STR8_TOPWRITE_A := ../DOC/GUIDES/ASM/SAMPLES/str8n-topwrite-3000.a
STR8_TOPWRITE_A_GEN := tools/emit_str8_topwrite_a.ps1
HIMON_LOAD_S19 := $(S19_DIR)/himon-load-c000.s19
HIMON_LOAD_LINKFLAGS := -g -s -t -cC000 -hm19 -j -o
HIMON_LOAD_BIN := $(BIN_DIR)/himon-load-c000.bin
BASIC_HIMON_ROM_BIN := $(BIN_DIR)/basic-himon-rom.bin
BASIC_FORTH_HIMON_ROM_BIN := $(BIN_DIR)/basic-forth-himon-rom.bin
FNV1A_HBSTR_SRC := $(HIM_SUBDIR)/fnv1a-hbstr-6000.asm
FNV1A_HBSTR_OBJ := $(OBJ_DIR)/$(HIM_SUBDIR)/fnv1a-hbstr-6000.obj
FNV1A_HBSTR_S19 := $(S19_DIR)/fnv1a-hbstr-6000.s19
FNV1A_HBSTR_LINKFLAGS := -g -s -t -c6000 -hm19 -j -o
STR8_SRC := $(STR8_SUBDIR)/str8.asm
STR8_OBJ := $(OBJ_DIR)/$(STR8_SUBDIR)/str8.obj
STR8_S19 := $(S19_DIR)/str8-f000.s19
STR8_LINKFLAGS := -g -s -t -cF000 -hm19 -j -o
STR8_WORKER_SRC := $(STR8_SUBDIR)/str8-worker.asm
STR8_WORKER_OBJ := $(OBJ_DIR)/$(STR8_SUBDIR)/str8-worker.obj
STR8_WORKER_S19 := $(S19_DIR)/str8-worker-0200.s19
STR8_WORKER_LINKFLAGS := -g -s -t -c0200 -hm19 -j -o
STR8_RAM_OBJ := $(OBJ_DIR)/$(STR8_SUBDIR)/str8-ram.obj
STR8_RAM_S19 := $(S19_DIR)/str8-ram-3000.s19
STR8_RAM_LINKFLAGS := -g -s -t -c3000 -hm19 -j -o
TMON_SRC := $(TESTS_DIR)/test-mon.asm
TMON_OBJ := $(OBJ_DIR)/$(TESTS_DIR)/test-mon.obj
TMON_S19 := $(S19_DIR)/test-mon.s19
TFTDI_SRC := $(TESTS_DIR)/test-ftdi-drv-2000.asm
TFTDI_OBJ := $(OBJ_DIR)/$(TESTS_DIR)/test-ftdi-drv-2000.obj
TFTDI_S19 := $(S19_DIR)/test-ftdi-drv-2000.s19
TFHAL_SRC := $(TESTS_DIR)/test-ftdi-hal-2000.asm
TFHAL_OBJ := $(OBJ_DIR)/$(TESTS_DIR)/test-ftdi-hal-2000.obj
TFHAL_S19 := $(S19_DIR)/test-ftdi-hal-2000.s19
TFLASH_SRC := $(TESTS_DIR)/test-flash-3000.asm
TFLASH_OBJ := $(OBJ_DIR)/$(TESTS_DIR)/test-flash-3000.obj
TFLASH_S19 := $(S19_DIR)/test-flash-3000.s19
LIFE_SRC := $(APPS_DIR)/life.asm
LIFE_OBJ := $(OBJ_DIR)/$(APPS_DIR)/life.obj
LIFE_S19 := $(S19_DIR)/life-2000.s19
LIFE_BIN := $(BIN_DIR)/life-2000-load.bin
HIMON_DEBUG_PROOF_SRC := $(PROOFS_DIR)/himon-debug-proof.asm
HIMON_DEBUG_PROOF_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/himon-debug-proof.obj
HIMON_DEBUG_PROOF_S19 := $(S19_DIR)/himon-debug-proof-3000.s19
HIMON_DEBUG_PROOF_LINKFLAGS := -g -s -t -c3000 -hm19 -j -o
HIMON_SEARCH_STATIC_PROOF_SRC := $(PROOFS_DIR)/himon-search-static-proof.asm
HIMON_SEARCH_STATIC_PROOF_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/himon-search-static-proof.obj
HIMON_SEARCH_STATIC_PROOF_S19 := $(S19_DIR)/himon-search-static-proof-3000.s19
HIMON_SEARCH_STATIC_PROOF_LINKFLAGS := -g -s -t -c3000 -hm19 -j -o
HIMON_SEARCH_PROOF_SRC := $(PROOFS_DIR)/himon-search-proof.asm
HIMON_SEARCH_PROOF_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/himon-search-proof.obj
HIMON_SEARCH_PROOF_S19 := $(S19_DIR)/himon-search-proof-3000.s19
HIMON_SEARCH_PROOF_LINKFLAGS := -g -s -t -c3000 -hm19 -j -o
HIMON_SEARCH_FLASH_SRC := $(PROOFS_DIR)/himon-search-flash.asm
HIMON_SEARCH_FLASH_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/himon-search-flash.obj
HIMON_SEARCH_FLASH_S19 := $(S19_DIR)/himon-search-flash-bb80.s19
HIMON_SEARCH_FLASH_LINKFLAGS := -g -s -t -cBB80 -hm19 -j -o
HIMON_SEARCH_FOR_HIMON_SRC := $(PROOFS_DIR)/himon-search-for-himon.asm
HIMON_SEARCH_FOR_HIMON_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/himon-search-for-himon.obj
HREC_JOIN_PROOF_SRC := $(PROOFS_DIR)/hrec-join-proof.asm
HREC_JOIN_PROOF_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/hrec-join-proof.obj
HREC_JOIN_PROOF_S19 := $(S19_DIR)/hrec-join-proof-4000.s19
HREC_JOIN_PROOF_LINKFLAGS := -g -s -t -c4000 -hm19 -j -o
PACK40_TEST_SRC := $(PROOFS_DIR)/pack40-test.asm
PACK40_TEST_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/pack40-test.obj
PACK40_TEST_S19 := $(S19_DIR)/pack40-test-3000.s19
PACK40_TEST_LINKFLAGS := -g -s -t -c3000 -hm19 -j -o
ASM_RJOIN_PROOF_SRC := $(PROOFS_DIR)/asm-rjoin-proof-3000.asm
ASM_RJOIN_PROOF_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/asm-rjoin-proof-3000.obj
ASM_RJOIN_PROOF_S19 := $(S19_DIR)/asm-rjoin-proof-3000.s19
ASM_RJOIN_PROOF_LINKFLAGS := -g -s -t -c3000 -hm19 -j -o
BANK3_ERASE_SRC := $(PROOFS_DIR)/bank3-erase-8000-bfff-3000.asm
BANK3_ERASE_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/bank3-erase-8000-bfff-3000.obj
BANK3_ERASE_S19 := $(S19_DIR)/bank3-erase-8000-bfff-3000.s19
BANK3_ERASE_LINKFLAGS := -g -s -t -c3000 -hm19 -j -o
ASM_V1_CORE_SRC := $(ASM_DIR)/asm-v1-core.asm
ASM_V1_CORE_OBJ := $(OBJ_DIR)/$(ASM_DIR)/asm-v1-core.obj
ASM_V1_CORE_S19 := $(S19_DIR)/asm-v1-core-2000.s19
ASM_V1_CORE_LINKFLAGS := -g -s -t -c2000 -hm19 -j -o
ASM_V1_RUNTIME_OBJ := $(OBJ_DIR)/$(ASM_DIR)/asm-v1-runtime.obj
ASM_V1_RUNTIME_S19 := $(S19_DIR)/asm-v1-runtime-2000.s19
ASM_V1_RUNTIME_LINKFLAGS := -g -s -t -c2000 -hm19 -j -o
ASM_V1_RUNTIME_SMOKE_SRC := $(PROOFS_DIR)/asm-v1-runtime-smoke.asm
ASM_V1_RUNTIME_SMOKE_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/asm-v1-runtime-smoke.obj
ASM_V1_RUNTIME_SMOKE_S19 := $(S19_DIR)/asm-v1-runtime-smoke-2000.s19
ASM_V1_RUNTIME_SMOKE_LINKFLAGS := -g -s -t -c2000 -hm19 -j -o
ASM_V1_RUNTIME_ASMTEST_SRC := $(PROOFS_DIR)/asm-v1-runtime-asmtest.asm
ASM_V1_RUNTIME_ASMTEST_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/asm-v1-runtime-asmtest.obj
ASM_V1_RUNTIME_ASMTEST_S19 := $(S19_DIR)/asm-v1-runtime-asmtest-2000.s19
ASM_V1_RUNTIME_ASMTEST_LINKFLAGS := -g -s -t -c2000 -hm19 -j -o
ASM_V1_RUNTIME_PASTE_SRC := $(PROOFS_DIR)/asm-v1-runtime-paste.asm
ASM_V1_RUNTIME_PASTE_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/asm-v1-runtime-paste.obj
ASM_V1_RUNTIME_PASTE_S19 := $(S19_DIR)/asm-v1-runtime-paste-2000.s19
ASM_V1_RUNTIME_PASTE_LINKFLAGS := -g -s -t -c2000 -hm19 -j -o
ASM_SESSION_REPORT_SRC := $(PROOFS_DIR)/asm-session-report.asm
ASM_SESSION_REPORT_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/asm-session-report.obj
ASM_SESSION_REPORT_S19 := $(S19_DIR)/asm-session-report-7000.s19
ASM_SESSION_REPORT_LINKFLAGS := -g -s -t -c7000 -hm19 -j -o
ASM_SESSION_REPORT_FLASH_S19 := $(S19_DIR)/asm-session-report-4800.s19
ASM_SESSION_REPORT_FLASH_LINKFLAGS := -g -s -t -c4800 -hm19 -j -o
ASM_SESSION_REPORT_INC_GEN := tools/emit_asm_session_report_inc.ps1
ASM_SESSION_REPORT_INC := $(INC_DIR)/asm-session-report.inc
ASM_SESSION_REPORT_A_FLASH := ../DOC/GUIDES/ASM/SAMPLES/asm-session-report-4800.a
ASM_SESSION_REPORT_A_RUNTIME := ../DOC/GUIDES/ASM/SAMPLES/asm-session-report-7000.a
ASM_SESSION_REPORT_AP_GEN := tools/build_ap_fixed_package.ps1
ASM_SESSION_REPORT_AP_BIN := $(BIN_DIR)/asm-session-report-4800.ap.bin
ASM_V1_FLASH_SRC := $(ASM_DIR)/asm-v1-flash.asm
ASM_V1_FLASH_OBJ := $(OBJ_DIR)/$(ASM_DIR)/asm-v1-flash.obj
ASM_V1_FLASH_RUNTIME_OBJ := $(OBJ_DIR)/$(ASM_DIR)/asm-v1-flash-runtime.obj
ASM_V1_FLASH_S19 := $(S19_DIR)/asm-v1-flash-8000.s19
ASM_V1_FLASH_LINKFLAGS := -g -s -t -c8000 -u5000 -hm19 -j -o
ASMTEST_3000_SAMPLE := ../DOC/GUIDES/ASM/SAMPLES/ASMTEST_3000.asm
ASMTEST_3000_WDC_SIDE_OBJ := $(ASMTEST_3000_SAMPLE:.asm=.obj)
ASMTEST_3000_WDC_SIDE_LST := $(ASMTEST_3000_SAMPLE:.asm=.lst)
ASMTEST_3000_WDC_OBJ := $(OBJ_DIR)/$(ASM_DIR)/asmtest-6800-wdc.obj
ASMTEST_3000_WDC_LST := $(LST_DIR)/asmtest-6800-wdc.lst
ASMTEST_3000_WDC_MAP := $(MAP_DIR)/asmtest-6800-wdc.map
ASMTEST_3000_WDC_S19 := $(S19_DIR)/asmtest-6800-wdc.s19
CALC_9A00_FNV_PROOF_SRC := $(PROOFS_DIR)/calc-9a00-fnv-proof.asm
CALC_9A00_FNV_PROOF_OBJ := $(OBJ_DIR)/$(PROOFS_DIR)/calc-9a00-fnv-proof.obj
CALC_9A00_FNV_PROOF_S19 := $(S19_DIR)/calc-9a00-fnv-proof.s19
CALC_9A00_FNV_PROOF_LINKFLAGS := -g -s -t -c9A00 -hm19 -j -o
ROM_APPEND_CALC_SRC := $(APPS_DIR)/rom-append-calc.asm
ROM_APPEND_CALC_OBJ := $(OBJ_DIR)/$(APPS_DIR)/rom-append-calc.obj
ROM_APPEND_CALC_S19 := $(S19_DIR)/rom-append-calc-b804.s19
ROM_APPEND_CALC_LINKFLAGS := -g -s -t -cB804 -hm19 -j -o
FIG_FORTH_SRC := $(FIG_FORTH_HOME)/generated/fig-forth.asm
FIG_FORTH_OBJ := $(OBJ_DIR)/LOCAL/fig-forth/fig-forth.obj
FIG_FORTH_S19 := $(S19_DIR)/fig-forth-a000.s19
FIG_FORTH_LINKFLAGS := -g -s -t -cA000 -hm19 -j -o
FIG_FORTH_C000_SRC := $(FIG_FORTH_HOME)/generated/fig-forth-c000.asm
FIG_FORTH_C000_OBJ := $(OBJ_DIR)/LOCAL/fig-forth/fig-forth-c000.obj
FIG_FORTH_C000_S19 := $(S19_DIR)/fig-forth-c000.s19
FIG_FORTH_C000_LINKFLAGS := -g -s -t -cC000 -hm19 -j -o
FIG_FORTH_STR8_UPDATE_S19 := $(S19_DIR)/fig-forth-str8-update.s19
MSBASIC_OSI_GEN := tools/emit_msbasic_osi_wdc.py
MSBASIC_OSI_C000_GEN := tools/emit_msbasic_osi_c000_from_generated.ps1
# Local-only source/generator home. Nothing under $(LOCAL_ROOT) is tracked.
MSBASIC_OSI_SRC := $(MSBASIC_HOME)/generated/osi-basic.asm
MSBASIC_OSI_OBJ := $(OBJ_DIR)/LOCAL/msbasic/osi-basic.obj
MSBASIC_OSI_S19 := $(S19_DIR)/msbasic-osi-8000.s19
MSBASIC_OSI_LINKFLAGS := -g -s -t -c8000 -hm19 -j -o
MSBASIC_OSI_BIN := $(BIN_DIR)/msbasic-osi-fnv-8000-8k.bin
MSBASIC_OSI_RAM_S19 := $(S19_DIR)/msbasic-osi-ram.s19
MSBASIC_OSI_RAM_LINKFLAGS := -g -s -t -c4000 -hm19 -j -o
MSBASIC_OSI_C000_SRC := $(MSBASIC_HOME)/generated/osi-basic-c000.asm
MSBASIC_OSI_C000_OBJ := $(OBJ_DIR)/LOCAL/msbasic/osi-basic-c000.obj
MSBASIC_OSI_C000_S19 := $(S19_DIR)/msbasic-osi-c000.s19
MSBASIC_OSI_C000_LINKFLAGS := -g -s -t -cC000 -hm19 -j -o
MSBASIC_OSI_STR8_UPDATE_S19 := $(S19_DIR)/msbasic-osi-str8-update.s19
FTDI_DRV_SRC := $(LIB_DIR)/ftdi/ftdi-drv.asm
FTDI_DRV_INC := $(LIB_DIR)/ftdi/ftdi-drv.inc
PACK40_UTIL_SRC := $(LIB_DIR)/util/util-pack40.asm
PACK40_UTIL_OBJ := $(OBJ_DIR)/$(LIB_DIR)/util/util-pack40.obj

ROM_EXTRA_SRC := $(wildcard $(TESTS_DIR)/ftdi-backend-debug.asm)
ROM_SRC := $(foreach d,$(LIB_SUBDIRS),$(wildcard $(d)/*.asm)) $(ROM_EXTRA_SRC)
APP_SRC := $(wildcard $(APPS_DIR)/*.asm) $(wildcard $(PROOFS_DIR)/*.asm) $(wildcard $(ASM_DIR)/*.asm) $(wildcard $(HIM_SUBDIR)/*.asm) $(wildcard $(STR8_SUBDIR)/*.asm) $(wildcard $(TESTS_DIR)/*.asm) $(wildcard $(TEST_SUPPORT_DIR)/*.asm) $(foreach d,$(LIB_SUBDIRS),$(wildcard $(d)/*.asm))
ROM_OBJ := $(addprefix $(OBJ_DIR)/,$(ROM_SRC:.asm=.obj))
ROM_LIB := $(BUILD_DIR)\lib\rom.lib
TEST_LIB_SRC := $(wildcard $(TEST_SUPPORT_DIR)/*.asm)
TEST_LIB_OBJ := $(addprefix $(OBJ_DIR)/,$(TEST_LIB_SRC:.asm=.obj))
TEST_LIB := $(BUILD_DIR)\lib\testing.lib
DOC_GENERATED_DIR := ../DOC/GENERATED
CALL_ORDER := $(DOC_GENERATED_DIR)/CALL_ORDER.md
CALL_ORDER_SRC := $(ROM_SRC) $(APP_SRC)
ROUTINE_CONTRACTS := $(DOC_GENERATED_DIR)/ROUTINE_CONTRACTS.md
HIMON_ROUTINE_TREE := $(DOC_GENERATED_DIR)/HIMON_ROUTINE_TREE.md
ROUTINE_CLASS_DIAGRAM := $(DOC_GENERATED_DIR)/ROUTINE_CLASS_DIAGRAM.md
ROUTINE_PREFIX_MAP := $(DOC_GENERATED_DIR)/ROUTINE_PREFIX_MAP.md
ROUTINE_WORD_TREE := $(DOC_GENERATED_DIR)/ROUTINE_WORD_TREE.md
HIMON_SUPPORT_MAP := $(DOC_GENERATED_DIR)/HIMON_SUPPORT_MAP.md
HIMON_COMMAND_MAP := $(DOC_GENERATED_DIR)/HIMON_COMMAND_MAP.md
HASH_ROUTINE_MAP := $(DOC_GENERATED_DIR)/HASH_ROUTINE_MAP.md
CMD_FLOW_MAP := $(DOC_GENERATED_DIR)/CMD_FLOW_MAP.md
STACK_DEPTH_MAP := $(DOC_GENERATED_DIR)/STACK_DEPTH_MAP.md
INTERRUPT_VECTOR_MAP := $(DOC_GENERATED_DIR)/INTERRUPT_VECTOR_MAP.md
MAP_OF_MAPS := $(DOC_GENERATED_DIR)/MAP_OF_MAPS.md
ROUTINE_GRAPH_INSIGHTS := $(DOC_GENERATED_DIR)/ROUTINE_GRAPH_INSIGHTS.md
ROUTINE_COMPONENTS := $(DOC_GENERATED_DIR)/ROUTINE_COMPONENTS.md
GENERATED_DOCS := $(CALL_ORDER) $(ROUTINE_CONTRACTS) $(HIMON_ROUTINE_TREE) $(ROUTINE_CLASS_DIAGRAM) $(ROUTINE_PREFIX_MAP) $(ROUTINE_WORD_TREE) $(HIMON_SUPPORT_MAP) $(HIMON_COMMAND_MAP) $(HASH_ROUTINE_MAP) $(CMD_FLOW_MAP) $(STACK_DEPTH_MAP) $(INTERRUPT_VECTOR_MAP) $(MAP_OF_MAPS) $(ROUTINE_GRAPH_INSIGHTS) $(ROUTINE_COMPONENTS)
ROUTINE_HASH_COMMENTS_GEN := tools/gen_routine_hash_comments.ps1
DOCS_GEN := tools/gen_docs.ps1
EDGE_DOCS_GEN := tools/gen_edge_dump.ps1
DOCS_WATCH := tools/watch_docs.ps1
DOCS_HTML_GEN := tools/gen_html_docs.ps1
DOC_HTML_DIR := ../DOC/HTML
GUIDE_HIMON_EDGE_DUMP := ../DOC/GUIDES/HIMON/HIMON_EDGE_DUMP.md
GUIDE_STR8_EDGE_DUMP := ../DOC/GUIDES/STR8/STR8_EDGE_DUMP.md
EDGE_DOCS := $(GUIDE_HIMON_EDGE_DUMP) $(GUIDE_STR8_EDGE_DUMP)
HELP_GEN := tools/show_make_help.ps1
BIN_POLICY := tools/bin_policy.ps1
BIN_CHECK := tools/check_bin_policy.ps1
ROM_INSTALL_S19_GEN := tools/build_rom_install_s19.ps1
HELP_QUERY := $(if $(Q),$(Q),$(SEARCH))

# Optional local commands (override from CLI, e.g. make upload UPLOADER="tool --flash")
TERMINAL ?=
UPLOADER ?=

FIRMWARE_TARGETS ?= \
	himon-str8-rom-bin \
	himon-str8-rom-install-s19

TEST_TARGETS ?= \
	test-mon \
	test-ftdi-drv \
	test-ftdi-hal \
	test-flash

PROOF_TARGETS ?= \
	himon-debug-proof \
	himon-search-static \
	himon-search-proof \
	himon-search-flash \
	himon-search-for-himon \
	hrec-join-proof \
	pack40-test \
	asm-rjoin-proof \
	bank3-erase \
	asm-v1-runtime-smoke \
	asm-v1-runtime-asmtest \
	asm-v1-runtime-paste \
	asm-session-report

APP_TARGETS ?= \
	life \
	rom-append-calc

ASM_TARGETS ?= \
	asm-v1-runtime \
	asm-v1-flash

LAB_TARGETS := \
	himon \
	str8 \
	himon-str8-rom-bin \
	himon-str8-himon-update-s19 \
	fnv1a-hbstr \
	$(TEST_TARGETS) \
	$(PROOF_TARGETS) \
	$(ASM_TARGETS) \
	$(APP_TARGETS)

# Local language S19/BIN targets consume ignored sources under LOCAL/. Include
# them in the broad lab sweep only when their local source homes are present.
LOCAL_LAB_TARGETS :=
ifneq ($(wildcard $(FIG_FORTH_INPUT)),)
LOCAL_LAB_TARGETS += fig-forth
endif
ifneq ($(wildcard $(MSBASIC_SRC_ROOT)/*),)
LOCAL_LAB_TARGETS += msbasic-osi msbasic-osi-ram
endif
LAB_TARGETS += $(LOCAL_LAB_TARGETS)

RELEASE_TARGETS ?= \
	himon-str8-rom-bin \
	himon-str8-rom-install-s19 \
	himon-str8-himon-update-s19

# release-local builds the private composite ROM images; they are not L F-safe
# packages.
RELEASE_LOCAL_TARGETS ?= \
	basic-himon-rom-bin \
	basic-forth-himon-rom-bin

all: firmware

firmware: $(FIRMWARE_TARGETS)
	@echo "Built current onboard firmware targets: $(FIRMWARE_TARGETS)"

lab: $(LAB_TARGETS)
	@echo "Built broad lab target set: $(LAB_TARGETS)"

everything: lab

proofs: $(PROOF_TARGETS)
	@echo "Built proof targets: $(PROOF_TARGETS)"

apps: $(APP_TARGETS)
	@echo "Built app/demo targets: $(APP_TARGETS)"

tests: $(TEST_TARGETS)
	@echo "Built test targets: $(TEST_TARGETS)"

help:
	powershell -NoProfile -ExecutionPolicy Bypass -File $(HELP_GEN) -Query "$(HELP_QUERY)"

release: docs $(RELEASE_TARGETS)
	@$(MAKE) artifacts
	powershell -NoProfile -ExecutionPolicy Bypass -File $(BIN_CHECK) -BinDir "$(BIN_DIR)"
	@echo "Release build complete."
	@echo "Tracked-source release targets: $(RELEASE_TARGETS)"
	@echo "Primary monitor binary: $(HIMON_STR8_ROM_BIN)"
	@echo "Primary monitor S19: $(HIMON_ROM_S19)"
	@echo "Primary install S19: $(HIMON_STR8_ROM_INSTALL_S19)"
	@echo "Stamped ROM archive dir: $(ROM_BIN_ARCHIVE_DIR)"
	powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(ROM_BIN_ARCHIVE_DIR)') { Get-ChildItem -LiteralPath '$(ROM_BIN_ARCHIVE_DIR)' -Filter '*.bin' -File | Sort-Object LastWriteTime -Descending | Select-Object -First 8 | ForEach-Object { $$b=[System.IO.File]::ReadAllBytes($$_.FullName); $$head=(($$b[0..([Math]::Min(2,$$b.Length-1))] | ForEach-Object { '{0:X2}' -f $$_ }) -join ' '); $$tail=(($$b[([Math]::Max(0,$$b.Length-3))..($$b.Length-1)] | ForEach-Object { '{0:X2}' -f $$_ }) -join ' '); '  ' + $$_.Name + '  len=' + $$b.Length + '  head=[' + $$head + '] tail=[' + $$tail + ']' } }"

release-local: release $(RELEASE_LOCAL_TARGETS)
	@$(MAKE) artifacts
	@echo "Local/private release build complete."
	@echo "Local release targets: $(RELEASE_LOCAL_TARGETS)"

himon: $(ROM_LIB) $(HIMON_S19) himon-load-bin himon-rom-bin
	@echo "Built $(HIMON_S19)."
	@$(MAKE) artifacts

himon-rom: $(ROM_LIB) $(HIMON_ROM_S19)
	@echo "Built $(HIMON_ROM_S19)."
	@$(MAKE) artifacts

himon-rom-bin: himon-rom
	@echo [ps] build $(HIMON_ROM_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_himon_rom_bin.ps1 -MapPath "$(MAP_DIR)/himon-rom-c000.map" -S19Path "$(HIMON_ROM_S19)" -BinPath "$(HIMON_ROM_BIN)" -TmpVecPath "$(BUILD_DIR)/tmp/himon-rom-c000-vectors.bin" -NmiSymbol "SYS_VEC_ENTRY_NMI" -IrqSymbol "SYS_VEC_ENTRY_IRQ_MASTER" -ResetSymbol "START"
	@echo [ps] clean HIMON ROM vector temp
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(BIN_DIR)/himon-rom-c000-vectors.bin') { Remove-Item -LiteralPath '$(BIN_DIR)/himon-rom-c000-vectors.bin' -Force }"
	@echo [ps] stamp $(HIMON_ROM_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/stamp_rom_bin.ps1 -SourcePath "$(HIMON_ROM_BIN)" -OutDir "$(ROM_BIN_ARCHIVE_DIR)" -Stamp "$(ROM_BIN_STAMP)"
	@echo "Built $(HIMON_ROM_BIN)."

himon-str8-rom-bin: $(HIMON_STR8_ROM_BIN)
	@echo "Built $(HIMON_STR8_ROM_BIN)."

himon-rom-install-s19: $(HIMON_ROM_INSTALL_S19)
	@echo "Built $(HIMON_ROM_INSTALL_S19)."

himon-str8-rom-install-s19: $(HIMON_STR8_ROM_INSTALL_S19)
	@echo "Built $(HIMON_STR8_ROM_INSTALL_S19)."

himon-str8-himon-update-s19: $(HIMON_STR8_HIMON_UPDATE_S19)
	@echo "Built $(HIMON_STR8_HIMON_UPDATE_S19)."

himon-str8-update str8-himon-update str-himon-str-update: himon-str8-himon-update-s19

str8-top-stage-s19: $(STR8_TOP_STAGE_S19)
	@echo "Built $(STR8_TOP_STAGE_S19)."

str8-topwrite-a: $(STR8_TOPWRITE_A)
	@echo "Built $(STR8_TOPWRITE_A)."

rom-install-s19: himon-str8-rom-install-s19
	@echo "Built primary ROM install S19."

himon-load: $(ROM_LIB) $(HIMON_LOAD_S19)
	@echo "Built $(HIMON_LOAD_S19)."
	@$(MAKE) artifacts

himon-load-bin: himon-load
	@echo [ps] build $(HIMON_LOAD_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_himon_rom_bin.ps1 -MapPath "$(MAP_DIR)/himon-load-c000.map" -S19Path "$(HIMON_LOAD_S19)" -BinPath "$(HIMON_LOAD_BIN)" -TmpVecPath "$(BUILD_DIR)/tmp/himon-load-c000-vectors.bin" -NmiSymbol "SYS_VEC_ENTRY_NMI" -IrqSymbol "SYS_VEC_ENTRY_IRQ_MASTER" -ResetSymbol "START"
	@echo [ps] clean HIMON load vector temp
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(BIN_DIR)/himon-load-c000-vectors.bin') { Remove-Item -LiteralPath '$(BIN_DIR)/himon-load-c000-vectors.bin' -Force }"
	@echo [ps] stamp $(HIMON_LOAD_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/stamp_rom_bin.ps1 -SourcePath "$(HIMON_LOAD_BIN)" -OutDir "$(ROM_BIN_ARCHIVE_DIR)" -Stamp "$(ROM_BIN_STAMP)"
	@echo "Built $(HIMON_LOAD_BIN)."

basic-himon-rom-bin: $(BASIC_HIMON_ROM_BIN)
	@echo "Built $(BASIC_HIMON_ROM_BIN)."

basic-forth-himon-rom-bin: $(BASIC_FORTH_HIMON_ROM_BIN)
	@echo "Built $(BASIC_FORTH_HIMON_ROM_BIN)."

fnv1a-hbstr: $(ROM_LIB) $(FNV1A_HBSTR_S19)
	@echo "Built $(FNV1A_HBSTR_S19)."

str8: $(STR8_S19) $(STR8_RAM_S19) $(STR8_WORKER_S19)
	@echo "Built $(STR8_S19), $(STR8_RAM_S19), and $(STR8_WORKER_S19)."
	@$(MAKE) artifacts

str8-ram: $(STR8_RAM_S19)
	@echo "Built $(STR8_RAM_S19)."
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

life: $(ROM_LIB) $(LIFE_S19) $(LIFE_BIN)
	@echo "Built $(LIFE_S19) and $(LIFE_BIN)."
	@$(MAKE) artifacts

himon-debug-proof: $(ROM_LIB) $(HIMON_DEBUG_PROOF_S19)
	@echo "Built $(HIMON_DEBUG_PROOF_S19)."
	@$(MAKE) artifacts

himon-search-static: $(ROM_LIB) $(HIMON_SEARCH_STATIC_PROOF_S19)
	@echo "Built $(HIMON_SEARCH_STATIC_PROOF_S19)."
	@$(MAKE) artifacts

himon-search-static-proof: himon-search-static

himon-search-proof: $(ROM_LIB) $(HIMON_SEARCH_PROOF_S19)
	@echo "Built $(HIMON_SEARCH_PROOF_S19)."
	@$(MAKE) artifacts

himon-search-flash: $(ROM_LIB) $(HIMON_SEARCH_FLASH_S19)
	@echo "Built $(HIMON_SEARCH_FLASH_S19)."
	@$(MAKE) artifacts

himon-search-for-himon: $(HIMON_SEARCH_FOR_HIMON_OBJ)
	@echo "Native HIMON search port scaffold: $(HIMON_SEARCH_FOR_HIMON_SRC)."
	@echo "Use it with DOC/GUIDES/HIMON/HIMON_SEARCH_IMPLEMENTATION_GUIDE.md and $(HIMON_SEARCH_FLASH_SRC)."
	@$(MAKE) artifacts

hrec-join-proof: $(ROM_LIB) $(HREC_JOIN_PROOF_S19)
	@echo "Built $(HREC_JOIN_PROOF_S19)."
	@$(MAKE) artifacts

pack40-test: $(ROM_LIB) $(PACK40_TEST_S19)
	@echo "Built $(PACK40_TEST_S19)."
	@$(MAKE) artifacts

asm-rjoin-proof: $(ROM_LIB) $(ASM_RJOIN_PROOF_S19)
	@echo "Built $(ASM_RJOIN_PROOF_S19)."
	@$(MAKE) artifacts

bank3-erase: $(BANK3_ERASE_S19)
	@echo "Built $(BANK3_ERASE_S19)."
	@$(MAKE) artifacts

asm-v1-core: $(ASM_V1_CORE_S19)
	@echo "Built $(ASM_V1_CORE_S19)."
	@$(MAKE) artifacts

asm-v1-runtime: $(ASM_V1_RUNTIME_S19)
	@echo "Built $(ASM_V1_RUNTIME_S19)."
	@$(MAKE) artifacts

asm-v1-runtime-smoke: $(ROM_LIB) $(ASM_V1_RUNTIME_SMOKE_S19)
	@echo "Built $(ASM_V1_RUNTIME_SMOKE_S19)."
	@$(MAKE) artifacts

asm-v1-runtime-asmtest: $(ROM_LIB) $(ASM_V1_RUNTIME_ASMTEST_S19)
	@echo "Built $(ASM_V1_RUNTIME_ASMTEST_S19)."
	@$(MAKE) artifacts

asm-v1-runtime-paste: $(ROM_LIB) $(ASM_V1_RUNTIME_PASTE_S19)
	@echo "Built $(ASM_V1_RUNTIME_PASTE_S19)."
	@$(MAKE) artifacts

asm-session-report: $(ROM_LIB) $(ASM_SESSION_REPORT_FLASH_S19) $(ASM_SESSION_REPORT_S19) $(ASM_SESSION_REPORT_AP_BIN) $(ASM_SESSION_REPORT_A_FLASH) $(ASM_SESSION_REPORT_A_RUNTIME)
	@echo "Built $(ASM_SESSION_REPORT_FLASH_S19), $(ASM_SESSION_REPORT_S19), and $(ASM_SESSION_REPORT_AP_BIN)."
	@$(MAKE) artifacts

asm-session-report-ap-bin: $(ASM_SESSION_REPORT_AP_BIN)
	@echo "Built $(ASM_SESSION_REPORT_AP_BIN)."
	@$(MAKE) artifacts

asm-v1-flash: $(ASM_V1_FLASH_S19)
	@echo "Built $(ASM_V1_FLASH_S19)."
	@$(MAKE) artifacts

asm-flash: asm-v1-flash

asmtest-6800-check: $(ASMTEST_CHECK) $(ASMTEST_3000_SAMPLE)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(ASMTEST_CHECK) -SourcePath "$(ASMTEST_3000_SAMPLE)"

asmtest-3000-check: asmtest-6800-check

asmtest-6800-wdc: $(ASMTEST_3000_WDC_S19)
	@$(MAKE) artifacts
	@echo "Built WDC ASMTEST_3000 pasted proof at 6800."
	@echo "Listing: $(ASMTEST_3000_WDC_LST)"
	@echo "Map: $(ASMTEST_3000_WDC_MAP)"
	@echo "S19: $(ASMTEST_3000_WDC_S19)"

asmtest-6800-wdc-check: $(ASMTEST_CHECK) $(ASMTEST_3000_SAMPLE) $(ASMTEST_3000_WDC_S19)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(ASMTEST_CHECK) -SourcePath "$(ASMTEST_3000_SAMPLE)" -S19Path "$(ASMTEST_3000_WDC_S19)"

asmtest-3000-wdc: asmtest-6800-wdc
asmtest-3000-wdc-check: asmtest-6800-wdc-check

asm-opcode-coverage: $(ASM_OPCODE_AUDIT) $(ASM_V1_CORE_SRC)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(ASM_OPCODE_AUDIT) -SourcePath "$(ASM_V1_CORE_SRC)"

asm-test: asm-opcode-coverage asmtest-6800-wdc-check asm-v1-core asm-v1-runtime asm-v1-runtime-smoke asm-v1-runtime-asmtest asm-v1-runtime-paste asm-v1-flash
	@echo "ASM v1 smoke checks passed."

calc-9a00-fnv-proof: $(ROM_LIB) $(CALC_9A00_FNV_PROOF_S19)
	@echo "Built $(CALC_9A00_FNV_PROOF_S19)."
	@$(MAKE) artifacts

rom-append-calc: $(ROM_LIB) $(ROM_APPEND_CALC_S19)
	@echo "Built $(ROM_APPEND_CALC_S19)."
	@$(MAKE) artifacts

fig-forth: $(ROM_LIB) $(FIG_FORTH_S19)
	@echo "Built $(FIG_FORTH_S19)."
	@$(MAKE) artifacts

fig-forth-src: $(FIG_FORTH_SRC)
	@echo "Built local $(FIG_FORTH_SRC)."

fig-forth-c000: $(ROM_LIB) $(FIG_FORTH_C000_S19)
	@echo "Built $(FIG_FORTH_C000_S19)."

fig-forth-str8-update-s19: $(FIG_FORTH_STR8_UPDATE_S19)
	@echo "Built $(FIG_FORTH_STR8_UPDATE_S19)."

msbasic-osi: $(MSBASIC_OSI_S19) $(MSBASIC_OSI_BIN)
	@echo "Built $(MSBASIC_OSI_S19) and $(MSBASIC_OSI_BIN)."

msbasic-osi-src: $(MSBASIC_OSI_SRC)
	@echo "Built local $(MSBASIC_OSI_SRC)."

msbasic-osi-bin: $(MSBASIC_OSI_BIN)
	@echo "Built $(MSBASIC_OSI_BIN)."

msbasic-osi-ram: $(MSBASIC_OSI_RAM_S19)
	@echo "Built $(MSBASIC_OSI_RAM_S19)."

msbasic-osi-c000: $(MSBASIC_OSI_C000_S19)
	@echo "Built $(MSBASIC_OSI_C000_S19)."

msbasic-osi-str8-update-s19: $(MSBASIC_OSI_STR8_UPDATE_S19)
	@echo "Built $(MSBASIC_OSI_STR8_UPDATE_S19)."

call-order: $(CALL_ORDER)
	@echo "Updated $(CALL_ORDER)."

routine-contracts: $(ROUTINE_CONTRACTS)
	@echo "Updated $(ROUTINE_CONTRACTS)."

himon-routine-tree: $(HIMON_ROUTINE_TREE)
	@echo "Updated $(HIMON_ROUTINE_TREE)."

routine-tree: himon-routine-tree

routine-class-diagram: $(ROUTINE_CLASS_DIAGRAM)
	@echo "Updated $(ROUTINE_CLASS_DIAGRAM)."

routine-prefix-map: $(ROUTINE_PREFIX_MAP)
	@echo "Updated $(ROUTINE_PREFIX_MAP)."

routine-word-tree: $(ROUTINE_WORD_TREE)
	@echo "Updated $(ROUTINE_WORD_TREE)."

himon-support-map: $(HIMON_SUPPORT_MAP)
	@echo "Updated $(HIMON_SUPPORT_MAP)."

himon-command-map: $(HIMON_COMMAND_MAP)
	@echo "Updated $(HIMON_COMMAND_MAP)."

hash-routine-map: $(HASH_ROUTINE_MAP)
	@echo "Updated $(HASH_ROUTINE_MAP)."

cmd-flow-map: $(CMD_FLOW_MAP)
	@echo "Updated $(CMD_FLOW_MAP)."

stack-depth-map: $(STACK_DEPTH_MAP)
	@echo "Updated $(STACK_DEPTH_MAP)."

interrupt-vector-map: $(INTERRUPT_VECTOR_MAP)
	@echo "Updated $(INTERRUPT_VECTOR_MAP)."

irq-vector-map: interrupt-vector-map

map-of-maps: $(MAP_OF_MAPS)
	@echo "Updated $(MAP_OF_MAPS)."

routine-graph-insights: $(ROUTINE_GRAPH_INSIGHTS)
	@echo "Updated $(ROUTINE_GRAPH_INSIGHTS)."

routine-components: $(ROUTINE_COMPONENTS)
	@echo "Updated $(ROUTINE_COMPONENTS)."

routine-hash-comments: $(ROUTINE_HASH_COMMENTS_GEN) $(CALL_ORDER_SRC)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(ROUTINE_HASH_COMMENTS_GEN) -Src .
	@echo "Updated routine HASH comments in .asm files."

edge-docs: $(EDGE_DOCS)
	@echo "Updated edge docs: $(EDGE_DOCS)."

docs: $(GENERATED_DOCS) edge-docs
	@echo "Updated docs: $(GENERATED_DOCS)."

docs-watch:
	powershell -NoProfile -ExecutionPolicy Bypass -File $(DOCS_WATCH) -Src . -OutDir $(DOC_GENERATED_DIR)

docs-html:
	powershell -NoProfile -ExecutionPolicy Bypass -File $(DOCS_HTML_GEN) -RepoRoot .. -OutDir $(DOC_HTML_DIR)

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

bin-check:
	powershell -NoProfile -ExecutionPolicy Bypass -File $(BIN_CHECK) -BinDir "$(BIN_DIR)"

# Build shared module library independently.
rom: $(ROM_LIB)
	@echo "Built $(ROM_LIB)."
	@$(MAKE) artifacts

testing: $(TEST_LIB)
	@echo "Built $(TEST_LIB)."

$(HIMON_S19): $(HIMON_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMON_LINKFLAGS) $(HIMON_S19) $(HIMON_OBJ) -L $(BUILD_DIR)\lib\rom

$(HIMON_LOAD_S19): $(HIMON_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMON_LOAD_LINKFLAGS) $(HIMON_LOAD_S19) $(HIMON_OBJ) -L $(BUILD_DIR)\lib\rom

$(HIMON_ROM_S19): $(HIMON_ROM_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMON_ROM_LINKFLAGS) $(HIMON_ROM_S19) $(HIMON_ROM_OBJ) -L $(BUILD_DIR)\lib\rom

$(FNV1A_HBSTR_S19): $(FNV1A_HBSTR_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(FNV1A_HBSTR_LINKFLAGS) $(FNV1A_HBSTR_S19) $(FNV1A_HBSTR_OBJ) -L $(BUILD_DIR)\lib\rom

$(STR8_S19): $(STR8_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(STR8_LINKFLAGS) $(STR8_S19) $(STR8_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$F000 in $(STR8_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(STR8_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S903F0000C'; Set-Content -Path $$p -Value $$lines"

$(STR8_WORKER_S19): $(STR8_WORKER_OBJ)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(STR8_WORKER_LINKFLAGS) $(STR8_WORKER_S19) $(STR8_WORKER_OBJ)
	@echo [ps] set S9 start $$0200 in $(STR8_WORKER_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(STR8_WORKER_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9030200FA'; Set-Content -Path $$p -Value $$lines"

$(STR8_RAM_OBJ): $(STR8_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) -DSTR8_RAM_PROOF $<
	@if exist $(subst /,\,$(<:.asm=.obj)) move /Y $(subst /,\,$(<:.asm=.obj)) $(subst /,\,$@)

$(STR8_RAM_S19): $(STR8_RAM_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(STR8_RAM_LINKFLAGS) $(STR8_RAM_S19) $(STR8_RAM_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$3000 in $(STR8_RAM_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(STR8_RAM_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9033000CC'; Set-Content -Path $$p -Value $$lines"

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
	@echo [ps] set S9 start $$3000 in $(TFLASH_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(TFLASH_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9033000CC'; Set-Content -Path $$p -Value $$lines"

$(LIFE_S19): $(LIFE_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(TEST_LINKFLAGS) $(LIFE_S19) $(LIFE_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$2000 in $(LIFE_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(LIFE_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9032000DC'; Set-Content -Path $$p -Value $$lines"

$(LIFE_BIN): $(LIFE_S19)
	@if not exist $(subst /,\,$(BIN_DIR)) mkdir $(subst /,\,$(BIN_DIR))
	@echo [ps] build $(LIFE_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$srecCat = (Get-Command srec_cat -ErrorAction Stop).Source; & $$srecCat '$(LIFE_S19)' -motorola -crop 0x2000 0x3000 -offset -0x2000 -o '$(LIFE_BIN)' -binary; if ($$LASTEXITCODE -ne 0) { exit $$LASTEXITCODE }; $$bin = [System.IO.File]::ReadAllBytes('$(LIFE_BIN)'); Write-Host ('BIN                      = {0}' -f '$(LIFE_BIN)'); Write-Host ('Load address/bytes       = 2000/{0}' -f $$bin.Length)"

$(HIMON_DEBUG_PROOF_S19): $(HIMON_DEBUG_PROOF_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMON_DEBUG_PROOF_LINKFLAGS) $(HIMON_DEBUG_PROOF_S19) $(HIMON_DEBUG_PROOF_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$3000 in $(HIMON_DEBUG_PROOF_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(HIMON_DEBUG_PROOF_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9033000CC'; Set-Content -Path $$p -Value $$lines"

$(HIMON_SEARCH_STATIC_PROOF_S19): $(HIMON_SEARCH_STATIC_PROOF_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMON_SEARCH_STATIC_PROOF_LINKFLAGS) $(HIMON_SEARCH_STATIC_PROOF_S19) $(HIMON_SEARCH_STATIC_PROOF_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$3000 in $(HIMON_SEARCH_STATIC_PROOF_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(HIMON_SEARCH_STATIC_PROOF_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9033000CC'; Set-Content -Path $$p -Value $$lines"

$(HIMON_SEARCH_PROOF_S19): $(HIMON_SEARCH_PROOF_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMON_SEARCH_PROOF_LINKFLAGS) $(HIMON_SEARCH_PROOF_S19) $(HIMON_SEARCH_PROOF_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$3000 in $(HIMON_SEARCH_PROOF_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(HIMON_SEARCH_PROOF_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9033000CC'; Set-Content -Path $$p -Value $$lines"

$(HIMON_SEARCH_FLASH_S19): $(HIMON_SEARCH_FLASH_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HIMON_SEARCH_FLASH_LINKFLAGS) $(HIMON_SEARCH_FLASH_S19) $(HIMON_SEARCH_FLASH_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$BB8C in $(HIMON_SEARCH_FLASH_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(HIMON_SEARCH_FLASH_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S903BB8CB5'; Set-Content -Path $$p -Value $$lines"

$(HREC_JOIN_PROOF_S19): $(HREC_JOIN_PROOF_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(HREC_JOIN_PROOF_LINKFLAGS) $(HREC_JOIN_PROOF_S19) $(HREC_JOIN_PROOF_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$4000 in $(HREC_JOIN_PROOF_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(HREC_JOIN_PROOF_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9034000BC'; Set-Content -Path $$p -Value $$lines"

$(PACK40_TEST_S19): $(PACK40_TEST_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(PACK40_TEST_LINKFLAGS) $(PACK40_TEST_S19) $(PACK40_TEST_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$3000 in $(PACK40_TEST_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(PACK40_TEST_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9033000CC'; Set-Content -Path $$p -Value $$lines"

$(PACK40_UTIL_OBJ): $(PACK40_UTIL_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.obj))' -Destination '$(subst /,\,$@)' -Force"

$(PACK40_TEST_OBJ): $(PACK40_TEST_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.obj))' -Destination '$(subst /,\,$@)' -Force"

$(ASM_RJOIN_PROOF_S19): $(ASM_RJOIN_PROOF_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(ASM_RJOIN_PROOF_LINKFLAGS) $(ASM_RJOIN_PROOF_S19) $(ASM_RJOIN_PROOF_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$3000 in $(ASM_RJOIN_PROOF_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(ASM_RJOIN_PROOF_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9033000CC'; Set-Content -Path $$p -Value $$lines"

$(BANK3_ERASE_S19): $(BANK3_ERASE_OBJ)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(BANK3_ERASE_LINKFLAGS) $(BANK3_ERASE_S19) $(BANK3_ERASE_OBJ)
	@echo [ps] set S9 start $$3000 in $(BANK3_ERASE_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(BANK3_ERASE_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9033000CC'; Set-Content -Path $$p -Value $$lines"

$(ASM_V1_CORE_S19): $(ASM_V1_CORE_OBJ)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(ASM_V1_CORE_LINKFLAGS) $(ASM_V1_CORE_S19) $(ASM_V1_CORE_OBJ)
	@echo [ps] set S9 start $$2000 in $(ASM_V1_CORE_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(ASM_V1_CORE_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9032000DC'; Set-Content -Path $$p -Value $$lines"

$(ASM_V1_CORE_OBJ): $(ASM_V1_CORE_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) -DASM_PACKAGE_ENABLED -DASM_PACKAGE_CHECK_ENABLED $<
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.obj))' -Destination '$(subst /,\,$@)' -Force"

$(ASM_V1_RUNTIME_OBJ): $(ASM_V1_CORE_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) -DASM_RUNTIME_ONLY $<
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.obj))' -Destination '$(subst /,\,$@)' -Force"

$(ASM_V1_RUNTIME_SMOKE_OBJ): $(ASM_V1_RUNTIME_SMOKE_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.obj))' -Destination '$(subst /,\,$@)' -Force"

$(ASM_V1_RUNTIME_ASMTEST_OBJ): $(ASM_V1_RUNTIME_ASMTEST_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.obj))' -Destination '$(subst /,\,$@)' -Force"

$(ASM_V1_RUNTIME_PASTE_OBJ): $(ASM_V1_RUNTIME_PASTE_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.obj))' -Destination '$(subst /,\,$@)' -Force"

$(ASM_SESSION_REPORT_INC): $(ASM_V1_FLASH_S19) $(ASM_SESSION_REPORT_INC_GEN)
	@if not exist $(subst /,\,$(INC_DIR)) mkdir $(subst /,\,$(INC_DIR))
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$map = if (Test-Path -LiteralPath '$(S19_DIR)/asm-v1-flash-8000.map') { '$(S19_DIR)/asm-v1-flash-8000.map' } elseif (Test-Path -LiteralPath '$(MAP_DIR)/asm-v1-flash-8000.map') { '$(MAP_DIR)/asm-v1-flash-8000.map' } else { throw 'asm-v1-flash-8000.map not found' }; & '$(ASM_SESSION_REPORT_INC_GEN)' -MapPath $$map -OutPath '$(ASM_SESSION_REPORT_INC)'"

$(ASM_SESSION_REPORT_A_FLASH): $(ASM_SESSION_REPORT_INC) $(ASM_SESSION_REPORT_INC_GEN)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$map = if (Test-Path -LiteralPath '$(S19_DIR)/asm-v1-flash-8000.map') { '$(S19_DIR)/asm-v1-flash-8000.map' } elseif (Test-Path -LiteralPath '$(MAP_DIR)/asm-v1-flash-8000.map') { '$(MAP_DIR)/asm-v1-flash-8000.map' } else { throw 'asm-v1-flash-8000.map not found' }; & '$(ASM_SESSION_REPORT_INC_GEN)' -MapPath $$map -OutPath '$(ASM_SESSION_REPORT_INC)' -AsmNativeFlashOut '$(ASM_SESSION_REPORT_A_FLASH)'"

$(ASM_SESSION_REPORT_A_RUNTIME): $(ASM_SESSION_REPORT_INC) $(ASM_SESSION_REPORT_INC_GEN)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$map = if (Test-Path -LiteralPath '$(S19_DIR)/asm-v1-flash-8000.map') { '$(S19_DIR)/asm-v1-flash-8000.map' } elseif (Test-Path -LiteralPath '$(MAP_DIR)/asm-v1-flash-8000.map') { '$(MAP_DIR)/asm-v1-flash-8000.map' } else { throw 'asm-v1-flash-8000.map not found' }; & '$(ASM_SESSION_REPORT_INC_GEN)' -MapPath $$map -OutPath '$(ASM_SESSION_REPORT_INC)' -AsmNativeRuntimeOut '$(ASM_SESSION_REPORT_A_RUNTIME)'"

$(ASM_SESSION_REPORT_OBJ): $(ASM_SESSION_REPORT_SRC) $(ASM_SESSION_REPORT_INC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.obj))' -Destination '$(subst /,\,$@)' -Force"

$(ASM_V1_FLASH_OBJ): $(ASM_V1_FLASH_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.obj))' -Destination '$(subst /,\,$@)' -Force"

$(ASM_V1_FLASH_RUNTIME_OBJ): $(ASM_V1_CORE_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) -DASM_RUNTIME_ONLY -DASM_FLASH_RUNTIME -DASM_PACKAGE_ENABLED $<
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.obj))' -Destination '$(subst /,\,$@)' -Force"

$(ASM_V1_RUNTIME_S19): $(ASM_V1_RUNTIME_OBJ)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(ASM_V1_RUNTIME_LINKFLAGS) $(ASM_V1_RUNTIME_S19) $(ASM_V1_RUNTIME_OBJ)
	@echo [ps] set S9 start $$2000 in $(ASM_V1_RUNTIME_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(ASM_V1_RUNTIME_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9032000DC'; Set-Content -Path $$p -Value $$lines"

$(ASM_V1_RUNTIME_SMOKE_S19): $(ASM_V1_RUNTIME_SMOKE_OBJ) $(ASM_V1_RUNTIME_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(ASM_V1_RUNTIME_SMOKE_LINKFLAGS) $(ASM_V1_RUNTIME_SMOKE_S19) $(ASM_V1_RUNTIME_SMOKE_OBJ) $(ASM_V1_RUNTIME_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$2000 in $(ASM_V1_RUNTIME_SMOKE_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(ASM_V1_RUNTIME_SMOKE_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9032000DC'; Set-Content -Path $$p -Value $$lines"

$(ASM_V1_RUNTIME_ASMTEST_S19): $(ASM_V1_RUNTIME_ASMTEST_OBJ) $(ASM_V1_RUNTIME_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(ASM_V1_RUNTIME_ASMTEST_LINKFLAGS) $(ASM_V1_RUNTIME_ASMTEST_S19) $(ASM_V1_RUNTIME_ASMTEST_OBJ) $(ASM_V1_RUNTIME_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$2000 in $(ASM_V1_RUNTIME_ASMTEST_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(ASM_V1_RUNTIME_ASMTEST_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9032000DC'; Set-Content -Path $$p -Value $$lines"

$(ASM_V1_RUNTIME_PASTE_S19): $(ASM_V1_RUNTIME_PASTE_OBJ) $(ASM_V1_RUNTIME_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(ASM_V1_RUNTIME_PASTE_LINKFLAGS) $(ASM_V1_RUNTIME_PASTE_S19) $(ASM_V1_RUNTIME_PASTE_OBJ) $(ASM_V1_RUNTIME_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$2000 in $(ASM_V1_RUNTIME_PASTE_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(ASM_V1_RUNTIME_PASTE_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9032000DC'; Set-Content -Path $$p -Value $$lines"

$(ASM_SESSION_REPORT_S19): $(ASM_SESSION_REPORT_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(ASM_SESSION_REPORT_LINKFLAGS) $(ASM_SESSION_REPORT_S19) $(ASM_SESSION_REPORT_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$7000 in $(ASM_SESSION_REPORT_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(ASM_SESSION_REPORT_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S90370008C'; Set-Content -Path $$p -Value $$lines"
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$map = if (Test-Path -LiteralPath '$(S19_DIR)/asm-session-report-7000.map') { '$(S19_DIR)/asm-session-report-7000.map' } elseif (Test-Path -LiteralPath '$(MAP_DIR)/asm-session-report-7000.map') { '$(MAP_DIR)/asm-session-report-7000.map' } else { throw 'asm-session-report-7000.map not found' }; $$m = Select-String -Path $$map -Pattern '^\s*([0-9A-Fa-f]{8})\s+_END_DATA\s*$$' | Select-Object -First 1; if (-not $$m) { throw '_END_DATA not found in asm-session-report map' }; $$end = [Convert]::ToInt32($$m.Matches[0].Groups[1].Value.Substring(4), 16); if ($$end -gt 0x7A00) { throw ('asm-session-report crosses 7A00: _END_DATA={0:X4}' -f $$end) }; Write-Host ('asm-session-report end = {0:X4} (limit 7A00)' -f $$end)"

$(ASM_SESSION_REPORT_FLASH_S19): $(ASM_SESSION_REPORT_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(ASM_SESSION_REPORT_FLASH_LINKFLAGS) $(ASM_SESSION_REPORT_FLASH_S19) $(ASM_SESSION_REPORT_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$4800 in $(ASM_SESSION_REPORT_FLASH_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(ASM_SESSION_REPORT_FLASH_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9034800B4'; Set-Content -Path $$p -Value $$lines"
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$map = if (Test-Path -LiteralPath '$(S19_DIR)/asm-session-report-4800.map') { '$(S19_DIR)/asm-session-report-4800.map' } elseif (Test-Path -LiteralPath '$(MAP_DIR)/asm-session-report-4800.map') { '$(MAP_DIR)/asm-session-report-4800.map' } else { throw 'asm-session-report-4800.map not found' }; $$m = Select-String -Path $$map -Pattern '^\s*([0-9A-Fa-f]{8})\s+_END_DATA\s*$$' | Select-Object -First 1; if (-not $$m) { throw '_END_DATA not found in asm-session-report flash map' }; $$end = [Convert]::ToInt32($$m.Matches[0].Groups[1].Value.Substring(4), 16); if ($$end -gt 0x5000) { throw ('asm-session-report flash crosses 5000: _END_DATA={0:X4}' -f $$end) }; Write-Host ('asm-session-report flash end = {0:X4} (limit 5000)' -f $$end)"

$(ASM_SESSION_REPORT_AP_BIN): $(ASM_SESSION_REPORT_FLASH_S19) $(ASM_SESSION_REPORT_AP_GEN)
	@echo [ps] build $(ASM_SESSION_REPORT_AP_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File $(ASM_SESSION_REPORT_AP_GEN) -S19Path "$(ASM_SESSION_REPORT_FLASH_S19)" -MapPath "$(S19_DIR)/asm-session-report-4800.map" -PackagePath "$(ASM_SESSION_REPORT_AP_BIN)" -BaseAddress 18432 -EntrySymbol "START" -ExportName "START"

$(ASM_V1_FLASH_S19): $(ASM_V1_FLASH_OBJ) $(ASM_V1_FLASH_RUNTIME_OBJ)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(ASM_V1_FLASH_LINKFLAGS) $(ASM_V1_FLASH_S19) $(ASM_V1_FLASH_OBJ) $(ASM_V1_FLASH_RUNTIME_OBJ)
	@echo [ps] set S9 start from START in $(ASM_V1_FLASH_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$map = if (Test-Path -LiteralPath '$(S19_DIR)/asm-v1-flash-8000.map') { '$(S19_DIR)/asm-v1-flash-8000.map' } elseif (Test-Path -LiteralPath '$(MAP_DIR)/asm-v1-flash-8000.map') { '$(MAP_DIR)/asm-v1-flash-8000.map' } else { throw 'asm-v1-flash-8000.map not found' }; $$m = Select-String -Path $$map -Pattern '^\s*([0-9A-Fa-f]{8})\s+START\s*$$' | Select-Object -First 1; if (-not $$m) { throw 'START not found in map' }; $$addr = [Convert]::ToInt32($$m.Matches[0].Groups[1].Value.Substring(4), 16); $$sum = 3 + (($$addr -shr 8) -band 255) + ($$addr -band 255); $$chk = ($$sum -bxor 255) -band 255; $$rec = ('S903{0:X4}{1:X2}' -f $$addr, $$chk); $$lines = Get-Content -Path '$(ASM_V1_FLASH_S19)'; $$lines[-1] = $$rec; Set-Content -Path '$(ASM_V1_FLASH_S19)' -Value $$lines"
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$map = if (Test-Path -LiteralPath '$(S19_DIR)/asm-v1-flash-8000.map') { '$(S19_DIR)/asm-v1-flash-8000.map' } elseif (Test-Path -LiteralPath '$(MAP_DIR)/asm-v1-flash-8000.map') { '$(MAP_DIR)/asm-v1-flash-8000.map' } else { throw 'asm-v1-flash-8000.map not found' }; $$m = Select-String -Path $$map -Pattern '^\s*([0-9A-Fa-f]{8})\s+_END_DATA\s*$$' | Select-Object -First 1; if (-not $$m) { throw '_END_DATA not found in map' }; $$end = [Convert]::ToInt32($$m.Matches[0].Groups[1].Value.Substring(4), 16); $$limit = 0xC000; $$minRoom = 0x0200; $$room = $$limit - $$end; if ($$room -lt $$minRoom) { throw ('asm-v1-flash too close to C000: _END_DATA={0:X4} room={1:X4} min={2:X4}' -f $$end, $$room, $$minRoom) }; Write-Host ('asm-v1-flash headroom to C000 = {0:X4} (_END_DATA={1:X4})' -f $$room, $$end)"

$(CALC_9A00_FNV_PROOF_S19): $(CALC_9A00_FNV_PROOF_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(CALC_9A00_FNV_PROOF_LINKFLAGS) $(CALC_9A00_FNV_PROOF_S19) $(CALC_9A00_FNV_PROOF_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$9A08 in $(CALC_9A00_FNV_PROOF_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(CALC_9A00_FNV_PROOF_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S9039A085A'; Set-Content -Path $$p -Value $$lines"

$(ROM_APPEND_CALC_S19): $(ROM_APPEND_CALC_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(ROM_APPEND_CALC_LINKFLAGS) $(ROM_APPEND_CALC_S19) $(ROM_APPEND_CALC_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$B804 in $(ROM_APPEND_CALC_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(ROM_APPEND_CALC_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S903B80440'; Set-Content -Path $$p -Value $$lines"

$(FIG_FORTH_S19): $(FIG_FORTH_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(FIG_FORTH_LINKFLAGS) $(FIG_FORTH_S19) $(FIG_FORTH_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$A008 in $(FIG_FORTH_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(FIG_FORTH_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S903A00854'; Set-Content -Path $$p -Value $$lines"

$(FIG_FORTH_C000_S19): $(FIG_FORTH_C000_OBJ) $(ROM_LIB)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(FIG_FORTH_C000_LINKFLAGS) $(FIG_FORTH_C000_S19) $(FIG_FORTH_C000_OBJ) -L $(BUILD_DIR)\lib\rom
	@echo [ps] set S9 start $$C000 in $(FIG_FORTH_C000_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(FIG_FORTH_C000_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S903C0003C'; Set-Content -Path $$p -Value $$lines"

$(FIG_FORTH_STR8_UPDATE_S19): $(FIG_FORTH_C000_S19)
	@echo [ps] build $(FIG_FORTH_STR8_UPDATE_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$src = '$(FIG_FORTH_C000_S19)'; $$dst = '$(FIG_FORTH_STR8_UPDATE_S19)'; $$out = New-Object System.Collections.Generic.List[string]; foreach ($$raw in Get-Content -Path $$src) { $$line = $$raw.Trim(); if ($$line.Length -eq 0) { continue }; if ($$line.StartsWith('S1', [System.StringComparison]::Ordinal)) { $$addr = [Convert]::ToInt32($$line.Substring(4, 4), 16); if ($$addr -lt 0xC000 -or $$addr -gt 0xEFFF) { throw ('fig-Forth STR8 U record outside C000-EFFF: ' + $$line) }; $$out.Add($$line); continue }; if ($$line.StartsWith('S9', [System.StringComparison]::Ordinal)) { $$out.Add('S903C0003C'); continue }; if ($$line.StartsWith('S0', [System.StringComparison]::Ordinal)) { continue }; throw ('Unsupported record in fig-Forth STR8 U stream: ' + $$line) }; if ($$out.Count -eq 0) { throw 'No records for fig-Forth STR8 U stream' }; [System.IO.File]::WriteAllLines($$dst, $$out, [System.Text.Encoding]::ASCII); Write-Host ('STR8 U S19              = {0}' -f $$dst); Write-Host ('Address range           = C000-EFFF'); Write-Host ('S9 start                = C000'); Write-Host ('Records                 = {0}' -f $$out.Count)"

$(FIG_FORTH_SRC): $(FIG_FORTH_INPUT) tools/emit_fig_forth_wdc.ps1 $(LOCAL_PROVENANCE)
	@if not exist $(subst /,\,$(dir $(FIG_FORTH_SRC))) mkdir $(subst /,\,$(dir $(FIG_FORTH_SRC)))
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/emit_fig_forth_wdc.ps1 -SourcePath "$(FIG_FORTH_INPUT)" -OutPath "$(FIG_FORTH_SRC)"
	powershell -NoProfile -ExecutionPolicy Bypass -File $(LOCAL_PROVENANCE) -Name "fig-forth" -LocalHome "$(FIG_FORTH_HOME)" -SourcePath "$(FIG_FORTH_INPUT)" -GeneratedPath "$(FIG_FORTH_SRC)" -ToolPath "tools/emit_fig_forth_wdc.ps1" -Note "Generated local WDC-flavored fig-Forth source."

$(FIG_FORTH_C000_SRC): $(FIG_FORTH_INPUT) tools/emit_fig_forth_wdc.ps1 $(LOCAL_PROVENANCE)
	@if not exist $(subst /,\,$(dir $(FIG_FORTH_C000_SRC))) mkdir $(subst /,\,$(dir $(FIG_FORTH_C000_SRC)))
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/emit_fig_forth_wdc.ps1 -SourcePath "$(FIG_FORTH_INPUT)" -OutPath "$(FIG_FORTH_C000_SRC)" -MonitorExitAddress 61440 -BootEntryAtBase
	powershell -NoProfile -ExecutionPolicy Bypass -File $(LOCAL_PROVENANCE) -Name "fig-forth-c000" -LocalHome "$(FIG_FORTH_HOME)" -SourcePath "$(FIG_FORTH_INPUT)" -GeneratedPath "$(FIG_FORTH_C000_SRC)" -ToolPath "tools/emit_fig_forth_wdc.ps1" -Note "Generated bootable C000 fig-Forth source for STR8 U experiments."

$(MSBASIC_OSI_S19): $(MSBASIC_OSI_OBJ)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(MSBASIC_OSI_LINKFLAGS) $(MSBASIC_OSI_S19) $(MSBASIC_OSI_OBJ)
	@echo [ps] set S9 start from COLD_START in $(MSBASIC_OSI_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$map = if (Test-Path -LiteralPath '$(S19_DIR)/msbasic-osi-8000.map') { '$(S19_DIR)/msbasic-osi-8000.map' } elseif (Test-Path -LiteralPath '$(MAP_DIR)/msbasic-osi-8000.map') { '$(MAP_DIR)/msbasic-osi-8000.map' } else { throw 'msbasic-osi-8000.map not found' }; $$m = Select-String -Path $$map -Pattern '^\s*([0-9A-Fa-f]{8})\s+COLD_START\s*$$' | Select-Object -First 1; if (-not $$m) { throw 'COLD_START not found in map' }; $$addr = [Convert]::ToInt32($$m.Matches[0].Groups[1].Value.Substring(4), 16); $$sum = 3 + (($$addr -shr 8) -band 255) + ($$addr -band 255); $$chk = ($$sum -bxor 255) -band 255; $$rec = ('S903{0:X4}{1:X2}' -f $$addr, $$chk); $$lines = Get-Content -Path '$(MSBASIC_OSI_S19)'; $$lines[-1] = $$rec; Set-Content -Path '$(MSBASIC_OSI_S19)' -Value $$lines"

$(MSBASIC_OSI_BIN): $(MSBASIC_OSI_S19) tools/build_msbasic_osi_bin.ps1 tools/stamp_rom_bin.ps1 $(BIN_POLICY)
	@echo [ps] build $(MSBASIC_OSI_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_msbasic_osi_bin.ps1 -MapPath "$(S19_DIR)/msbasic-osi-8000.map" -S19Path "$(MSBASIC_OSI_S19)" -BinPath "$(MSBASIC_OSI_BIN)"
	@echo [ps] stamp $(MSBASIC_OSI_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/stamp_rom_bin.ps1 -SourcePath "$(MSBASIC_OSI_BIN)" -OutDir "$(ROM_BIN_ARCHIVE_DIR)" -Stamp "$(ROM_BIN_STAMP)"

$(BASIC_HIMON_ROM_BIN): $(MSBASIC_OSI_S19) $(HIMON_ROM_S19) tools/build_basic_himon_rom_bin.ps1 tools/stamp_rom_bin.ps1
	@echo [ps] build $(BASIC_HIMON_ROM_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_basic_himon_rom_bin.ps1 -MsbasicMapPath "$(S19_DIR)/msbasic-osi-8000.map" -MsbasicS19Path "$(MSBASIC_OSI_S19)" -HimonMapPath "$(S19_DIR)/himon-rom-c000.map" -HimonS19Path "$(HIMON_ROM_S19)" -BinPath "$(BASIC_HIMON_ROM_BIN)" -TmpVecPath "$(BUILD_DIR)/tmp/basic-himon-rom-vectors.bin"
	@echo [ps] stamp $(BASIC_HIMON_ROM_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/stamp_rom_bin.ps1 -SourcePath "$(BASIC_HIMON_ROM_BIN)" -OutDir "$(ROM_BIN_ARCHIVE_DIR)" -Stamp "$(ROM_BIN_STAMP)"

$(BASIC_FORTH_HIMON_ROM_BIN): $(FIG_FORTH_S19) $(MSBASIC_OSI_S19) $(HIMON_ROM_S19) tools/build_basic_forth_himon_rom_bin.ps1 tools/stamp_rom_bin.ps1
	@echo [ps] build $(BASIC_FORTH_HIMON_ROM_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_basic_forth_himon_rom_bin.ps1 -ForthMapPath "$(S19_DIR)/fig-forth-a000.map" -ForthS19Path "$(FIG_FORTH_S19)" -MsbasicMapPath "$(S19_DIR)/msbasic-osi-8000.map" -MsbasicS19Path "$(MSBASIC_OSI_S19)" -HimonMapPath "$(S19_DIR)/himon-rom-c000.map" -HimonS19Path "$(HIMON_ROM_S19)" -BinPath "$(BASIC_FORTH_HIMON_ROM_BIN)"
	@echo [ps] stamp $(BASIC_FORTH_HIMON_ROM_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/stamp_rom_bin.ps1 -SourcePath "$(BASIC_FORTH_HIMON_ROM_BIN)" -OutDir "$(ROM_BIN_ARCHIVE_DIR)" -Stamp "$(ROM_BIN_STAMP)"

$(HIMON_STR8_ROM_BIN): $(HIMON_ROM_S19) $(STR8_S19) $(STR8_WORKER_S19) $(ASM_V1_FLASH_S19) $(ASM_SESSION_REPORT_AP_BIN) tools/build_himon_str8_rom_bin.ps1 tools/stamp_rom_bin.ps1
	@echo [ps] build $(HIMON_STR8_ROM_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_himon_str8_rom_bin.ps1 -HimonMapPath "$(S19_DIR)/himon-rom-c000.map" -HimonS19Path "$(HIMON_ROM_S19)" -Str8MapPath "$(S19_DIR)/str8-f000.map" -Str8S19Path "$(STR8_S19)" -WorkerMapPath "$(S19_DIR)/str8-worker-0200.map" -WorkerS19Path "$(STR8_WORKER_S19)" -AsmMapPath "$(S19_DIR)/asm-v1-flash-8000.map" -AsmS19Path "$(ASM_V1_FLASH_S19)" -ApPackageBinPath "$(ASM_SESSION_REPORT_AP_BIN)" -BinPath "$(HIMON_STR8_ROM_BIN)"
	@echo [ps] stamp $(HIMON_STR8_ROM_BIN)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/stamp_rom_bin.ps1 -SourcePath "$(HIMON_STR8_ROM_BIN)" -OutDir "$(ROM_BIN_ARCHIVE_DIR)" -Stamp "$(ROM_BIN_STAMP)"

$(HIMON_ROM_INSTALL_S19): $(HIMON_ROM_BIN) $(ROM_INSTALL_S19_GEN)
	@echo [ps] build $(HIMON_ROM_INSTALL_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -File $(ROM_INSTALL_S19_GEN) -BinPath "$(HIMON_ROM_BIN)" -S19Path "$(HIMON_ROM_INSTALL_S19)" -BaseAddress 32768

$(HIMON_STR8_ROM_INSTALL_S19): $(HIMON_STR8_ROM_BIN) $(ROM_INSTALL_S19_GEN)
	@echo [ps] build $(HIMON_STR8_ROM_INSTALL_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -File $(ROM_INSTALL_S19_GEN) -BinPath "$(HIMON_STR8_ROM_BIN)" -S19Path "$(HIMON_STR8_ROM_INSTALL_S19)" -BaseAddress 32768

$(HIMON_STR8_HIMON_UPDATE_S19): $(HIMON_STR8_ROM_BIN) $(ROM_INSTALL_S19_GEN)
	@echo [ps] build $(HIMON_STR8_HIMON_UPDATE_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -File $(ROM_INSTALL_S19_GEN) -BinPath "$(HIMON_STR8_ROM_BIN)" -S19Path "$(HIMON_STR8_HIMON_UPDATE_S19)" -BaseAddress 32768 -RangeStart 49152 -RangeEnd 61439 -StartAddress 49152 -OmitAllFFDataRecords

$(STR8_TOP_STAGE_S19): $(HIMON_STR8_ROM_BIN) tools/build_str8_top_stage_s19.ps1
	@echo [ps] build $(STR8_TOP_STAGE_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_str8_top_stage_s19.ps1 -BinPath "$(HIMON_STR8_ROM_BIN)" -S19Path "$(STR8_TOP_STAGE_S19)"

$(STR8_TOPWRITE_A): $(HIMON_STR8_ROM_BIN) $(ASM_V1_FLASH_S19) $(STR8_TOPWRITE_A_GEN)
	@echo [ps] build $(STR8_TOPWRITE_A)
	@powershell -NoProfile -ExecutionPolicy Bypass -File $(STR8_TOPWRITE_A_GEN) -BinPath "$(HIMON_STR8_ROM_BIN)" -AsmMapPath "$(S19_DIR)/asm-v1-flash-8000.map" -OutPath "$(STR8_TOPWRITE_A)"

$(MSBASIC_OSI_RAM_S19): $(MSBASIC_OSI_OBJ)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(MSBASIC_OSI_RAM_LINKFLAGS) $(MSBASIC_OSI_RAM_S19) $(MSBASIC_OSI_OBJ)
	@echo [ps] set S9 start from COLD_START in $(MSBASIC_OSI_RAM_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$map = if (Test-Path -LiteralPath '$(S19_DIR)/msbasic-osi-ram.map') { '$(S19_DIR)/msbasic-osi-ram.map' } elseif (Test-Path -LiteralPath '$(MAP_DIR)/msbasic-osi-ram.map') { '$(MAP_DIR)/msbasic-osi-ram.map' } else { throw 'msbasic-osi-ram.map not found' }; $$m = Select-String -Path $$map -Pattern '^\s*([0-9A-Fa-f]{8})\s+COLD_START\s*$$' | Select-Object -First 1; if (-not $$m) { throw 'COLD_START not found in map' }; $$addr = [Convert]::ToInt32($$m.Matches[0].Groups[1].Value.Substring(4), 16); $$sum = 3 + (($$addr -shr 8) -band 255) + ($$addr -band 255); $$chk = ($$sum -bxor 255) -band 255; $$rec = ('S903{0:X4}{1:X2}' -f $$addr, $$chk); $$lines = Get-Content -Path '$(MSBASIC_OSI_RAM_S19)'; $$lines[-1] = $$rec; Set-Content -Path '$(MSBASIC_OSI_RAM_S19)' -Value $$lines"

$(MSBASIC_OSI_C000_S19): $(MSBASIC_OSI_C000_OBJ)
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) $(MSBASIC_OSI_C000_LINKFLAGS) $(MSBASIC_OSI_C000_S19) $(MSBASIC_OSI_C000_OBJ)
	@echo [ps] set S9 start $$C000 in $(MSBASIC_OSI_C000_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(MSBASIC_OSI_C000_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S903C0003C'; Set-Content -Path $$p -Value $$lines"

$(MSBASIC_OSI_STR8_UPDATE_S19): $(MSBASIC_OSI_C000_S19)
	@echo [ps] build $(MSBASIC_OSI_STR8_UPDATE_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$src = '$(MSBASIC_OSI_C000_S19)'; $$dst = '$(MSBASIC_OSI_STR8_UPDATE_S19)'; $$out = New-Object System.Collections.Generic.List[string]; foreach ($$raw in Get-Content -Path $$src) { $$line = $$raw.Trim(); if ($$line.Length -eq 0) { continue }; if ($$line.StartsWith('S1', [System.StringComparison]::Ordinal)) { $$addr = [Convert]::ToInt32($$line.Substring(4, 4), 16); if ($$addr -lt 0xC000 -or $$addr -gt 0xEFFF) { throw ('MS BASIC STR8 U record outside C000-EFFF: ' + $$line) }; $$out.Add($$line); continue }; if ($$line.StartsWith('S9', [System.StringComparison]::Ordinal)) { $$out.Add('S903C0003C'); continue }; if ($$line.StartsWith('S0', [System.StringComparison]::Ordinal)) { continue }; throw ('Unsupported record in MS BASIC STR8 U stream: ' + $$line) }; if ($$out.Count -eq 0) { throw 'No records for MS BASIC STR8 U stream' }; [System.IO.File]::WriteAllLines($$dst, $$out, [System.Text.Encoding]::ASCII); Write-Host ('STR8 U S19              = {0}' -f $$dst); Write-Host ('Address range           = C000-EFFF'); Write-Host ('S9 start                = C000'); Write-Host ('Records                 = {0}' -f $$out.Count)"

$(FTDI_DRV_INC): $(FTDI_DRV_SRC)
	@if not exist $(subst /,\,$(dir $(FTDI_DRV_INC))) mkdir $(subst /,\,$(dir $(FTDI_DRV_INC)))
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$src = '$(FTDI_DRV_SRC)'; $$dst = '$(FTDI_DRV_INC)'; $$defs = Select-String -Path $$src -Pattern '^\s*XDEF\s+PIN_FTDI_[A-Z0-9_]+' | ForEach-Object { [Regex]::Match($$_.Line, 'PIN_FTDI_[A-Z0-9_]+').Value } | Select-Object -Unique; $$lines = @('; -------------------------------------------------------------------------','; ftdi-drv.inc','; Public include interface for FTDI L0 driver entry points.','; AUTO-GENERATED by Makefile from LIB/ftdi/ftdi-drv.asm.','; -------------------------------------------------------------------------','') + ($$defs | ForEach-Object { ('                        XREF            ' + $$_) }); Set-Content -Path $$dst -Value $$lines"

$(TFTDI_OBJ): $(FTDI_DRV_INC)

$(ROM_LIB): $(ROM_OBJ)
	@if not exist $(subst /,\,$(BUILD_DIR)\lib) mkdir $(subst /,\,$(BUILD_DIR)\lib)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(ROM_LIB)') { Remove-Item -LiteralPath '$(ROM_LIB)' -Force }"
	$(LIB) -A $(ROM_LIB) $(ROM_OBJ)
	@if exist LIB.TMP move /Y LIB.TMP $(ROM_LIB)

$(TEST_LIB): $(TEST_LIB_OBJ)
	@if not exist $(subst /,\,$(BUILD_DIR)\lib) mkdir $(subst /,\,$(BUILD_DIR)\lib)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(TEST_LIB)') { Remove-Item -LiteralPath '$(TEST_LIB)' -Force }"
	$(LIB) -A $(TEST_LIB) $(TEST_LIB_OBJ)
	@if exist LIB.TMP move /Y LIB.TMP $(TEST_LIB)

$(MSBASIC_OSI_SRC):
	@if not exist $(subst /,\,$(dir $(MSBASIC_OSI_SRC))) mkdir $(subst /,\,$(dir $(MSBASIC_OSI_SRC)))
	$(PYTHON) $(MSBASIC_OSI_GEN) --source-root "$(MSBASIC_SRC_ROOT)" --out "$(MSBASIC_OSI_SRC)"
	powershell -NoProfile -ExecutionPolicy Bypass -File $(LOCAL_PROVENANCE) -Name "msbasic" -LocalHome "$(MSBASIC_HOME)" -SourceRoot "$(MSBASIC_SRC_ROOT)" -GeneratedPath "$(MSBASIC_OSI_SRC)" -ToolPath "$(MSBASIC_OSI_GEN)" -Note "Generated local WDC-flavored OSI MS BASIC source."

$(MSBASIC_OSI_C000_SRC): $(MSBASIC_OSI_C000_GEN)
	@if not exist $(subst /,\,$(dir $(MSBASIC_OSI_C000_SRC))) mkdir $(subst /,\,$(dir $(MSBASIC_OSI_C000_SRC)))
	powershell -NoProfile -ExecutionPolicy Bypass -File $(MSBASIC_OSI_C000_GEN) -SourcePath "$(MSBASIC_OSI_SRC)" -OutPath "$(MSBASIC_OSI_C000_SRC)"
	powershell -NoProfile -ExecutionPolicy Bypass -File $(LOCAL_PROVENANCE) -Name "msbasic-c000" -LocalHome "$(MSBASIC_HOME)" -SourceRoot "$(MSBASIC_SRC_ROOT)" -GeneratedPath "$(MSBASIC_OSI_C000_SRC)" -ToolPath "$(MSBASIC_OSI_C000_GEN)" -Note "Generated bootable C000 OSI MS BASIC source for STR8 U experiments."

$(MSBASIC_OSI_OBJ): $(MSBASIC_OSI_SRC) $(HIMON_ROM_S19) tools/patch_msbasic_himon_addrs.ps1
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/patch_msbasic_himon_addrs.ps1 -SourcePath "$(MSBASIC_OSI_SRC)" -MapPath "$(S19_DIR)/himon-rom-c000.map"
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	@if exist $(subst /,\,$(<:.asm=.obj)) move /Y $(subst /,\,$(<:.asm=.obj)) $(subst /,\,$@)

$(MSBASIC_OSI_C000_OBJ): $(MSBASIC_OSI_C000_SRC) $(STR8_S19) tools/patch_msbasic_himon_addrs.ps1
	powershell -NoProfile -ExecutionPolicy Bypass -File tools/patch_msbasic_himon_addrs.ps1 -SourcePath "$(MSBASIC_OSI_C000_SRC)" -MapPath "$(S19_DIR)/str8-f000.map" -Profile str8
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	@if exist $(subst /,\,$(<:.asm=.obj)) move /Y $(subst /,\,$(<:.asm=.obj)) $(subst /,\,$@)

$(FIG_FORTH_OBJ): $(FIG_FORTH_SRC) $(HIMON_ROM_S19) $(FIG_FORTH_HIMON_PATCH)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(FIG_FORTH_HIMON_PATCH) -SourcePath "$(FIG_FORTH_SRC)" -MapPath "$(S19_DIR)/himon-rom-c000.map"
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	@if exist $(subst /,\,$(<:.asm=.obj)) move /Y $(subst /,\,$(<:.asm=.obj)) $(subst /,\,$@)

$(FIG_FORTH_C000_OBJ): $(FIG_FORTH_C000_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	@if exist $(subst /,\,$(<:.asm=.obj)) move /Y $(subst /,\,$(<:.asm=.obj)) $(subst /,\,$@)

.PHONY: himon-version-stamp
himon-version-stamp: $(HIMON_VERSION_STAMP)
	@powershell -NoProfile -ExecutionPolicy Bypass -File $(HIMON_VERSION_STAMP) -OutPath "$(HIMON_VERSION_INC)" $(HIMON_VISIBLE_STAMP_ARG)

$(HIMON_OBJ) $(HIMON_ROM_OBJ): $(HIMON_INC) himon-version-stamp

$(HIMON_OBJ) $(HIMON_ROM_OBJ): $(HIMON_SRC)
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	@if not exist $(subst /,\,$(LST_DIR)) mkdir $(subst /,\,$(LST_DIR))
	@if not exist $(subst /,\,$(SYM_DIR)) mkdir $(subst /,\,$(SYM_DIR))
	$(ASM) $(ASFLAGS) $<
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(subst /,\,$(<:.asm=.obj))') { Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.obj))' -Destination '$(subst /,\,$@)' -Force }"
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(subst /,\,$(<:.asm=.lst))') { Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.lst))' -Destination '$(subst /,\,$(LST_DIR)/$(@F:.obj=.lst))' -Force }"
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path -LiteralPath '$(subst /,\,$(<:.asm=.sym))') { Copy-Item -LiteralPath '$(subst /,\,$(<:.asm=.sym))' -Destination '$(subst /,\,$(SYM_DIR)/$(@F:.obj=.sym))' -Force }"

$(OBJ_DIR)/%.obj: %.asm
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	$(ASM) $(ASFLAGS) $<
	@if exist $(subst /,\,$*.obj) move /Y $(subst /,\,$*.obj) $(subst /,\,$@)

$(ASMTEST_3000_WDC_OBJ): $(ASMTEST_3000_SAMPLE) Makefile
	@if not exist $(subst /,\,$(dir $@)) mkdir $(subst /,\,$(dir $@))
	@if not exist $(subst /,\,$(LST_DIR)) mkdir $(subst /,\,$(LST_DIR))
	$(ASM) $(ASFLAGS) $<
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '$(subst /,\,$(ASMTEST_3000_WDC_SIDE_OBJ))' -Destination '$(subst /,\,$@)' -Force"
	powershell -NoProfile -ExecutionPolicy Bypass -Command "Copy-Item -LiteralPath '$(subst /,\,$(ASMTEST_3000_WDC_SIDE_LST))' -Destination '$(subst /,\,$(ASMTEST_3000_WDC_LST))' -Force"

$(ASMTEST_3000_WDC_S19): $(ASMTEST_3000_WDC_OBJ) Makefile
	@if not exist $(subst /,\,$(S19_DIR)) mkdir $(subst /,\,$(S19_DIR))
	$(LINKER) -g -s -t -hm19 -j -o $(ASMTEST_3000_WDC_S19) $(ASMTEST_3000_WDC_OBJ)
	@echo [ps] set S9 start $$6800 in $(ASMTEST_3000_WDC_S19)
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$p = '$(ASMTEST_3000_WDC_S19)'; $$lines = Get-Content -Path $$p; $$lines[-1] = 'S903680094'; Set-Content -Path $$p -Value $$lines"

$(GENERATED_DOCS): $(CALL_ORDER_SRC) $(DOCS_GEN)
	powershell -NoProfile -ExecutionPolicy Bypass -Command "New-Item -ItemType Directory -Force -Path '$(DOC_GENERATED_DIR)' | Out-Null"
	powershell -NoProfile -ExecutionPolicy Bypass -File $(DOCS_GEN) -Src . -OutDir $(DOC_GENERATED_DIR)

$(GUIDE_HIMON_EDGE_DUMP): HIMON/himon.asm $(EDGE_DOCS_GEN)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(EDGE_DOCS_GEN) -SourcePath "HIMON/himon.asm" -OutPath "$@" -Title "HIMON Edge Dump" -DisplaySource "HIMON/himon.asm" -ReadableMap "[HIMON_MAP.md](HIMON_MAP.md)"

$(GUIDE_STR8_EDGE_DUMP): STR8/str8.asm $(EDGE_DOCS_GEN)
	powershell -NoProfile -ExecutionPolicy Bypass -File $(EDGE_DOCS_GEN) -SourcePath "STR8/str8.asm" -OutPath "$@" -Title "STR8 Edge Dump" -DisplaySource "STR8/str8.asm" -ReadableMap "[STR8.md](STR8.md)"

artifacts:
	@echo [ps] sync sidecar artifacts
	@powershell -NoProfile -ExecutionPolicy Bypass -Command "$$pairs = @(@{Ext='lst';Dir='$(LST_DIR)'},@{Ext='sym';Dir='$(SYM_DIR)'},@{Ext='map';Dir='$(MAP_DIR)'},@{Ext='bin';Dir='$(BIN_DIR)'},@{Ext='s19';Dir='$(S19_DIR)'}); foreach ($$p in $$pairs) { New-Item -ItemType Directory -Force -Path $$p.Dir | Out-Null }; foreach ($$p in $$pairs) { $$src = @('$(APPS_DIR)','$(PROOFS_DIR)','$(ASM_DIR)','$(HIMON_DIR)','$(STR8_DIR)','$(TESTS_DIR)','$(LIB_DIR)'); if ($$p.Ext -ne 's19') { $$src += '$(S19_DIR)' }; $$dst = (Resolve-Path $$p.Dir).Path; Get-ChildItem -Recurse -File -Path $$src -Filter ('*.' + $$p.Ext) | Where-Object { $$_.DirectoryName -ne $$dst } | ForEach-Object { Copy-Item -LiteralPath $$_.FullName -Destination (Join-Path $$p.Dir $$_.Name) -Force }; Get-ChildItem -File -Path . -Filter ('*.' + $$p.Ext) | ForEach-Object { Copy-Item -LiteralPath $$_.FullName -Destination (Join-Path $$p.Dir $$_.Name) -Force } }"
	@echo "Synced sidecar artifacts into $(BUILD_DIR)/{lst,sym,map,bin,s19}."

clean:
	-del /f *.obj *.lst *.sym *.map *.bin >nul 2>nul
	powershell -NoProfile -ExecutionPolicy Bypass -Command "$$dirs = @('$(APPS_DIR)','$(PROOFS_DIR)','$(ASM_DIR)','$(HIMON_DIR)','$(STR8_DIR)','$(TESTS_DIR)','$(LIB_DIR)'); foreach ($$d in $$dirs) { if (Test-Path -LiteralPath $$d) { Get-ChildItem -Recurse -File -Path $$d -Include *.obj,*.lst,*.sym,*.map,*.bin | Remove-Item -Force -ErrorAction SilentlyContinue } }"
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

.PHONY: \
	all firmware lab everything proofs apps tests help release release-local \
	himon himon-rom himon-rom-bin himon-str8-rom-bin \
	himon-rom-install-s19 himon-str8-rom-install-s19 \
	himon-str8-himon-update-s19 himon-str8-update str8-himon-update \
	str-himon-str-update str8-top-stage-s19 str8-topwrite-a \
	himon-load himon-load-bin \
	basic-himon-rom-bin basic-forth-himon-rom-bin fnv1a-hbstr \
	str8 str8-ram test-mon test-ftdi-drv test-ftdi-hal test-flash \
	life himon-debug-proof himon-search-static himon-search-static-proof \
	himon-search-proof himon-search-flash himon-search-for-himon \
	hrec-join-proof pack40-test asm-rjoin-proof bank3-erase asm-v1-core \
	asm-v1-runtime asm-v1-runtime-smoke asm-v1-runtime-asmtest \
	asm-v1-runtime-paste asm-session-report asm-session-report-ap-bin asm-v1-flash asm-flash asm-opcode-coverage \
	asmtest-6800-check asmtest-6800-wdc asmtest-6800-wdc-check \
	asmtest-3000-check asmtest-3000-wdc asmtest-3000-wdc-check \
	asm-test calc-9a00-fnv-proof rom-append-calc fig-forth fig-forth-src \
	fig-forth-c000 fig-forth-str8-update-s19 msbasic-osi msbasic-osi-src \
	msbasic-osi-bin msbasic-osi-ram msbasic-osi-c000 \
	msbasic-osi-str8-update-s19 local-homes call-order routine-contracts \
	himon-routine-tree routine-tree routine-class-diagram routine-prefix-map \
	routine-word-tree himon-support-map himon-command-map hash-routine-map \
	cmd-flow-map stack-depth-map interrupt-vector-map irq-vector-map \
	map-of-maps routine-graph-insights routine-components routine-hash-comments \
	edge-docs docs docs-watch docs-html bin-check rom testing artifacts clean realclean \
	upload term
