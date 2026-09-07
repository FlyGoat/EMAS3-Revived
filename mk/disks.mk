# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

.PHONY: chop-ipl-disk chop-volume-image stage-supervisor hercules-config
chop-ipl-disk: build/ipl/chop.3380 build/ipl/hercules.cnf
chop-volume-image: build/ipl/emas0.3380 build/ipl/emas1.3380 build/ipl/hercules.cnf
hercules-config system-images: build/ipl/hercules.cnf

build/ipl/hercules.cnf: config/hercules-chop.cnf
	mkdir -p $(@D)
	cp $< $@

build/ipl/chop.3380: build/chopsupe/ichopt tools/chop_ipl_disk.py Makefile mk/disks.mk
	mkdir -p $(@D)
	rm -f $@.tmp
	"$(DASDINIT)" -r $@.tmp 3380 2 > $@.log 2>&1
	$(PYTHON) tools/chop_ipl_disk.py $< $@.tmp >> $@.log 2>&1
	mv $@.tmp $@

# Create blank volumes only when explicitly requested and absent.
build/ipl/emas0.3380 build/ipl/emas1.3380:
	mkdir -p $(@D)
	"$(DASDINIT)" -r $@ 3380 885 > $@.log 2>&1

# Run with Hercules stopped and the volume already formatted by EMAS.
stage-supervisor: build/supervisor/isup-fixed
	$(PYTHON) tools/write_emas_pages.py build/ipl/emas0.3380 64 $< --system-area
