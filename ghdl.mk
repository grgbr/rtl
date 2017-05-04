GHDL          := $(STAGING)/bin/ghdl

cocotb_libs   := $(BUILD)/cocotb_libs
cocotb_libdir := $(cocotb_libs)/build/libs/$(shell uname -m)
libvpi        := $(cocotb_libdir)/libvpi.so

ghdl-flags    := --vital-checks \
                 -Wbinding \
                 -Wlibrary \
                 -Wvital-generic \
                 -Wbody \
                 -Wspecs \
                 -Wunused \
                 -Werror

define _runcosim
	env PYTHONPATH="$(TEST):$(cocotb_libdir):$(COCOTB)" \
	    LD_LIBRARY_PATH="$(cocotb_libdir)" \
	    MODULE=$(subst .ghw,,$(subst $(BUILD)/,,$(1))) \
	    COCOTB_REDUCED_LOG_FMT=1 \
	    TESTCASE= \
	    TOPLEVEL=$(subst _cosim.ghw,,$(subst $(BUILD)/,,$(1))) \
	    TOPLEVEL_LANG=vhdl \
	    $(GHDL) -r --ieee=standard --syn-binding --work=$(2) \
	        --workdir=$(BUILD) $(ghdl-flags) -P$(BUILD) \
	        $(subst _cosim.ghw,,$(subst $(BUILD)/,,$(1))) \
	        --vpi=$(libvpi) --wave=$(1)
	mv results.xml $(BUILD)
endef

define libobj
$(BUILD)/$(1)-obj93.cf
endef

define _libdep
$(patsubst $(BUILD)/%-obj93.cf,%,$(filter %-obj93.cf,$(1)))
endef

define _mklibdeps
$(BUILD)/$(1)-obj93.cf: $($(1)-lib)
endef

define _mkcosim
$(BUILD)/$(1)_cosim.ghw: $($(1)-cosim) $(libvpi)
	$(call _runcosim,$(BUILD)/$(1)_cosim.ghw,$(call _libdep,$($(1)-cosim)))
endef

# co-simulation target dependencies and default rules
$(libvpi): | $(BUILD)/cocotb
	+$(MAKE) -j1 -f cocotb_libs.mk $@ \
		SIM=ghdl SIM_ROOT=$(COCOTB) USER_DIR=$(cocotb_libs)

# libraries analysis default rule
$(BUILD)/%-obj93.cf: $(STAMPS)/ghdl.installed Makefile ghdl.mk
	$(GHDL) -a --ieee=standard \
	        --work=$(patsubst $(BUILD)/%-obj93.cf,%,$@) \
	        --workdir=$(BUILD) \
	        $(ghdl-flags) \
	        -P$(BUILD) \
	        $(filter %.vhd,$^)

################################################################################
# ghdl VHDL simulator build and install with default mcode backend
################################################################################
ghdl-url := git@github.com:tgingold/ghdl.git

.PHONY: install-ghdl
install-ghdl: $(STAMPS)/ghdl.installed

$(STAMPS)/ghdl.installed: $(STAMPS)/ghdl.configured
	cd $(BUILD)/ghdl && $(MAKE)
	cd $(BUILD)/ghdl && $(MAKE) install
	touch $@

$(STAMPS)/ghdl.configured: | $(BUILD)/ghdl $(STAMPS)
	cd $(BUILD)/ghdl && ./configure --prefix=$(STAGING)
	touch $@

$(BUILD)/ghdl: | $(BUILD)
	cd $(dir $@) && git clone $(ghdl-url)
