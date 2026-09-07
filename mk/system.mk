# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

# System components compiled from the maintained sources.
SYSTEM_OPT ?= -fno-line -fno-diag
SYSTEM_CONSOLE_SOURCE ?= src/eutils/iop3270s.imp
# Keep the archived optimizer off: GETMNEM depends on adjacent local storage.
SYSTEM_DIR_OBJECTS = $(addprefix build/director/,diagy conny directy xopy ssy)
build/director/diagy: DIR_SOURCE=src/director/c05diag.imp
build/director/conny: DIR_SOURCE=src/director/b01conn.imp
build/director/directy: DIR_SOURCE=src/director/b02direct.imp
build/director/xopy: DIR_SOURCE=src/director/c04xop.imp
build/director/ssy: DIR_SOURCE=src/director/b07ss.imp
# The copied director/compile.txt explicitly selects PARM OPT.
$(SYSTEM_DIR_OBJECTS): $$(DIR_SOURCE) $(wildcard src/director/*.imp) $(HOST_COMPILER) Makefile mk/system.mk
	mkdir -p $(@D)
	$(HOST_COMPILER) -O \
	  --include dirarc:d.c03formats=src/director/c03formats.imp \
	  --include c03formats=src/director/c03formats.imp \
	  $(DIR_SOURCE) $@ > $@.log 2>&1
SYSTEM_SUP_OBJECTS = $(addprefix build/supervisor/,isup12fy ifast24y idev22y ioper2y icom9y iprint4y itapes9ny icomms16y ienter3y indiag3y)
SYSTEM_CHOP_OBJECTS = $(addprefix build/chopsupe/,ichopn6y idev22nry ich3270nry itapes9nry)
SYSTEM_INCLUDES := $(wildcard src/supervisor/ibmsup/*.imp src/eutils/*.imp)

.PHONY: director-objects supervisor-objects chopsupe-objects
.PHONY: combined-director combined-supervisor combined-chopsupe
.PHONY: supervisor-image loader-image director-image
director-objects: $(SYSTEM_DIR_OBJECTS)
supervisor-objects: $(SYSTEM_SUP_OBJECTS)
chopsupe-objects: $(SYSTEM_CHOP_OBJECTS)
combined-director: build/director/combined
combined-supervisor: build/supervisor/isup-combined
combined-chopsupe: build/chopsupe/ichop-combined
supervisor-image: build/supervisor/isup-fixed
loader-image: build/chopsupe/ichopt
director-image: $(DIRECTOR_IMAGE)

build/director/combined: $(SYSTEM_DIR_OBJECTS) tools/ibm_combine.py
	$(PYTHON) tools/ibm_combine.py $@ $(SYSTEM_DIR_OBJECTS) > $@.log

build/supervisor/isup-combined: $(SYSTEM_SUP_OBJECTS) tools/ibm_combine.py
	$(PYTHON) tools/ibm_combine.py $@ $(SYSTEM_SUP_OBJECTS) > $@.log

build/chopsupe/ichop-combined: $(SYSTEM_CHOP_OBJECTS) tools/ibm_combine.py
	$(PYTHON) tools/ibm_combine.py $@ $(SYSTEM_CHOP_OBJECTS) > $@.log

build/supervisor/isup-fixed: build/supervisor/isup-combined $(IMAGE_FIXER)
	$(IMAGE_FIXER) supervisor $< $@ > $@.console.log

build/chopsupe/ichopt: build/chopsupe/ichop-combined $(IMAGE_FIXER) src/chopsupe/xacfix01s.imp
	$(IMAGE_FIXER) loader $< $@ > $@.log

$(DIRECTOR_IMAGE): build/director/combined $(IMAGE_FIXER) src/director/c02bld.imp
	$(IMAGE_FIXER) director $< $@ > $@.console.log

build/supervisor/isup12fy: SYSTEM_SOURCE=src/supervisor/isup12fs.imp
$(SYSTEM_SUP_OBJECTS): SYSTEM_OPTIONS=src/compilers/ercc07/ctoptnassmp.imp
build/supervisor/ifast24y: SYSTEM_SOURCE=src/supervisor/ifast24s.imp
build/supervisor/idev22y: SYSTEM_SOURCE=src/supervisor/idev22s.imp
build/supervisor/ioper2y: SYSTEM_SOURCE=$(SYSTEM_CONSOLE_SOURCE)
build/supervisor/icom9y: SYSTEM_SOURCE=src/supervisor/icom9s.imp
build/supervisor/iprint4y: SYSTEM_SOURCE=src/supervisor/iprint4s.imp
build/supervisor/itapes9ny: SYSTEM_SOURCE=src/supervisor/itapes9ns.imp
build/supervisor/icomms16y: SYSTEM_SOURCE=src/supervisor/icomms16s.imp
build/supervisor/ienter3y: SYSTEM_SOURCE=src/supervisor/ienter3s.imp
build/supervisor/indiag3y: SYSTEM_SOURCE=src/supervisor/indiag3s.imp
$(SYSTEM_CHOP_OBJECTS): SYSTEM_OPTIONS=src/eutils/ctoptnassc.imp
build/chopsupe/ichopn6y: SYSTEM_SOURCE=src/chopsupe/ichop6cs.imp
build/chopsupe/idev22nry: SYSTEM_SOURCE=src/chopsupe/idev22s.imp
build/chopsupe/ich3270nry: SYSTEM_SOURCE=src/chopsupe/ich3270s.imp
build/chopsupe/itapes9nry: SYSTEM_SOURCE=src/chopsupe/itapes9ns.imp
$(SYSTEM_SUP_OBJECTS) $(SYSTEM_CHOP_OBJECTS): SYSTEM_INPUT=host/supervisor.imp
# The tape module already includes its options.
build/chopsupe/itapes9nry: SYSTEM_INPUT=src/chopsupe/itapes9ns.imp
build/supervisor/itapes9ny: SYSTEM_INPUT=src/supervisor/itapes9ns.imp
build/supervisor/icomms16y: SYSTEM_INPUT=src/supervisor/icomms16s.imp
$(SYSTEM_SUP_OBJECTS) $(SYSTEM_CHOP_OBJECTS): $$(SYSTEM_SOURCE) $$(SYSTEM_INPUT) $$(SYSTEM_OPTIONS) $(SYSTEM_INCLUDES) $(HOST_COMPILER) Makefile mk/system.mk
	mkdir -p $(@D)
	$(HOST_COMPILER) $(SYSTEM_OPT) -fno-check -fno-array-check \
	  --include ibmsup_ctoptxa=$(SYSTEM_OPTIONS) \
	  --include ibmsup_unit=$(SYSTEM_SOURCE) \
	  --include ercc07:ctoptnass=$(SYSTEM_OPTIONS) \
	  --include ercc07:ctoptnassmp=src/compilers/ercc07/ctoptnassmp.imp \
	  --include ercc07:ibmsup_seguse2=src/supervisor/ibmsup/seguse2.imp \
	  --include ercc07:ibmsup_page0=src/supervisor/ibmsup/page0.imp \
	  --include ercc07:ibmsup_page0f=src/supervisor/ibmsup/page0f.imp \
	  --include ercc07:ibmsup_lcform7s=src/supervisor/ibmsup/lcform7s.imp \
	  --include ercc07:ibmsup_comf370=src/supervisor/ibmsup/comf370.imp \
	  --include ercc07:ibmsup_comformat=src/supervisor/ibmsup/comformat.imp \
	  --include ercc07:ibmsup_dtform1s=src/supervisor/ibmsup/dtform1s.imp \
	  --include ercc07:ibmsup_dtform2s=src/supervisor/ibmsup/dtform2s.imp \
	  --include ercc07:ibmsup_xaioform=src/supervisor/ibmsup/xaioform.imp \
	  --include ercc07:ibmsup_configv7=src/supervisor/ibmsup/configv7.imp \
	  --include ercc07:ibmsup_config370=src/supervisor/ibmsup/config370.imp \
	  --include confignass=src/eutils/confignass.imp \
	  $(SYSTEM_INPUT) $@ > $@.log 2>&1
