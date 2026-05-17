# henua Makefile.
#
# henua is mostly pure-kaikai (Repository, Aggregate, EventBus,
# Validation, BoundedContext, DomainEvent) — for those fixtures
# `kai build` / `kai run` is sufficient with no orchestration.
# The SQLite-backed Repository adapter
# (`henua/sqlite_repository.kai`) is the exception: it imports
# `kohau.sqlite`, which binds libsqlite3 through a C shim that
# lives in the sibling `kohau` checkout.
#
# Pattern (idiomatic — mirrors `lnds/uira`'s raylib demos):
# `kai build` is the driver; the shim sources and the
# `-lsqlite3` link flag are passed through `CFLAGS`, which the
# `kai` wrapper forwards to its underlying `cc` invocation. We
# do NOT call `kaic2` directly — `kai build` owns the stdlib
# prelude assembly, package-path resolution, and edition gates.
#
# Requirements on the host:
#
#   - `kai` on PATH (`brew install lnds/kaikai/kaikai`).
#   - libsqlite3 development headers + library. macOS Homebrew
#     ships them under `/opt/homebrew/opt/sqlite/`; Linux distros
#     ship them under `/usr/include` and `/usr/lib` typically.
#   - The sibling `kohau` checkout at `../kohau`. Its `c/`
#     directory contains the shim sources henua's fixtures link
#     against (we do NOT duplicate the shim under henua).

KAI_BIN ?= kai

# SQLite. Override via `make SQLITE_INC=... SQLITE_LIB=...` if
# the installation is somewhere non-standard.
SQLITE_INC := /opt/homebrew/opt/sqlite/include
SQLITE_LIB := /opt/homebrew/opt/sqlite/lib

# Sibling kohau checkout (its `c/sqlite_shim.{c,h}` provides the
# extern symbols `henua.sqlite_repository` reaches via
# `kohau.sqlite`).
KOHAU_DIR := ../kohau
SHIM_C    := $(KOHAU_DIR)/c/sqlite_shim.c
SHIM_H    := $(KOHAU_DIR)/c/sqlite_shim.h

# Flags forwarded to `cc` via the `kai` driver. `-include` brings
# the shim declarations into the generated C; the shim source
# itself is appended so `cc` compiles + links it in one step;
# `-lsqlite3` resolves the libsqlite3 symbols the shim calls.
KAI_CFLAGS := -std=c99 -O2 -Wno-unused-function -Wno-unused-variable \
              -I$(SQLITE_INC) -include $(SHIM_H) $(SHIM_C) \
              -L$(SQLITE_LIB) -lsqlite3

BUILD = build

# Fixture discovery — split into FFI (sqlite_repository_*) and
# pure-kaikai. Both go through `kai build` / `kai run`; FFI
# fixtures additionally need `CFLAGS=$(KAI_CFLAGS)` to link the
# shim.
FFI_TEST_KAI   = $(wildcard tests/sqlite_repository_*.kai)
FFI_TEST_NAMES = $(patsubst tests/%.kai,%,$(FFI_TEST_KAI))
FFI_TEST_BINS  = $(addprefix $(BUILD)/,$(FFI_TEST_NAMES))

PURE_TEST_KAI   = $(filter-out $(FFI_TEST_KAI),$(wildcard tests/*.kai))
PURE_TEST_NAMES = $(patsubst tests/%.kai,%,$(PURE_TEST_KAI))

HENUA_SRC = $(wildcard henua/*.kai)
KOHAU_SRC = $(wildcard $(KOHAU_DIR)/kohau/*.kai)

.PHONY: tier0 tier1 tier1-pure tier1-ffi clean

# tier0: compile every fixture. Pure fixtures compile via
# `kai build` to a throwaway location (we only care about
# typecheck + codegen success); FFI fixtures compile to
# $(BUILD)/<name> for later execution by tier1-ffi.
tier0: $(FFI_TEST_BINS) tier0-pure
	@echo "tier0: henua modules + $(words $(FFI_TEST_BINS)) ffi fixtures + $(words $(PURE_TEST_NAMES)) pure fixtures compile."

tier0-pure: | $(BUILD)
	@set -e; \
	for n in $(PURE_TEST_NAMES); do \
	  $(KAI_BIN) build tests/$$n.kai -o $(BUILD)/$$n > /dev/null && echo "tier0: $$n compiles"; \
	done

# tier1: tier0 plus running each fixture and diffing stdout
# against its `.out.expected` sibling.
tier1: tier0 tier1-pure tier1-ffi
	@echo "tier1: $(words $(FFI_TEST_BINS)) ffi + $(words $(PURE_TEST_NAMES)) pure fixtures pass."

tier1-pure: tier0-pure
	@set -e; \
	for n in $(PURE_TEST_NAMES); do \
	  exp="tests/$$n.out.expected"; \
	  if [ ! -f "$$exp" ]; then echo "tier1: missing $$exp"; exit 1; fi; \
	  out="$(BUILD)/$$n.out"; \
	  $(BUILD)/$$n > "$$out"; \
	  diff -u "$$exp" "$$out" || { echo "tier1: $$n FAIL"; exit 1; }; \
	  echo "tier1: $$n OK"; \
	done

tier1-ffi: $(FFI_TEST_BINS)
	@set -e; \
	for n in $(FFI_TEST_NAMES); do \
	  bin="$(BUILD)/$$n"; \
	  exp="tests/$$n.out.expected"; \
	  out="$(BUILD)/$$n.out"; \
	  if [ ! -f "$$exp" ]; then echo "tier1: missing $$exp"; exit 1; fi; \
	  "$$bin" > "$$out"; \
	  diff -u "$$exp" "$$out" || { echo "tier1: $$n FAIL"; exit 1; }; \
	  echo "tier1: $$n OK"; \
	done

# FFI fixture build — `kai build` is the driver; the shim
# sources and `-lsqlite3` go through CFLAGS.
$(BUILD)/sqlite_repository_%: tests/sqlite_repository_%.kai $(HENUA_SRC) $(KOHAU_SRC) $(SHIM_C) $(SHIM_H) kai.toml | $(BUILD)
	CFLAGS="$(KAI_CFLAGS)" $(KAI_BIN) build $< -o $@

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
