PWD := $(CURDIR)

SRC_DIR := $(PWD)/src
TESTSPACE_DIR := $(PWD)/testspace
TESTCASE_DIR := $(PWD)/testcase

SIM_TESTCASE_DIR := $(TESTCASE_DIR)/sim
FPGA_TESTCASE_DIR := $(TESTCASE_DIR)/fpga

SIM_DIR := $(PWD)/sim

V_SOURCES := $(shell find $(SRC_DIR) -name '*.v')

ONLINE_JUDGE ?= false

IV_FLAGS := -I$(SRC_DIR) -Wall -Wno-timescale

ifeq ($(ONLINE_JUDGE), true)
IV_FLAGS += -D ONLINE_JUDGE
all: build_sim
	@mv $(TESTSPACE_DIR)/test $(PWD)/code
else
all: testcases build_sim
endif

testcases:
	# docker run -it --rm -v "$(TESTCASE_DIR):/app" -w /app my-archlinux-image  make all
	@make -C $(TESTCASE_DIR)

_no_testcase_name_check:
ifndef name
	$(error name is not set. Usage: make run_sim name=your_testcase_name)
endif

build_sim: $(SIM_DIR)/testbench.v $(V_SOURCES)
	@iverilog $(IV_FLAGS) -o $(TESTSPACE_DIR)/test $(SIM_DIR)/testbench.v $(V_SOURCES)

build_sim_test: testcases _no_testcase_name_check
	@cp $(SIM_TESTCASE_DIR)/*$(name)*.c $(TESTSPACE_DIR)/test.c
	@cp $(SIM_TESTCASE_DIR)/*$(name)*.data $(TESTSPACE_DIR)/test.data
	@cp $(SIM_TESTCASE_DIR)/*$(name)*.dump $(TESTSPACE_DIR)/test.dump
	@rm -f $(TESTSPACE_DIR)/test.in $(TESTSPACE_DIR)/test.ans
	@cp $(SIM_TESTCASE_DIR)/*$(name)*.ans $(TESTSPACE_DIR)/test.ans
	@find $(SIM_TESTCASE_DIR) -name '*$(name)*.in' -exec cp {} $(TESTSPACE_DIR)/test.in \;


build_fpga_test: testcases _no_testcase_name_check
	@cp $(FPGA_TESTCASE_DIR)/*$(name)*.c $(TESTSPACE_DIR)/test.c
	@cp $(FPGA_TESTCASE_DIR)/*$(name)*.elf $(TESTSPACE_DIR)/test.elf
	@cp $(FPGA_TESTCASE_DIR)/*$(name)*.dump $(TESTSPACE_DIR)/test.dump
# sometimes the input and output file not exist
	@rm -f $(TESTSPACE_DIR)/test.in $(TESTSPACE_DIR)/test.ans
	@find $(FPGA_TESTCASE_DIR) -name '*$(name)*.in' -exec cp {} $(TESTSPACE_DIR)/test.in \;
	@find $(FPGA_TESTCASE_DIR) -name '*$(name)*.ans' -exec cp {} $(TESTSPACE_DIR)/test.ans \;

run_sim: build_sim build_sim_test
	# cd $(TESTSPACE_DIR) && ./test > test.log
	cd $(TESTSPACE_DIR) && time -p stdbuf -o0 ./test | tee test.out.raw && bash ./judge.sh


fpga_device := /dev/ttyUSB1
fpga_run_mode := -T # or -T

# Please manually load .bit file to FPGA
run_fpga: build_fpga_test
	@cd $(TESTSPACE_DIR) && if [ -f test.in ]; then stdbuf -o0 $(PWD)/fpga/fpga test.elf test.in $(fpga_device) $(fpga_run_mode) | tee test.out; else stdbuf -o0 $(PWD)/fpga/fpga test.elf $(fpga_device) $(fpga_run_mode) | tee test.out; fi && bash ./fpga_judge.sh

# "heart" runs too slow, so we exclude it 
# "testsleep" has no answer, you should manually check the output
test_list := testsleep queens expr lvalue2 magic looper superloop tak uartboom array_test2 pi multiarray manyarguments hanoi qsort gcd statement_test basicopt1 bulgarian array_test1

run_fpga_all: 
	@for name in $(test_list); do \
		echo -e "\033[34mrun on test $$name\033[0m"; \
		timeout 30s $(MAKE) run_fpga name=$$name 2>/dev/null >/dev/null; \
		retval=$$?; \
		if [ $$retval -eq 124 ]; then \
			echo -e "\033[33m$$name TLE >30s\033[0m"; \
			read -p "Please press the reset button on the FPGA, then press Enter to continue..."; \
		elif [ $$retval -eq 0 ]; then \
			echo -e "\033[32m$$name passed\033[0m"; \
		else \
			echo -e "\033[31m$$name failed\033[0m"; \
		fi; \
		sleep 1; \
	done

clean:
	rm -f $(TESTSPACE_DIR)/test*

.PHONY: all build_sim build_sim_test run_sim clean run_fpga_all run_fpga
