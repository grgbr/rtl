PREFIX  := $(abspath $(HOME)/local)
BUILD   := $(abspath build)
TEST    := $(realpath test)
SRC     := $(realpath src)
COCOTB  := $(BUILD)/cocotb
STAMPS  := $(BUILD)/.stamps
STAGING := $(BUILD)/staging

include ghdl.mk
#include modelsim.mk

axi4ls_timer-cosim := $(TEST)/axi4ls_timer_cosim.py $(call libobj,time)

# Amba library
amba-lib           := $(SRC)/axi4_pkg.vhd $(SRC)/axi4l_slave.vhd

# Time library
time-lib           := $(SRC)/axi4ls_timer.vhd \
                      $(SRC)/timer.vhd \
                      $(call libobj,amba)

$(foreach s,$(subst -cosim,,\
  $(filter %-cosim,$(.VARIABLES))),$(eval $(call _mkcosim,$(s))))

$(foreach s,$(subst -lib,,$(filter %-lib,$(.VARIABLES))),\
  $(eval $(call _mklibdeps,$(s))))

.PHONY: cosim-%
cosim-%: $(BUILD)/%_cosim.ghw ;

# cleanup everything
.PHONY: clean
clean:
	$(RM) -r $(BUILD)

################################################################################
# Get cocotb, a co-simulation framework
################################################################################
cocotb-url := git@github.com:potentialventures/cocotb.git

.PHONY: install-cocotb
install-cocotb: $(BUILD)/cocotb

$(BUILD)/cocotb: | $(BUILD)
	cd $(dir $@) && git clone $(cocotb-url)

$(BUILD) $(STAMPS):
	mkdir -p $@
