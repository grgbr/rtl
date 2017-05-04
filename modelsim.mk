#
# Modelsim linux binary is 32 bits only. To run on 64 bits platform, a python /
# openssl combination is needed to be built for 32 bits platform along with
# cocotb framework.
#
# Moreover, to properly run modelsim on 64 bits, additional 32 bits packages
# must be installed. A good starting point is:
#
# dpkg --add-architecture i386
# apt-get update
# apt-get install build-essential
# apt-get install gcc-multilib g++-multilib \
# lib32z1 lib32stdc++6 lib32gcc1 \
# expat:i386 fontconfig:i386 libfreetype6:i386 libexpat1:i386 libc6:i386 libgtk-3-0:i386 \
# libcanberra0:i386 libpng12-0:i386 libice6:i386 libsm6:i386 libncurses5:i386 zlib1g:i386 \
# libx11-6:i386 libxau6:i386 libxdmcp6:i386 libxext6:i386 libxft2:i386 libxrender1:i386 \
# libxt6:i386 libxtst6:i386
#
# Note ! Modelsim starter edition does not support FLI interface... Which makes
# it pretty unusable with cocotb for now.
#
MODELSIM      := /opt/altera/modelsim_ase
VSIM          := $(MODELSIM)/bin/vsim
VLIB          := $(MODELSIM)/bin/vlib
VMAP          := $(MODELSIM)/bin/vmap
VCOM          := $(MODELSIM)/bin/vcom
VFLAGS        := -nologo -fsmverbose w -stats=-cmd,-time -source \
                 -check_synthesis -lint

cocotb_libs   := $(BUILD)/cocotb_libs
cocotb_libdir := $(cocotb_libs)/build/libs/i686
libvpi        := $(cocotb_libdir)/libvpi.so
libfli        := $(cocotb_libdir)/libfli.so

modelsim-env  := ARCH="i686" \
	         PATH="$(STAGING)/bin:$(PATH)" \
	         SIM_ROOT="$(COCOTB)" \
	         SIM="modelsim" \
	         MODELSIM_BIN_DIR="$(MODELSIM)/bin" \
	         PYTHONHOME="$(STAGING)" \
	         PYTHONPATH="$(TEST):$(cocotb_libdir):$(COCOTB)" \
	         LIBRARY_PATH="$(STAGING)/lib:/usr/lib32:/lib32:$(LIBRARY_PATH)" \
	         LD_LIBRARY_PATH="$(cocotb_libdir):$(STAGING)/lib" \
	         TOPLEVEL_LANG="vhdl"

define _runcosim
	cd $(BUILD) && \
	env $(modelsim-env) \
	    GPI_EXTRA="vpi" \
	    TOPLEVEL="$(subst _cosim.ghw,,$(subst $(BUILD)/,,$(1)))" \
	    MODULE="$(subst .ghw,,$(subst $(BUILD)/,,$(1)))" \
	    TESTCASE= \
	    COCOTB_REDUCED_LOG_FMT=1 \
	    $(VSIM) -c +nowarn3116 -onfinish exit -foreign "cocotb_init libfli.so" \
	    $(2).$(subst _cosim.ghw,,$(subst $(BUILD)/,,$(1))) -do ../modelsim.do
endef

define libobj
$(STAMPS)/$(1)-lib.built
endef

define _libdep
$(patsubst $(STAMPS)/%-lib.built,%,$(filter %-lib.built,$(1)))
endef

define _mklibdeps
$(STAMPS)/$(1)-lib.built: $($(1)-lib)
endef

define _mkcosim
$(BUILD)/$(1)_cosim.ghw: $($(1)-cosim) $(libvpi) $(libfli)
	$(call _runcosim,$(BUILD)/$(1)_cosim.ghw,$(call _libdep,$($(1)-cosim)))
endef

# build library
$(STAMPS)/%-lib.built: Makefile | $(STAMPS) $(BUILD)/amba-lib
	cd $(BUILD) && $(VCOM) $(VFLAGS) \
		-logfile $(patsubst $(dir $@)%-lib.built,\
		                    $(BUILD)/%-lib.log,$@) \
		-work $(patsubst $(dir $@)%-lib.built,%,$@) \
		$(filter %.vhd,$^)
	touch $@

# Create library and map library file to friendly logical name
$(BUILD)/%-lib: | $(BUILD)/modelsim.ini $(BUILD)
	cd $(dir $@) && $(VLIB) -unix $@
	cd $(dir $@) && $(VMAP) $(subst -lib,,$(notdir $@)) $@

# Init modelsim configuration from system wide skeleton
$(BUILD)/modelsim.ini: | $(BUILD)
	cd $(dir $@) && $(VMAP) -c

ifneq ($(shell uname -m),x86_64)

# co-simulation target dependencies and default rules for modelsim support
$(libfli) $(libvpi): | $(BUILD)/cocotb
	+$(MAKE) -j1 -f cocotb_libs.mk $@ $(modelsim-env) \
		USER_DIR=$(cocotb_libs)

else

# co-simulation target dependencies and default rules for modelsim support
$(libfli) $(libvpi): $(STAMPS)/python.installed | $(BUILD)/cocotb
	+$(MAKE) -j1 -f cocotb_libs.mk $@ $(modelsim-env) \
		USER_DIR=$(cocotb_libs)

################################################################################
# build 32 bits Python to run onto 64 bits platform
################################################################################
python-vers := 2.7.13
python-url  := https://www.python.org/ftp/python/$(python-vers)/Python-$(python-vers).tar.xz

.PHONY: install-python
install-python: $(STAMPS)/python.installed

$(STAMPS)/python.installed: $(STAMPS)/python.configured
	+$(MAKE) -j1 -C $(BUILD)/Python-$(python-vers)
	+$(MAKE) -j1 -C $(BUILD)/Python-$(python-vers) install
	touch $@

$(STAMPS)/python.configured: $(STAMPS)/openssl.installed | \
                             $(BUILD)/Python-$(python-vers)
	cd $(BUILD)/Python-$(python-vers) && \
		CC="$(CC) -m32" \
		CFLAGS="-I$(STAGING)/include" \
		LDFLAGS="-L$(STAGING)/lib -L/usr/lib32 -L/lib32 -Wl,-rpath,$(STAGING)/lib -Wl,-rpath,/usr/lib32 -Wl,-rpath,/lib32" \
		./configure --prefix=$(STAGING) --enable-shared
	touch $@

$(BUILD)/Python-$(python-vers): | $(BUILD)
	cd $(dir $@) && wget -O - $(python-url) | tar xJf -

################################################################################
# build 32 bits Openssl to run onto 64 bits platform
################################################################################
openssl-vers := 1.1.0e
openssl-url  := https://www.openssl.org/source/openssl-$(openssl-vers).tar.gz

.PHONY: install-openssl
install-openssl: $(STAMPS)/openssl.installed

$(STAMPS)/openssl.installed: $(STAMPS)/openssl.configured
	$(MAKE) -C $(BUILD)/openssl-$(openssl-vers)
	$(MAKE) -C $(BUILD)/openssl-$(openssl-vers) install
	touch $@

$(STAMPS)/openssl.configured: | $(BUILD)/openssl-$(openssl-vers) $(STAMPS)
	cd $(BUILD)/openssl-$(openssl-vers) && \
		./Configure --prefix=$(STAGING) linux-x86
	touch $@

$(BUILD)/openssl-$(openssl-vers): | $(BUILD)
	cd $(dir $@) && wget -O - $(openssl-url) | tar xzf -

endif
