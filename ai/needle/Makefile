CC ?= cc
LUAJIT ?= luajit
NEEDLE_SOURCE ?= ../../../../needle
NEEDLE_PYTHON ?= $(NEEDLE_SOURCE)/.venv/bin/python
NEEDLE_TOKENIZER := $(NEEDLE_SOURCE)/needle/tokenizer/needle.model
NEEDLE_CHECKPOINT := $(NEEDLE_SOURCE)/checkpoints/needle.pkl

BUILD_DIR := build
SRC_DIR := src
LIB := $(BUILD_DIR)/libneedle_runtime.so
FIXTURE := $(BUILD_DIR)/test-model.ndl
TOKENIZER := $(BUILD_DIR)/tokenizer.ndltok
GOLDEN_ENCODER_ATTN := $(BUILD_DIR)/golden_encoder_self_attention.json
REAL_MODEL := $(BUILD_DIR)/needle.bin
Q8_MODEL := $(BUILD_DIR)/needle-q8.bin
Q8_STRIPPED_MODEL := $(BUILD_DIR)/needle-q8-stripped.bin
REAL_GOLDEN_ENCODER_ATTN := $(BUILD_DIR)/golden_real_encoder_self_attention.json
SRCS := $(SRC_DIR)/needle_runtime.c $(SRC_DIR)/needle_tokenizer.c $(SRC_DIR)/needle_kernels.c
HEADERS := $(SRC_DIR)/needle_runtime.h $(SRC_DIR)/needle_tokenizer.h $(SRC_DIR)/needle_kernels.h

CFLAGS ?= -O2 -g
CFLAGS += -std=c11 -Wall -Wextra -Wpedantic -fPIC -fvisibility=hidden -DNEEDLE_RUNTIME_BUILD
LDFLAGS ?=
LDFLAGS += -shared -lm

.PHONY: all clean test test-ci test-all example example-tool example-tool-q8 example-stream bench-kv bench-profile bench-q8 bench-q8-stripped bench-q8-quality export-q8 export-q8-stripped

all: $(LIB)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(LIB): $(SRCS) $(HEADERS) | $(BUILD_DIR)
	$(CC) $(CFLAGS) $(SRCS) $(LDFLAGS) -o $@

$(FIXTURE): scripts/write_test_fixture.py | $(BUILD_DIR)
	python3 scripts/write_test_fixture.py $@

$(TOKENIZER): scripts/export_tokenizer_runtime.py $(NEEDLE_TOKENIZER) | $(BUILD_DIR)
	$(NEEDLE_PYTHON) scripts/export_tokenizer_runtime.py --model $(NEEDLE_TOKENIZER) --output $@

$(GOLDEN_ENCODER_ATTN): scripts/golden_encoder_self_attention.py | $(BUILD_DIR)
	python3 scripts/golden_encoder_self_attention.py

$(REAL_MODEL): scripts/export_needle_runtime.py scripts/export_tokenizer_runtime.py $(NEEDLE_CHECKPOINT) $(NEEDLE_TOKENIZER) | $(BUILD_DIR)
	$(NEEDLE_PYTHON) scripts/export_needle_runtime.py --checkpoint $(NEEDLE_CHECKPOINT) --tokenizer $(NEEDLE_TOKENIZER) --output $@

$(Q8_MODEL): scripts/export_needle_runtime.py scripts/export_tokenizer_runtime.py $(NEEDLE_CHECKPOINT) $(NEEDLE_TOKENIZER) | $(BUILD_DIR)
	$(NEEDLE_PYTHON) scripts/export_needle_runtime.py --checkpoint $(NEEDLE_CHECKPOINT) --tokenizer $(NEEDLE_TOKENIZER) --output $@ --quantize-int8

$(Q8_STRIPPED_MODEL): scripts/export_needle_runtime.py scripts/export_tokenizer_runtime.py $(NEEDLE_CHECKPOINT) $(NEEDLE_TOKENIZER) | $(BUILD_DIR)
	$(NEEDLE_PYTHON) scripts/export_needle_runtime.py --checkpoint $(NEEDLE_CHECKPOINT) --tokenizer $(NEEDLE_TOKENIZER) --output $@ --quantize-int8 --strip-quantized-float-kernels

$(REAL_GOLDEN_ENCODER_ATTN): scripts/golden_real_encoder_self_attention.py $(NEEDLE_CHECKPOINT) | $(BUILD_DIR)
	$(NEEDLE_PYTHON) scripts/golden_real_encoder_self_attention.py --checkpoint $(NEEDLE_CHECKPOINT) --tokenizer $(NEEDLE_TOKENIZER) --output $@

test: $(LIB) $(FIXTURE) $(TOKENIZER) $(GOLDEN_ENCODER_ATTN)
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_ffi.lua
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_loader.lua "$(abspath $(FIXTURE))"
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_loader_errors.lua "$(abspath $(FIXTURE))"
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_api.lua
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_tokenizer.lua "$(abspath $(TOKENIZER))"
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_constraints_malformed.lua "$(abspath $(TOKENIZER))"
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_model.lua "$(abspath $(FIXTURE))"
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_memory_stats.lua "$(abspath $(FIXTURE))"
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_kernels.lua
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_encoder_attention_golden.lua "$(abspath $(FIXTURE))" "$(abspath $(GOLDEN_ENCODER_ATTN))"

test-ci: test

.PHONY: test-real
test-real: $(LIB) $(REAL_MODEL) $(Q8_STRIPPED_MODEL) $(TOKENIZER) $(REAL_GOLDEN_ENCODER_ATTN)
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_real_encoder_attention_golden.lua "$(abspath $(REAL_MODEL))" "$(abspath $(REAL_GOLDEN_ENCODER_ATTN))"
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_quantized_runtime.lua "$(abspath $(REAL_MODEL))" "$(abspath $(Q8_STRIPPED_MODEL))" "$(abspath $(TOKENIZER))"
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) tests/test_embedded_tokenizer.lua "$(abspath $(Q8_STRIPPED_MODEL))"

test-all: test test-real

example: $(LIB) $(REAL_MODEL) $(TOKENIZER)
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) examples/run.lua "$(abspath $(REAL_MODEL))"

example-tool: $(LIB) $(REAL_MODEL) $(TOKENIZER)
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) examples/tool_call.lua "$(abspath $(REAL_MODEL))" "$(abspath $(TOKENIZER))"

example-tool-q8: $(LIB) $(Q8_STRIPPED_MODEL) $(TOKENIZER)
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) examples/tool_call.lua "$(abspath $(Q8_STRIPPED_MODEL))" "$(abspath $(TOKENIZER))"

example-stream: $(LIB) $(Q8_STRIPPED_MODEL) $(TOKENIZER)
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) examples/stream.lua "$(abspath $(Q8_STRIPPED_MODEL))" "$(abspath $(TOKENIZER))"

bench-kv: $(LIB) $(REAL_MODEL) $(TOKENIZER)
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) benchmarks/kv_cache.lua "$(abspath $(REAL_MODEL))" "$(abspath $(TOKENIZER))"

bench-profile: $(LIB) $(REAL_MODEL) $(TOKENIZER)
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) benchmarks/profile_runtime.lua "$(abspath $(REAL_MODEL))" "$(abspath $(TOKENIZER))"

bench-q8: $(LIB) $(REAL_MODEL) $(Q8_MODEL) $(TOKENIZER)
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) benchmarks/quant_compare.lua "$(abspath $(REAL_MODEL))" "$(abspath $(Q8_MODEL))" "$(abspath $(TOKENIZER))"

bench-q8-stripped: $(LIB) $(REAL_MODEL) $(Q8_STRIPPED_MODEL) $(TOKENIZER)
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) benchmarks/quant_compare.lua "$(abspath $(REAL_MODEL))" "$(abspath $(Q8_STRIPPED_MODEL))" "$(abspath $(TOKENIZER))"

bench-q8-quality: $(LIB) $(REAL_MODEL) $(Q8_STRIPPED_MODEL) $(TOKENIZER)
	NEEDLE_RUNTIME_LIB="$(abspath $(LIB))" LUA_PATH="./?.lua;;" $(LUAJIT) benchmarks/quant_quality.lua "$(abspath $(REAL_MODEL))" "$(abspath $(Q8_STRIPPED_MODEL))" "$(abspath $(TOKENIZER))"

export-q8: $(Q8_MODEL)

export-q8-stripped: $(Q8_STRIPPED_MODEL)

clean:
	rm -rf $(BUILD_DIR)
