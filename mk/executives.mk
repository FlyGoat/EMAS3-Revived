# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

# Executive recipes follow each maintained archive link file.
EXEC_OPT ?= -fno-line -fno-diag -fno-check -fno-array-check
EXEC_VOLUMS = volums-diag volums director-legacy
EXEC_SPOOLR = spoolr-diag spoolr spoolr-read spoolr-iocp director-legacy
EXEC_MAILER = mailer-diag mailer-iocp mailer
EXEC_FTRANS = ftrans-diag ftrans ftrans-conf ftrans-iocp director-legacy
EXEC_MODULES = $(sort $(EXEC_VOLUMS) $(EXEC_SPOOLR) $(EXEC_MAILER) $(EXEC_FTRANS))
build/executives/volums-diag: EXEC_SOURCE=src/volumes/diag4s.imp
build/executives/volums: EXEC_SOURCE=src/volumes/s1u.imp
build/executives/director-legacy: EXEC_SOURCE=src/compat/director_legacy.imp
build/executives/spoolr-diag: EXEC_SOURCE=src/spooler/newstdiags.imp
build/executives/spoolr: EXEC_SOURCE=src/spooler/snas1089.imp
build/executives/spoolr-read: EXEC_SOURCE=src/spooler/readcs.imp
build/executives/spoolr-iocp: EXEC_SOURCE=src/spooler/iocps.imp
build/executives/mailer-diag: EXEC_SOURCE=src/mailer/mdiag6s.imp
build/executives/mailer-iocp: EXEC_SOURCE=src/mailer/iocp4s.imp
build/executives/mailer: EXEC_SOURCE=src/mailer/mailer8ms.imp
build/executives/ftrans-diag: EXEC_SOURCE=src/ftrans/newstdiags.imp
build/executives/ftrans: EXEC_SOURCE=src/ftrans/ft.imp
build/executives/ftrans-conf: EXEC_SOURCE=src/ftrans/conf.imp
build/executives/ftrans-iocp: EXEC_SOURCE=src/ftrans/iocp.imp
$(addprefix build/executives/,$(EXEC_MODULES)): $(HOST_COMPILER) Makefile mk/executives.mk $(wildcard src/volumes/*.imp src/spooler/*.imp src/mailer/*.imp src/ftrans/*.imp src/compat/*.imp)
	mkdir -p $(@D)
	$(HOST_COMPILER) $(EXEC_OPT) \
	  --include :TARGET=src/ftrans/target.imp --include TARGET=src/ftrans/target.imp \
	  $(EXEC_SOURCE) $@ > $@.log 2>&1
.PHONY: executive-objects
executive-objects: $(addprefix build/executives/,$(EXEC_MODULES))

$(addprefix build/executives/,$(EXEC_MODULES)): $$(EXEC_SOURCE)
build/executives/volums-combined: EXEC_INPUTS=$(EXEC_VOLUMS)
build/executives/spoolr-combined: EXEC_INPUTS=$(EXEC_SPOOLR)
build/executives/mailer-combined: EXEC_INPUTS=$(EXEC_MAILER)
build/executives/ftrans-combined: EXEC_INPUTS=$(EXEC_FTRANS)
EXEC_COMBINED = $(addprefix build/executives/,$(addsuffix -combined,volums spoolr mailer ftrans))
$(EXEC_COMBINED): $$(addprefix build/executives/,$$(EXEC_INPUTS)) tools/ibm_combine.py
	$(PYTHON) tools/ibm_combine.py $@ $(addprefix build/executives/,$(EXEC_INPUTS)) > $@.log
build/executives/ivolums: EXEC_NAME=volums
build/executives/ispoolr: EXEC_NAME=spoolr
build/executives/imailer: EXEC_NAME=mailer
build/executives/iftrans: EXEC_NAME=ftrans
EXEC_IMAGES = $(addprefix build/executives/i,volums spoolr mailer ftrans)
$(EXEC_IMAGES): build/executives/$$(EXEC_NAME)-combined $(IMAGE_TOOLS)
	$(PYTHON) tools/fix_image.py executive $< $@ > $@.log
.PHONY: executive-images
executive-images: $(EXEC_IMAGES)
