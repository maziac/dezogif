# Makefile 


# ZX Next Game Framework:
PROJ = dbg_uart_if

ASM = sjasmplus
SED = gsed
PRG_BIN = $(OUT)/$(PROJ).nex

UT = $(OUT)/ut
#UT_NEX_FORMAT = -DNEX_FORMAT
UT_BIN = $(UT).nex

SRC = src
OUT = out
MAIN_ASM = $(SRC)/main.asm 
ASM_FILES = $(wildcard $(SRC)/*.asm)
UT_ASM = $(SRC)/unit_tests/unit_tests.asm 
UT_ASM_FILES = $(wildcard $(SRC)/unit_tests/*.asm) $(ASM_FILES)
#OBJS = $(BIN)/$(notdir $(ASM_FILES:.asm=.obj))
#LABELS_OUT = $(OUT)/$(PROJ).labels
# The assembler output listing file:
LIST_OUT = $(OUT)/$(PROJ).list
# Exports of marked labels
#LABELS_EXPORT = $(SRC)/$(PROJ).inc


all:	default unit_tests

default:	main

clean:
	# clean
	rm -f $(OUT)/*


# Build main program
main:	$(PRG_BIN)

$(PRG_BIN):	$(ASM_FILES) Makefile $(OUT)/
	$(ASM) --inc=$(SRC) --lstlab --lst=$(LIST_OUT) --fullpath -DBIN_FILE=\"$(PRG_BIN)\" $(MAIN_ASM)


# Build the unit tests
unit_tests:	$(UT_BIN)

$(UT_BIN):	$(UT_ASM_FILES) Makefile $(OUT)/
	$(ASM) --inc=$(SRC) --lstlab --lst=$(UT).list --fullpath -DBIN_FILE=\"$(UT_BIN)\" $(UT_ASM)


# Create 'out' folder:
$(OUT)/:
	mkdir -p $@
