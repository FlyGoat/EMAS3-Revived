# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

HOST_DRIVER_FLAGS ?= -g
HOST_MODULES := poneb02s timp06s opt04s ibmgen05s cserv01s host_put ibmrecos
HOST_OBJECTS := $(addprefix build/host/compiler/,$(addsuffix .o,$(HOST_MODULES)))
HOST_SOURCES := $(wildcard host/*.imp)
COMPILER_SOURCES := $(wildcard src/compilers/ercc07/*.imp src/compilers/ercc10/*.imp) $(wildcard src/xautils/*.imp) src/supervisor/ibmsup/seguse2.imp
HOST_LIBRARY := build/host/libemascompat.a
HOST_RUNTIME := build/host/runtime/libximplangrt.a

.PHONY: setup host-driver host-library compiler-objects grammar-tool compiler-grammar
setup: .venv/.requirements-installed
host-driver: $(HOST_COMPILER)
host-library: $(HOST_LIBRARY) $(HOST_RUNTIME)
compiler-objects: $(HOST_OBJECTS)
grammar-tool: build/grammar/oldps
compiler-grammar: build/compiler-grammar/tables.imp

.venv/.requirements-installed: requirements.txt
	uv venv --allow-existing .venv
	uv pip install --python $(PYTHON) -r requirements.txt
	touch $@

$(HOST_LIBRARY) $(HOST_RUNTIME) &: $(HOST_SOURCES) tools/build.py Makefile mk/host.mk .venv/.requirements-installed
	$(PYTHON) tools/build.py compat build/host --cc $(CLANG)

build/grammar/oldps: src/compilers/ercc07/trimp_oldps.imp host/oldps_main.imp $(HOST_LIBRARY) $(HOST_RUNTIME) mk/host.mk
	mkdir -p $(@D)
	$(XIMPLANG) -DXIMPLHOST=1 -o $@ src/compilers/ercc07/trimp_oldps.imp host/oldps_main.imp $(HOST_LIBRARY)

build/compiler-grammar/tables.imp: build/grammar/oldps src/compilers/ercc07/ibmps01.txt
	mkdir -p $(@D)
	cp src/compilers/ercc07/ibmps01.txt $(@D)/grammar.dat
	cd $(@D) && ../grammar/oldps > generate.log

$(HOST_OBJECTS) &: $(COMPILER_SOURCES) build/compiler-grammar/tables.imp tools/build.py Makefile mk/host.mk .venv/.requirements-installed
	$(PYTHON) tools/build.py compiler

build/host/libemascompiler.so: $(HOST_OBJECTS) $(HOST_LIBRARY) $(HOST_RUNTIME) Makefile mk/host.mk
	$(CLANG) -shared -fPIC -Wl,--no-undefined $(HOST_OBJECTS) $(HOST_LIBRARY) $(HOST_RUNTIME) -lm -o $@

build/host/host_imp.o: host/host_imp.imp Makefile mk/host.mk .venv/.requirements-installed
	mkdir -p $(@D)
	$(XIMPLANG) -c $< -o $@

$(HOST_COMPILER): build/host/host_imp.o build/host/libemascompiler.so Makefile mk/host.mk
	$(CLANG) $(HOST_DRIVER_FLAGS) $< -L build/host -lemascompiler -Wl,-rpath,'$$ORIGIN' -o $@
