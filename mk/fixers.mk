# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

# Archived IMP image fixers, hosted with native pointers and IBM file byte order.
IMAGE_FIXER := build/fixers/fix-image
FIXER_OBJECTS := $(addprefix build/fixers/,ifix.o chopfix.o dirfix.o vsmfix.o subfix.o)
build/fixers/ifix.o: FIXER_SOURCE=src/supervisor/ifix8s.imp
build/fixers/chopfix.o: FIXER_SOURCE=src/chopsupe/xacfix01s.imp
build/fixers/dirfix.o: FIXER_SOURCE=src/director/c02bld.imp
build/fixers/vsmfix.o: FIXER_SOURCE=src/eutils/vsmfix1s.imp
build/fixers/subfix.o: FIXER_SOURCE=src/subsystem/subfix.imp
$(FIXER_OBJECTS): $$(FIXER_SOURCE) mk/fixers.mk .venv/.requirements-installed
	mkdir -p $(@D)
	$(XIMPLANG) -DXIMPLHOST=1 -c $< -o $@

build/fixers/image_main.o: host/image_main.imp mk/fixers.mk .venv/.requirements-installed
	mkdir -p $(@D)
	$(XIMPLANG) -c $< -o $@

$(IMAGE_FIXER): $(FIXER_OBJECTS) build/fixers/image_main.o $(HOST_LIBRARY) $(HOST_RUNTIME)
	$(CLANG) $^ -lm -pthread -o $@

.PHONY: image-fixers
image-fixers: $(IMAGE_FIXER)
