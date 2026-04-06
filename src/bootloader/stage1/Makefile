# ------------ PROJECT DIRECTORIES ------------

DIR_SRC=$(abspath src)
DIR_BUILD=$(abspath build)

# --------------- DEPENDENCIES ----------------

GCC_LINKERFLAGS:=-T "${DIR_SRC}/linker.ld"
GCC_LINKERFLAGSFAST:=${GCC_LINKERFLAGS} -Wl,--oformat binary

ifeq (${DEBUG}, true)
	GCC_FLAGS:=${GCC_FLAGS} -g
	GCC_LINKERFLAGSDEBUG:=${GCC_LINKERFLAGS} -Wl,--oformat elf32-i386
endif

GCC_LIBS:=-lgcc

# ------------- INPUT AND OUTPUT --------------

IN=$(shell find "${DIR_SRC}" -mindepth 1 -maxdepth 1 -name "*.s" -printf "${DIR_BUILD}/%f.o ")
OUT=${OS_BUILD}/stage1.bin

ifeq (${DEBUG}, true)
	OUTDEBUG=${OS_DEBUG}/stage1.elf
endif

# -------------- SPECIAL TARGETS --------------

.NOTPARALLEL: all

# ------------- COMPLETE TARGETS --------------
#
# Targets that are meant for the user to call,
# like 'make all' and 'make clean'.

all: clean ${OUT}

clean:
	rm -rf "${DIR_BUILD}"

# ----------- SOURCE BUILD TARGETS ------------

${OUT}: ${IN}
	${GCC} ${GCC_FLAGS} ${GCC_LINKERFLAGSFAST} ${IN} -o "${OUT}" ${GCC_LIBS}

ifeq (${DEBUG}, true)
	${GCC} ${GCC_FLAGS} ${GCC_LINKERFLAGSDEBUG} ${IN} -o "${OUTDEBUG}" ${GCC_LIBS}
endif

${DIR_BUILD}/%.s.o: ${DIR_SRC}/%.s ${DIR_BUILD}
	${ASM} ${ASM_FLAGS} "$<" -o "$@"

${DIR_BUILD}:
	mkdir -p "${DIR_BUILD}"