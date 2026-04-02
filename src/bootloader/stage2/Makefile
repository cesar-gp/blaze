# ------------ PROJECT DIRECTORIES ------------

DIR_SRC=src
DIR_BUILD=build

# --------------- DEPENDENCIES ----------------

ASM?=nasm
ASM_FLAGS=-f elf

GCC?=/opt/i686-elf-gcc/bin/i686-elf-gcc
GCC_FLAGS=-std=c99 -Wall -Wextra -ffreestanding
GCC_LINKER=-T "${DIR_SRC}/linker.ld"
GCC_LIBS=-nostdlib -lgcc

# ------------- INPUT AND OUTPUT --------------

IN_ASM=$(shell find "${DIR_SRC}" -mindepth 1 -maxdepth 1 -name "*.s")
IN_GCC=$(shell find "${DIR_SRC}" -mindepth 1 -maxdepth 1 -name "*.c")
IN_OBJ=$(shell find "${DIR_SRC}" -mindepth 1 -maxdepth 1 -name "*.s" -printf "${DIR_BUILD}/bin/%f.o " -or -name "*.c" -printf "${DIR_BUILD}/bin/%f.o ")

OBJ=${DIR_BUILD}/stage2.elf
OUT=${DIR_BUILD}/stage2.bin

# ------------- COMPLETE TARGETS --------------
#
# Targets that are meant for the user to call,
# like 'make all' and 'make clean'.

all: clean ${OUT}

clean:
	rm -rf "${DIR_BUILD}"

# ----------- SOURCE BUILD TARGETS ------------

${OUT}: ${DIR_BUILD} ${IN_OBJ}
	${GCC} ${GCC_FLAGS} ${GCC_LINKER} ${GCC_LIBS} ${IN_OBJ} -o "${OUT}"

ifdef OS_BUILD
	cp "${OUT}" "${OS_BUILD}/sysroot"
endif

${DIR_BUILD}/bin/%.c.o: ${DIR_SRC}/%.c
	${GCC} -c ${GCC_FLAGS} ${GCC_LIBS} "$<" -o "$@"

${DIR_BUILD}/bin/%.s.o: ${DIR_SRC}/%.s
	${ASM} ${ASM_FLAGS} "$<" -o "$@"

${DIR_BUILD}:
	mkdir -p "${DIR_BUILD}/bin"