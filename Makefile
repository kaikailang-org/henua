# henua Makefile.
#
# henua is mostly pure-kaikai (Repository, Aggregate, EventBus,
# Validation, BoundedContext, DomainEvent). The SQLite-backed
# Repository adapter (`henua/sqlite_repository.kai`) is the
# exception: it imports `kohau.sqlite`, which binds libsqlite3
# through a C shim.
#
# That shim needs nothing from here. kohau declares it in a
# `[native]` table, so `kai build` compiles and links it as part of
# resolving the dependency — the same plain invocation the pure
# fixtures use. We do NOT call `kaic2` directly: `kai build` owns
# the stdlib prelude assembly, package-path resolution, and edition
# gates.
#
# Requirements on the host:
#
#   - `kai` on PATH — install via
#     `curl -fsSL https://raw.githubusercontent.com/kaikailang-org/kaikai/main/install.sh | sh`
#     or `brew install kaikailang-org/kaikai/kaikai`.
#     Version 0.174.0+ (0.167.0 through 0.173.0 charge the event
#     bus and the in-memory Repository handler with effects they do
#     not perform). Verified against 0.174.0, edition hanga-roa.
#   - libsqlite3 development headers + library. macOS Homebrew
#     ships them under `/opt/homebrew/opt/sqlite/`; Linux distros
#     ship them under `/usr/include` and `/usr/lib` typically.
#   - A successful `kai install` before `make tier1-ffi` (the
#     ffi target depends on the lockfile and the cache contents).

KAI_BIN ?= kai

BUILD = build

# Fixture discovery — split into FFI (sqlite_repository_*) and
# pure-kaikai. Both build and run identically; the split exists
# because the FFI ones need libsqlite3 on the host, so a failure
# there reads as a missing library rather than a broken adapter.
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

# FFI fixture build. Depends on kai.lock because the shim arrives
# with the locked kohau package; the compiler builds it from there.
$(BUILD)/sqlite_repository_%: tests/sqlite_repository_%.kai $(HENUA_SRC) kai.toml kai.lock | $(BUILD)
	$(KAI_BIN) build $< -o $@

# kai.lock — produced by `kai fetch`. Treat it as a build
# input so tier1-ffi runs a fetch when the lockfile is absent
# or stale relative to kai.toml.
kai.lock: kai.toml
	$(KAI_BIN) fetch

$(BUILD):
	mkdir -p $(BUILD)

clean:
	rm -rf $(BUILD)
