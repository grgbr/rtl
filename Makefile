PREFIX     := $(abspath $(HOME)/local)
BUILD      := $(abspath build)
TEST       := $(realpath test)
SRC        := $(realpath src)
COCOTB     := $(BUILD)/cocotb
STAMPS     := $(BUILD)/.stamps
STAGING    := $(BUILD)/staging
COCOTB_LOG := INFO
#COCOTB_LOG := DEBUG

include ghdl.mk
#include modelsim.mk

axi4ls_regs-cosim := $(TEST)/axi4ls_regs_cosim.py $(call libobj,tbench)
tmr_axi4ls-cosim  := $(TEST)/tmr_axi4ls_cosim.py $(TEST)/amba.py $(call libobj,time)
tmr_regs_tb-cosim := $(TEST)/tmr_regs_tb_cosim.py $(TEST)/monitor.py $(call libobj,tbench)
tmr_impl-cosim    := $(TEST)/tmr_impl_cosim.py $(call libobj,time)

# Test bench library
tbench-lib         := $(TEST)/axi4ls_regs.vhd \
                      $(TEST)/tmr_regs_tb.vhd \
                      $(call libobj,time)

# Time library
time-lib           := $(SRC)/timer_pkg.vhd \
                      $(SRC)/clock_pkg.vhd \
                      $(SRC)/tmr_regs.vhd \
                      $(SRC)/tmr_impl.vhd \
                      $(SRC)/tmr_axi4ls.vhd \
                      $(SRC)/clk_gate_impl.vhd \
                      $(call libobj,amba)

# Amba library
amba-lib           := $(SRC)/axi4_pkg.vhd $(SRC)/axi4l_slave.vhd


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
