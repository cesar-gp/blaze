# ------------ PROJECT DIRECTORIES ------------

DIR_SRC=src
DIR_BUILD=build

# --------------- DEPENDENCIES ----------------

ASM?=nasm
ASM_FLAGS=-f bin

# ------------- INPUT AND OUTPUT --------------

IN=${DIR_SRC}/stage1.s
OUT=${DIR_BUILD}/stage1.bin

# ------------- COMPLETE TARGETS --------------
#
# Targets that are meant for the user to call,
# like 'make all' and 'make clean'.

all: clean ${DIR_BUILD} ${OUT}

# ----------- SOURCE BUILD TARGETS ------------

${OUT}: ${IN}
	${ASM} ${ASM_FLAGS} -o $@ $<

ifdef OS_BUILD
	cp "${OUT}" "${OS_BUILD}/bin"
endif

${DIR_BUILD}:
	mkdir -p "${DIR_BUILD}"

clean:
	rm -rf "${DIR_BUILD}"