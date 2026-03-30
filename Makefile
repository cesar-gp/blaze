# ------------ PROJECT DIRECTORIES ------------

DIR_SRC=src
DIR_BUILD=build

# ---------------- SYSTEM IMAGE ---------------

IMG=${DIR_BUILD}/os.img

# ----------- REQUIRED DEPENDENCIES -----------
#
# Dependencies that are required to compile
# the OS.
# 
# If you change one of these values and plan
# to make isolated builds of some subproject,
# make sure to check their values also there
# in its local Makefile.
#
# Apart from these dependencies, GNU make
# and GNU coreutils are also required to
# compile the operating system. They are
# pre-installed in most Unix systems.

export ASM=nasm									# NASM 3.0.1 or greater.
export LD=/opt/i686-elf-gcc/bin/i686-elf-gcc	# GCC cross-compiler for the i686-elf architecture.
export MCOPY=mcopy								# Sometimes pre-installed in Unix systems.
export MKFSFAT=mkfs.fat							# Sometimes pre-installed in Unix systems.

# ----------- OPTIONAL DEPENDENCIES -----------
#
# All optional dependencies (OPT) should be
# located in the 'tools' directory.

# For target 'qemu'

OPT_QEMU=qemu-system-i386

# For target 'bochs'

OPT_BOCHS=bochs									# Bochs with `rfb` display support.
OPT_GVNCVIEWER=gvncviewer						# Viewer for Bochs VNC display.
OPT_SLEEP=sleep									# Always installed in Unix systems.

# -------- PATH OF OS BUILD DIRECTORY ---------
#
# Subprojects like the bootloader will copy
# their final binaries and other compilation
# results here.
#
# It is also used internally to distinguish
# isolated builds of the subprojects and
# global builds that compile the entire OS.

export OS_BUILD=$(abspath ${DIR_BUILD})

# -------- AUTO-GENERATED TARGET LISTS --------
#
# Lists of Strings that contain build-* and
# clean-* target names for all of the folders
# that are inside the source directory.

TARGETS_BUILD=$(shell find ${DIR_SRC} -mindepth 1 -maxdepth 1 -type d -printf "build-%h/%f ")
TARGETS_CLEAN=$(shell find ${DIR_SRC} -mindepth 1 -maxdepth 1 -type d -printf "clean-%h/%f ")

# ------------- COMPLETE TARGETS --------------
#
# Targets that are meant for the user to call,
# like 'make all' and 'make clean'.

all: clean ${IMG}
clean: ${TARGETS_CLEAN}

debug: all
	# Assumes optional dependency 'bochs' using
	# 'rfb' as its display library.
	((sleep 1 && ${OPT_GVNCVIEWER} localhost) &>/dev/null) &
	DIR=${OPT_BOCHS_DIR} ${OPT_BOCHS} -dbg -q -f bochsrc

qemu: all
	${OPT_QEMU} -fda ${IMG}

# ----------- SYSTEM BUILD TARGETS ------------

${IMG}: ${DIR_BUILD} ${TARGETS_BUILD}
	dd if=/dev/zero bs=512 of="${IMG}" count=2880
	
	${MKFSFAT} -F 12 "${IMG}"
	dd if="${DIR_BUILD}/bin/stage1.bin" of="${IMG}" conv=notrunc

	# TODO: make a recursive copy of all the contents of
	# "sysroot" to the root of the system image.
	${MCOPY} -i "${IMG}" "${DIR_BUILD}/sysroot/stage2.bin" "::stage2.bin"

${DIR_BUILD}:
	mkdir -p "${DIR_BUILD}/bin"
	mkdir -p "${DIR_BUILD}/sysroot"

# --------- SUBPROJECT BUILD TARGETS ----------

build-${DIR_SRC}/%:
	${MAKE} all -C "${DIR_SRC}/$*"

clean-${DIR_SRC}/%:
	${MAKE} clean -C "${DIR_SRC}/$*"
	rm -rf "${DIR_BUILD}"