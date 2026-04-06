# ------- PATHS IN OS BUILD DIRECTORIES -------
#
# Subprojects like the bootloader will copy
# their final binaries and other compilation
# results here.
#
# This includes the "sysroot", the folder that
# contains all the files that are later copied
# to the root of the generated disk image.

export OS_BUILD=$(abspath build)
export OS_SRC=$(abspath src)
export OS_SYSROOT=${OS_BUILD}/sysroot
export OS_SYSLIB=${OS_SYSROOT}/usr/lib
export OS_SYSINCLUDE=${OS_SYSROOT}/usr/include

ifeq (${DEBUG}, true)
	export OS_DEBUG=${OS_BUILD}/debug
endif

# ---------------- SYSTEM IMAGE ---------------

IMG=${OS_BUILD}/os.img

# ----------- REQUIRED DEPENDENCIES -----------
#
# Dependencies that are required to compile
# the OS.
#
# Apart from these dependencies, GNU make
# and GNU coreutils are also required to
# compile the operating system. They are
# pre-installed in most Unix systems.

# NASM 3.0.1 or greater.
export ASM=nasm
export ASM_FLAGS=-f elf

# GCC cross-compiler for the i686-elf architecture.
export GCC=i686-elf-gcc
export GCC_FLAGS=-std=c99 -Wall -Wextra -ffreestanding -nostdlib

# GNU ar for the i686-elf architecture.
export AR=i686-elf-ar

# 'mcopy':	usually pre-installed in Unix systems
#			as part of `mtools`.
export MCOPY=mcopy

# 'mkfs.fat':	usually pre-installed in Unix systems
#				as part of `dosfstools`.
export MKFSFAT=mkfs.fat

# ----------- OPTIONAL DEPENDENCIES -----------
#

# - - - - - - - For target 'qemu' - - - - - - -

# Path to QEMU for the i386 architecture.
OPT_QEMU=qemu-system-i386

# QEMU command-line options.
OPT_QEMU_FLAGS=-s -S -fda ${IMG}

# GDB version 17.1 or greater.
OPT_GDB=gdb

# GDB command-line options.
OPT_GDB_FLAGS=\
	-ex "set pagination off" \
	-ex "set confirm off" \
	-ex "target remote localhost:1234" \
	$(shell find "${OS_DEBUG}" -mindepth 1 -name "*.elf" -printf "-ex \"add-symbol-file \"%h/%f\"\" ") \
	-ex "set confirm on" \
	-ex "set pagination on" \
	-ex "layout src"

# A bash-compatible terminal with `-e` flag.
OPT_TERMINAL=alacritty

# Terminal command-line options.
OPT_TERMINAL_FLAGS=-e ${OPT_GDB} ${OPT_GDB_FLAGS}

# - - - - - -  For target 'bochs' - - - - - - -

# Bochs with `rfb` display support.
OPT_BOCHS=bochs

# Bochs command-line options.
OPT_BOCHS_FLAGS=-dbg -q -f bochsrc

# VNC Viewer for Bochs RFB display.
OPT_GVNCVIEWER=gvncviewer

# -------- AUTO-GENERATED TARGET LISTS --------
#
# Lists of Strings that contain build-* and
# clean-* target names for all of the folders
# that are inside the source directory.

TARGETS_BUILD=$(shell find "${OS_SRC}" -mindepth 1 -maxdepth 1 -type d -printf "build-%h/%f ")
TARGETS_CLEAN=$(shell find "${OS_SRC}" -mindepth 1 -maxdepth 1 -type d -printf "clean-%h/%f ")

# -------------- SPECIAL TARGETS --------------

.NOTPARALLEL: all

# ------------- COMPLETE TARGETS --------------
#
# Targets that are meant for the user to call,
# like 'make all' and 'make clean'.

all: clean ${IMG}
clean: ${TARGETS_CLEAN}

bochs: all
	((sleep 1 && ${OPT_GVNCVIEWER} localhost) &>/dev/null) &
	DIR=${OPT_BOCHS_DIR} ${OPT_BOCHS} ${OPT_BOCHS_FLAGS}

qemu: all
	${OPT_TERMINAL} ${OPT_TERMINAL_FLAGS} &
	${OPT_QEMU} ${OPT_QEMU_FLAGS}

# ----------- SYSTEM BUILD TARGETS ------------

${IMG}: ${TARGETS_BUILD}
	dd if=/dev/zero bs=512 of="${IMG}" count=2880
	
	${MKFSFAT} -F 12 "${IMG}"
	dd if="${OS_BUILD}/stage1.bin" of="${IMG}" conv=notrunc

	${MCOPY} -s -i "${IMG}" "${OS_SYSROOT}"/* "::"

${OS_BUILD}:
	mkdir -p "${OS_BUILD}"
	mkdir -p "${OS_SYSROOT}"
	mkdir -p "${OS_SYSLIB}"
	mkdir -p "${OS_SYSINCLUDE}"

ifeq (${DEBUG}, true)
	mkdir -p "${OS_DEBUG}"
endif

# --------- SUBPROJECT BUILD TARGETS ----------

build-${OS_SRC}/%: ${OS_BUILD} ${OS_SRC}/%
	${MAKE} all -C "${OS_SRC}/$*"

clean-${OS_SRC}/%: ${OS_SRC}/%
	${MAKE} clean -C "$<"
	rm -rf "${OS_BUILD}"
	rm -rf "${OS_SYSROOT}"
	rm -rf "${OS_SYSLIB}"
	rm -rf "${OS_SYSINCLUDE}"

ifeq (${DEBUG}, true)
	rm -rf "${OS_DEBUG}"
endif