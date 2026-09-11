# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

.DEFAULT_GOAL := host-driver
.DELETE_ON_ERROR:
.SECONDEXPANSION:

PYTHON ?= $(CURDIR)/.venv/bin/python
XIMPLANG ?= $(CURDIR)/.venv/bin/ximplang
CLANG ?= clang
HERCULES ?= hercules
DASDINIT ?= dasdinit
SOURCE_DATE_EPOCH ?= 0
export PATH := $(CURDIR)/.venv/bin:$(PATH)
export HERCULES DASDINIT SOURCE_DATE_EPOCH

HOST_COMPILER := build/host/emas-imp
DIRECTOR_IMAGE := build/director/ERCC04\:DIRECTOR

include mk/host.mk
include mk/fixers.mk
include mk/system.mk
include mk/executives.mk
include mk/subsystem.mk
include mk/compiler.mk
include mk/disks.mk

.PHONY: system-images
system-images: supervisor-image loader-image director-image executive-images subsystem-image compiler
