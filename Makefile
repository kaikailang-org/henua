# henua Makefile.
#
# henua is mostly pure-kaikai (Repository, Aggregate, EventBus,
# Validation, BoundedContext, DomainEvent) — for those fixtures
# `kai build` / `kai run` is sufficient with no orchestration.
# The SQLite-backed Repository adapter
# (`henua/sqlite_repository.kai`) is the exception: it imports
# `kohau.sqlite`, which binds libsqlite3 through a C shim
# (`c/sqlite_shim.{c,h}`) that ships inside the kohau repo.
#
# Pattern (idiomatic — mirrors `lnds/uira`'s raylib demos):
# `kai build` is the driver; the shim sources and the
# `-lsqlite3` link flag are passed through `CFLAGS`, which the
# `kai` wrapper forwards to its underlying `cc` invocation. We
# do NOT call `kaic2` directly — `kai build` owns the stdlib
# prelude assembly, package-path resolution, and edition gates.
#
# Resolution of the shim sources:
#   1. `kai install` fetches the kohau git-dep pinned in
#      kai.toml into the user-level cache.
#   2. The lockfile (kai.lock) records the resolved SHA.
#   3. This Makefile parses kai.lock to find that SHA and
#      derives the shim path from the cache root.
# No sibling-checkout assumption: kohau as a kaikai package
# arrives via `kai install`, and the C shim that ships
# alongside the kaikai code arrives in the same fetch.
#
# Requirements on the host:
#
#   - `kai` on PATH — install via
#     `curl -fsSL https://raw.githubusercontent.com/kaikailang-org/kaikai/main/install.sh | sh`
#     or `brew install kaikailang-org/kaikai/kaikai`.
#     Version 0.101.0+ (the sources annotate `Result[Ok, Error]`,
#     the argument order the flip landed there; 0.98 brought the
#     `var name := init` cell syntax and naked cell reads).
#     Verified against 0.110.0, edition hanga-roa.
#   - libsqlite3 development headers + library. macOS Homebrew
#     ships them under `/opt/homebrew/opt/sqlite/`; Linux distros
#     ship them under `/usr/include` and `/usr/lib` typically.
#   - A successful `kai install` before `make tier1-ffi` (the
#     ffi target depends on the lockfile and the cache contents).

KAI_BIN ?= kai

# SQLite. Override via `make SQLITE_INC=... SQLITE_LIB=...` if
# the installation is somewhere non-standard.
SQLITE_INC := /opt/homebrew/opt/sqlite/include
SQLITE_LIB := /opt/homebrew/opt/sqlite/lib

# Locate the kohau C shim. kohau is a git-dep (see kai.toml), so
# the shim travels with the cached package: `kai install` fetches
# kohau into the user-level cache and pins the resolved SHA in
# kai.lock; we read that SHA back and derive the shim path under the
# cache root.
KAI_CACHE_ROOT ?= $(shell \
  if [ -d "$$HOME/Library/Caches/kai" ]; then echo "$$HOME/Library/Caches/kai"; \
  elif [ -n "$$XDG_CACHE_HOME" ]; then echo "$$XDG_CACHE_HOME/kai"; \
  else echo "$$HOME/.cache/kai"; fi)

# Pull the kohau SHA out of the kohau block in kai.lock. The lock
# line is `sha = "<40 hex>"`; strip quotes and whitespace.
KOHAU_SHA = $(shell awk '/name = "kohau"/{f=1} f && /sha =/{gsub(/[" ]/,"",$$3); print $$3; exit}' kai.lock 2>/dev/null)

KOHAU_DIR := $(KAI_CACHE_ROOT)/pkg/github.com/kaikailang-org/kohau/$(KOHAU_SHA)
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
$(BUILD)/sqlite_repository_%: tests/sqlite_repository_%.kai $(HENUA_SRC) $(SHIM_C) $(SHIM_H) kai.toml kai.lock | $(BUILD)
	CFLAGS="$(KAI_CFLAGS)" $(KAI_BIN) build $< -o $@

# kai.lock — produced by `kai install`. Treat it as a build
# input so tier1-ffi runs an install when the lockfile is absent
# or stale relative to kai.toml.
kai.lock: kai.toml
	$(KAI_BIN) install

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
