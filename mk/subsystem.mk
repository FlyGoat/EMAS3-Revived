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

build/subsystem/basefile: build/subsystem/combined $(SUBSYSTEM_DIRECTOR) $(IMAGE_FIXER)
	$(IMAGE_FIXER) subsystem $< $@ $(SUBSYSTEM_DIRECTOR) > $@.console.log
