# -------- AUTO-GENERATED TARGET LISTS --------
#
# Lists of Strings that contain build-* and
# clean-* target names for all of the folders
# that are inside the source directory.

TARGETS_BUILD=$(shell find . -mindepth 1 -maxdepth 1 -type d -printf "build-%h/%f ")
TARGETS_CLEAN=$(shell find . -mindepth 1 -maxdepth 1 -type d -printf "clean-%h/%f ")

# -------------- OS-BUILD IMPORT --------------

export OS_BUILD

# ------------- COMPLETE TARGETS --------------
#
# Targets that are meant for the user to call,
# like 'make all' and 'make clean'.

all: ${TARGETS_BUILD}
clean: ${TARGETS_CLEAN}

# --------- SUBPROJECT BUILD TARGETS ----------

build-./%:
	${MAKE} all -C "$*"

clean-./%:
	${MAKE} clean -C "$*"