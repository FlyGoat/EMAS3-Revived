# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Jiaxun Yang <jiaxun.yang@flygoat.com>

COMPILER_MODULES := poneb02s timp06s opt04s ibmgen05s cserv01s host_put ibmrecos
COMPILER_OBJECTS := $(addprefix build/compiler/,$(COMPILER_MODULES))
COMPILER_STEERING := ibmponeas trimp_ibmptwoas trimp_ibmoptas
COMPILER_TABLES := mnemonics props names
COMPILER_GENERATED := $(addprefix build/compiler/,$(addsuffix .imp,$(COMPILER_STEERING))) \
  build/compiler/tform.imp $(addprefix build/compiler/ib7_,$(addsuffix .imp,$(COMPILER_TABLES)))
COMPILER_BINDINGS := \
  $(foreach name,$(filter-out ibmrecos,$(COMPILER_MODULES)) trimp_ibmoptions ibmpone_support,$(name).imp=src/compilers/ercc07/$(name).imp) \
  $(foreach name,$(COMPILER_STEERING),$(name).imp=build/compiler/$(name).imp) \
  ibmrecos.imp=src/xautils/ibmrecos.imp \
  ibmrecobody.imp=src/xautils/ibmrecobody.imp \
  COMPILER_TABLES=build/compiler-grammar/tables.imp \
  ERCC07.TRIMP_HOSTCODES=src/compilers/ercc07/hostcodes.imp \
  ERCC07:ITRIMP_HOSTCODES=src/compilers/ercc07/hostcodes.imp \
  ERCC07:ITRIMP_TFORM2S=build/compiler/tform.imp \
  ERCC07:TRIPCNSTS=src/compilers/ercc07/tripcnsts.imp \
  ERCC07:PUTSPECS=src/compilers/ercc07/host_putspecs.imp \
  XAUTILS_CTOPTXA=src/compilers/ercc07/ctoptnass.imp \
  ERCC07:IBMSUP_SEGUSE2=src/supervisor/ibmsup/seguse2.imp \
  ERCC10:OPOUTS=src/compilers/ercc10/opouts.imp \
  host_addresses.imp=src/compilers/ercc07/host_addresses.imp \
  ERCS20:IB7_MNEMONICS=build/compiler/ib7_mnemonics.imp \
  ERCS20:IB7_PROPS=build/compiler/ib7_props.imp \
  ERCS20:IB7_NAMES=build/compiler/ib7_names.imp

.PHONY: compiler
compiler: build/compiler/imp

# Select the IBM host without changing the archived steering sources.
$(addprefix build/compiler/,$(addsuffix .imp,$(COMPILER_STEERING))): build/compiler/%.imp: src/compilers/ercc07/%.imp mk/compiler.mk
	mkdir -p $(@D)
	sed -e 's/HOST=EMAS/HOST=AMDAHL/' \
	  -e 's,../../../build/compiler-grammar/tables.imp,COMPILER_TABLES,' $< > $@

build/compiler/tform.imp: src/compilers/ercc07/trimp_tform2s.imp mk/compiler.mk
	mkdir -p $(@D)
	printf '%%constantinteger XIMPLITTLEENDIAN=0\n' > $@
	cat $< >> $@

# Remove DOS EOF markers from the archived instruction tables.
build/compiler/ib7_%.imp: src/compilers/ercc07/ib7_%.imp mk/compiler.mk
	mkdir -p $(@D)
	tr -d '\032' < $< > $@

build/compiler/poneb02s.imp: COMPILER_PARTS = ibmponeas.imp poneb02s.imp
build/compiler/timp06s.imp: COMPILER_PARTS = trimp_ibmoptions.imp trimp_ibmptwoas.imp timp06s.imp
build/compiler/opt04s.imp: COMPILER_PARTS = trimp_ibmoptas.imp opt04s.imp
build/compiler/ibmgen05s.imp: COMPILER_PARTS = ibmgen05s.imp
build/compiler/cserv01s.imp: COMPILER_PARTS = cserv01s.imp
build/compiler/host_put.imp: COMPILER_PARTS = host_put.imp
build/compiler/ibmrecos.imp: COMPILER_PARTS = ibmrecos.imp

# Short include aliases
# %ENDOFFILE inside an include returns to the wrapper, which needs its own EOF.
$(addsuffix .imp,$(COMPILER_OBJECTS)): mk/compiler.mk
	mkdir -p $(@D)
	printf '%%include "%s"\n' $(COMPILER_PARTS) > $@
	printf '%%endoffile\n' >> $@

$(COMPILER_OBJECTS): %: %.imp $(COMPILER_GENERATED) $(COMPILER_SOURCES) build/compiler-grammar/tables.imp $(HOST_COMPILER) mk/compiler.mk
	$(HOST_COMPILER) -fno-check -fno-array-check \
	  $(addprefix --include ,$(COMPILER_BINDINGS)) $< $@ > $@.log 2>&1

build/compiler/imp: $(COMPILER_OBJECTS) tools/ibm_combine.py
	$(PYTHON) tools/ibm_combine.py $@ $(COMPILER_OBJECTS) > $@.log
