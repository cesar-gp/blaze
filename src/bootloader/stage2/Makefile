# ------------ PROJECT DIRECTORIES ------------

DIR_SRC=src
DIR_BUILD=build

# --------------- DEPENDENCIES ----------------

ASM?=nasm
ASM_FLAGS=-f elf

LD?=/opt/i686-elf-gcc/bin/i686-elf-gcc
LD_FLAGS=-T "${DIR_SRC}/linker.ld" -nostdlib
LD_LIBS=-lgcc

# ------------- INPUT AND OUTPUT --------------

IN=${DIR_SRC}/stage2.s
OBJ=${DIR_BUILD}/stage2.elf
OUT=${DIR_BUILD}/stage2.bin

# ------------- COMPLETE TARGETS --------------
#
# Targets that are meant for the user to call,
# like 'make all' and 'make clean'.

all: clean ${OUT}

# ----------- SOURCE BUILD TARGETS ------------

${OUT}: ${DIR_BUILD}
	${ASM} ${ASM_FLAGS} "${IN}" -o "${OBJ}"
	${LD} ${LD_FLAGS} ${LD_LIBS} "${OBJ}" -o "${OUT}"

ifdef OS_BUILD
	cp "${OUT}" "${OS_BUILD}/sysroot"
endif

${DIR_BUILD}:
	mkdir -p "${DIR_BUILD}"

clean:
	rm -rf "${DIR_BUILD}"