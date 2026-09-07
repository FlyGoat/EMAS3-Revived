# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

# Module order from subsystem/compile.txt and optlink.txt.
SUBSYSTEM_MODULES = s01 s02 s30 s31 s32 s33 s34 s05 s51 s52 s06 s07 s10 s11 s14 s15 s22 s24 s25 s26 s27 s88
SUBSYSTEM_OBJECTS = $(addprefix build/subsystem/,$(addsuffix y,$(SUBSYSTEM_MODULES)))
.PHONY: subsystem-objects
subsystem-objects: $(SUBSYSTEM_OBJECTS)
build/subsystem/%y: src/subsystem/%s.imp src/subsystem/ssownf3.imp $(wildcard src/subsystem/*.imp) $(HOST_COMPILER) Makefile mk/subsystem.mk
	mkdir -p $(@D)
	$(HOST_COMPILER) -O -fno-check -fno-array-check \
	  --include SUBARC:SSOWNF3=src/subsystem/ssownf3.imp \
	  $< $@ > $@.log 2>&1

# Require the already fixed Director that this basefile will run against.
SUBSYSTEM_DIRECTOR ?= $(DIRECTOR_IMAGE)
build/subsystem/combined: $(SUBSYSTEM_OBJECTS) tools/ibm_combine.py
	$(PYTHON) tools/ibm_combine.py $@ $(SUBSYSTEM_OBJECTS) > $@.log
.PHONY: subsystem-image
subsystem-image: build/subsystem/basefile

# Run the archived IMP fixer natively, with the same host ABI adaptations as
# the compiler. The adapter supplies files and the Director SCT, not fixups.
build/subsystem/subfix.o: src/subsystem/subfix.imp mk/subsystem.mk .venv/.requirements-installed
	mkdir -p $(@D)
	$(XIMPLANG) -DXIMPLHOST=1 -c $< -o $@

build/subsystem/subfix_main.o: host/subfix_main.imp mk/subsystem.mk .venv/.requirements-installed
	mkdir -p $(@D)
	$(XIMPLANG) -c $< -o $@

build/subsystem/subfix: build/subsystem/subfix.o build/subsystem/subfix_main.o $(HOST_LIBRARY) $(HOST_RUNTIME)
	$(CLANG) $^ -lm -pthread -o $@

build/subsystem/basefile: build/subsystem/combined $(SUBSYSTEM_DIRECTOR) build/subsystem/subfix
	build/subsystem/subfix $< $(SUBSYSTEM_DIRECTOR) $@
