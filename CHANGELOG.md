# Changelog

All notable changes to henua are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project versions track Semantic Versioning loosely while
the surface is pre-1.0 (every release may break shape).

## [0.6.1] - 2026-10-24

### Added

- **The fixtures pin the boundaries they used to skip.**
  `tests/sqlite_repository_invalid_table.kai` now accepts a
  one-character name, names built from the `a`/`z`/`A`/`Z`/`0`/`9`
  range edges, and a name of exactly 64 characters, and rejects one
  of 65. `tests/event_bus_unsubscribe.kai` removes the last handler
  and checks that an out-of-range index leaves the bus unchanged.
  `tests/validation_strings.kai` accepts a string whose length is
  exactly the upper bound. Tests only; no library code changed.

- **`tools/mutate-known-equivalent.txt`.** Lists the `kai mutate`
  mutants that mean the same as the original, each with the reason:
  the single-element match arms in `aggregate` and `event_bus` that
  the general `[x, ...rest]` arm already covers, and two rewrites in
  the SQLite table-name validator that accept and reject the same
  names.

## [0.6.0] - 2026-10-24

### Added

- **The Repository port lists and counts.** `Repository[a, i]` gains
  `size() : Int` and `all() : [a]`, the two operations the value form
  already had. The in-memory adapter answers from its map (`all` in
  ascending key order); the SQLite one with `SELECT COUNT(*)` and
  `SELECT data ... ORDER BY id`, skipping rows the codec cannot parse.

- **`sqlite_repository.transaction(c, body)`.** Runs a `with_sqlite`
  scope, or several over different tables, inside one
  `BEGIN IMMEDIATE` ... `COMMIT`. `Ok` commits; `Err`, whether from a
  statement that failed mid-body or from the body itself, rolls back
  and comes back unchanged. New fixture
  `tests/sqlite_repository_transaction.kai`.

### Changed

- **BREAKING: a hand-written `Repository` handler must cover `size`
  and `all`.** kaikai requires a clause for every op of the effect.
  `examples/repository_port`'s tracing adapter shows the two clauses.

- **BREAKING: `sqlite_repository.size(c, table)` is removed.** Use
  `Repository.size()` inside `with_sqlite`.

## [0.5.0] - 2026-10-24

### Changed

- **BREAKING: the SQLite adapter handles the Repository port.**
  `sqlite_repository.with_sqlite(c, table, codec, body)` (and
  `with_sqlite_delim`) validates the table name, creates the table,
  and runs `body` under a `Repository[a, i]` handler, returning
  `Result[r, RepositoryError]`. Domain code calls `Repository.find /
  save / delete` exactly as under `with_in_memory`. A statement that
  fails mid-body aborts it with `Err(Backend(...))`; `delete` of an
  absent id returns `False` rather than `Err(NotFound)`.
  `SqliteRepository`, `make_sqlite`, `make_sqlite_with_delim` and the
  value-form `save / find / delete` are gone: kaikai 0.165.0 rejects
  returning a `Pid` held in a record field, so the value could no
  longer be built. `size(c, table)` takes the client and table name.

- **Requires kaikai 0.174.0.** 0.167.0 through 0.173.0 reject
  `event_bus.subscribe` and `repository_effect.with_in_memory` with
  effects they do not perform (lnds/kaikai#3142). tier1 passes 14/14
  on 0.174.0 (4 ffi + 10 pure fixtures).

### Added

- **`tests/sqlite_repository_backend_error.kai`**: a statement that
  fails mid-body aborts it and surfaces as `Err(Backend(...))`.

- **A roadmap with one milestone per release** in `docs/design.md`.
  The design's "v0.1" / "v0.2" phase labels, which never matched the
  package versions, give way to release numbers.

### Fixed

- **`examples/catalog` compiles again.** The edition migration had
  rewritten its `ProductId` refinement as
  `regexp.compile_or_panic()("...")`, a call with no argument; it is
  back to the `~r/.../` literal.

## [0.4.0] - 2026-10-12

### Changed

- **The kohau sqlite shim is no longer this package's problem.**
  kohau v0.5.0 declares it in a `[native]` table, so `kai build`
  compiles and links it while resolving the dependency. The Makefile
  used to read the locked kohau SHA out of `kai.lock`, derive the
  shim's path inside the module cache, and pass it through `CFLAGS`
  together with the include and library directories; all of that is
  gone, and the FFI fixtures build with the same plain invocation as
  the pure ones.

- **The adapter renders kohau's structured error.** kohau's sqlite
  client returns a `SqliteError` record (code, extended code,
  message) rather than a string, so `Backend(...)` carries
  `client.error_to_string(err)`.

### Added

- **A tier1 workflow.** Every pull request and every push to `main`
  compiles each fixture, runs it, diffs its output, and fails if the
  build emitted a warning from this package. The compiler comes from
  the official installer, unpinned, so a release that breaks henua
  surfaces as a failed run.

### Changed

- **Verified against kaikai 0.145.0.** tier1 passes 13/13 with the
  sources unchanged (3 ffi + 10 pure fixtures). No source change has
  been needed since 0.110.0.

### Fixed

- **A fresh checkout builds in one pass.** The shim paths are composed
  from a SHA read out of the lockfile, which does not exist in a fresh
  checkout — the build generates it. Read immediately, that SHA
  resolved to the empty string while the makefile was still being
  parsed, leaving the shim under a directory that never exists, so the
  first build of a clone could not succeed at all.

- **The `[unstable]` keys are spelled as module paths.** An
  acknowledgement key is the declaration's mangled module path with the
  package name on the front — `henua__sqlite_repository`,
  `kohau__sqlite` — so the bare names the manifest carried matched
  nothing and silenced nothing.

## [0.3.1] - 2026-08-09

### Fixed

- **`kai.toml` declared `edition = "orongo"`, an edition that does
  not exist yet.** The compiler never implemented it: `kaic2` warns
  that the selected edition is unavailable and silently proceeds
  under `hanga-roa` semantics, so the pin described something other
  than what was being compiled. The manifest now declares
  `edition = "hanga-roa"`, the only edition the toolchain provides.

  The 0.3.0 notes below have been corrected accordingly. The change
  they describe — `Result`'s type-argument order flipping to
  `Result[Ok, Error]` in kaikai 0.101 — is real and landed *within*
  `hanga-roa`; only the attribution to an edition was wrong. No
  source changed, and consumers need no edition declaration of their
  own.

### Changed

- **Verified against kaikai 0.110.0.** tier1 passes 13/13 with the
  sources unchanged. `examples/catalog` picked up canonical
  formatting (0.110's formatter drops a redundant paren group), and
  `examples/ledger`'s `Account` record is now written multi-line so
  its field comment stays attached to `balance_minor`. The Makefile's
  host requirement moves to 0.101.0+ — the floor the `Result`
  annotations actually impose.
- **`sqlite` joins the `[unstable]` opt-ins.** `kai lint` reports the
  raw `kohau.sqlite` FFI decls reached transitively through the
  cell-wrapped client; the build was already quiet, and the linter is
  now quiet too, on the same grounds `cell` is already listed.

## [0.3.0] - 2026-07-26

### Changed

- **The sources move to `Result[Ok, Error]` (kaikai 0.104).** kaikai
  0.101 flipped `Result`'s type-argument order from
  `Result[Error, Ok]` to `Result[Ok, Error]`, so every annotation in
  the package stopped typing against the current compiler. The 22
  affected annotations across `validation`, `repository`,
  `sqlite_repository` and the fixtures were rewritten with
  `kai migrate`. The package stays on `edition = "hanga-roa"`, the
  only edition the compiler implements today.

  `Ok` and `Err` are position-independent, so consumers that match by
  constructor are unaffected; consumers that *annotate* a henua
  result must flip the annotation. The rewrite runs through the
  fmt-writer, so the sources also picked up canonical 0.104
  formatting.

- **`kohau` moves to v0.4.0 and `ahu` to v0.2.1.** The SQLite
  repository reaches kohau's cell-wrapped client, and kohau v0.4.0 is
  the first release carrying the same `Result` flip — earlier tags
  return `Result` in the pre-flip order and no longer type against the
  migrated adapter. ahu moves to the version kohau itself depends on,
  so both paths resolve one copy. tier1 stays green: 3 ffi + 10 pure
  fixtures pass against kaikai 0.104.

## [0.2.0] - 2026-07-02

### Added

- `henua/repository_effect.kai` — Repository as a **port**: the
  `Repository[a, i]` *effect*, complementing the value form in
  `repository.kai`. A domain function declares `/ Repository[a, i]`
  in its row and calls `Repository.find / save / delete`; which
  adapter is plugged in is decided by the enclosing handler
  (`with_in_memory` / `with_in_memory_seeded` ship today) at the
  composition root. New fixture
  `tests/repository_effect_roundtrip.kai` and example
  `examples/repository_port/` (same domain under two adapters).

### Changed

- **Sources updated for kaikai 0.98.** Two syntax changes landed
  upstream between 0.86 and 0.98 and are now reflected in henua:

  - `var` cells are declared with `:=` (`var store : Map[i, a]
    := initial`); `=` on a `var` is a compile error.
  - `var` cells are read naked (`map.get(store, key)`); the `@`
    dereference is now reserved for first-class `Ref[T]` values.

  Both changes touch `henua/repository_effect.kai` and
  `examples/repository_port/main.kai` only. Behaviour-preserving:
  tier1 stays 3 ffi + 10 pure fixtures green and the three
  examples' golden outputs are byte-identical under kaikai 0.98.0.
  The Makefile's minimum-`kai` note moves from 0.83.0+ to 0.98.0+,
  since the new cell syntax does not compile on older toolchains.

- **License set to MIT.** `LICENSE` added at the repo root,
  `license = "MIT"` declared in `kai.toml`, and the README's
  "TBD" license section resolved.

- **`sqlite_repository` migrated from the borrowed `db: Int`
  handle to kohau's cell-wrapped client.** This closes the debt
  the previous CHANGELOG flagged: *"connection lifecycle moves
  into kohau.sqlite.client once that lands."* It has landed.

  - `SqliteRepository[a, i]` now carries `client: Pid[SqlMsg]`
    instead of `db: Int`. The import changes from `kohau.sqlite`
    (raw FFI) to `kohau.sqlite.client` (the cell).
  - Every operation's row changes from `/ Ffi` to
    `/ Actor[SqlMsg]`. The adapter no longer touches libsqlite3
    directly — prepare / bind / step / finalize are gone, replaced
    by `client.exec` / `query_row` / `query_scalar`. The cell-fiber
    is the sole owner of the FFI boundary; henua never sees a raw
    handle, a libsqlite3 status code, or an `Ffi` effect again.
  - `make_sqlite(c, table, codec)` / `make_sqlite_with_delim`
    take the client pid instead of a `db` handle. The strict
    table-name validation (the §*Security* hardening) is preserved
    verbatim. The adapter does NOT own the client lifecycle — the
    caller's `kohau.sqlite.client.with_client(path, body)` scope
    does, and the `SqliteRepository` is constructed inside `body`.
  - The borrowed-`db` form is **removed**, not kept alongside —
    henua is pre-1.0, every `pub` is `#[unstable]`, and the
    project follows "few forms, each with clear intent". A second
    adapter doing the same thing through a raw handle would be a
    liability, not a migration aid.
  - **Behaviour-preserving.** The three FFI fixtures
    (`sqlite_repository_roundtrip`, `_not_found`, `_invalid_table`)
    were rewritten to drive the adapter through `with_client` —
    their golden output is byte-identical to the borrowed-`db`
    version. Same semantics, FFI sealed inside the cell. tier1
    stays 3 ffi + 10 pure fixtures green under kaikai 0.86.1.

- **`kai.toml`: kohau bumped to v0.2.0; ahu added as a git-dep.**
  kohau is pinned to `ref = "v0.2.0"` — the release that ships
  `kohau.sqlite.client`. `ahu` is added as a direct git-dep
  (`ref = "v0.1.0"`): henua's adapter delegates to an `ahu.cell`
  and the fixtures call `ahu.cell.ask` transitively, and
  dependency resolution does not thread a dependency's own deps to
  the consumer's module path, so ahu must be declared directly.
  `kai install` fetches both into the user-level cache and records
  the resolved SHAs in `kai.lock`. The Makefile reads the kohau SHA
  back from the lockfile to locate the C shim under the cache root.
  tier1 is green with both deps resolved from the remote — no
  sibling checkout required.

## [0.1.0] - 2026-05-24

### Changed

- **kohau dependency migrated from path-dep to git-dep.**
  `kai.toml` switches `kohau = { path = "../kohau" }` to
  `kohau = { source = "github.com/kaikailang-org/kohau",
  ref = "v0.1.0" }`. henua no longer assumes a sibling
  checkout — `kai install` fetches the pinned kohau release
  into the user-level cache and the lockfile (`kai.lock`,
  new this release) records the resolved SHA. The Makefile
  parses `kai.lock` to find the cached path of the
  `c/sqlite_shim.{c,h}` shim (which travels with the kohau
  repo) instead of looking under `../kohau/c/`. Build
  requirements: `kai` 0.83.0+ for git-dep resolution and a
  successful `kai install` before `make tier1-ffi` (the
  Makefile auto-runs install if `kai.lock` is absent or
  older than `kai.toml`). tier1 stays 3 ffi + 9 pure
  fixtures green.

### Security

- `sqlite_repository.make_sqlite` and `make_sqlite_with_delim`
  now validate the `table` argument against a strict
  SQL-identifier subset (first char ASCII letter or underscore,
  remaining ASCII letters / digits / underscores, length 1..64)
  and reject anything else with
  `Err(Backend("invalid table name: <input>"))`. SQLite's
  prepared-statement protocol does not parameterise
  identifiers, so the table name is necessarily concatenated
  into the DDL/DML the adapter builds. Validation closes the
  resulting SQL-injection foot-gun for callers that take the
  table name from configuration or untrusted input. Module
  header gains a §*Security* section documenting the accepted
  shape and the caller-side discipline (never feed unvalidated
  external input as the table name). Behaviour-preserving for
  every legitimate identifier; invalid names that previously
  reached SQLite now fail fast before the connection is touched.
  New fixture `tests/sqlite_repository_invalid_table.kai`
  locks down four acceptance cases and seven rejection cases
  (empty, embedded space, semicolon-injection, SQL comment,
  embedded quote, leading digit, punctuation). tier1 FFI grows
  from 2 to 3 fixtures, all green under kaikai 0.82.0 hanga-roa.

### Added

- `henua/sqlite_repository.kai` — SQLite-backed Repository
  adapter built on `kohau.sqlite` (v0.1, low-level surface).
  Mirrors the InMemory adapter's surface (`save` / `find` /
  `delete` / `size`) but every operation carries `Ffi` in its
  row. Polymorphic in the aggregate `a` and id `i` via an
  inline `RepositoryCodec[a, i]` (OPTION A — record of
  serialiser functions). Schema is minimal v1: `(id TEXT
  PRIMARY KEY, data TEXT NOT NULL)`; row payload joined with
  `|` by default (overridable via `make_sqlite_with_delim`).
  Every `pub` is `#[unstable]` under the Hanga Roa edition.

- `Makefile` for tier0 / tier1 orchestration. The FFI fixtures
  (`tests/sqlite_repository_*.kai`) link the sibling `kohau`
  C shim and libsqlite3 by passing `-include`, the shim source,
  and `-lsqlite3` through `CFLAGS` to `kai build` (idiomatic
  pattern — mirrors `lnds/uira`'s raylib demos). Pure fixtures
  continue to build via plain `kai build`.

- `tests/sqlite_repository_roundtrip.kai` — round-trip
  fixture: open `:memory:`, make adapter, save / find /
  replace / delete / find-after-delete against a `Todo`
  aggregate with a bool field. Confirms the polymorphic shape
  threads through with `Ffi` in the row and the codec round-
  trips clean.

- `tests/sqlite_repository_not_found.kai` — `delete` on absent
  id returns `Err(NotFound)`; `find` on absent id returns
  `Ok(None)`. Mirrors the InMemory adapter's
  `repository_delete_missing.kai` against the SQLite backend.

### Changed

- `kai.toml` gained a `[dependencies]` entry for the local
  `kohau` checkout and a `[unstable]` opt-in block for
  `henua`, `sqlite`, `kohau`, and `sqlite_repository` (so the
  in-tree tier1 build is warning-free).

### Known limitations / follow-ups

- The SQLite adapter has no transaction surface; atomicity
  across multiple `save` / `delete` calls is the caller's job
  (`sqlite.exec(db, "BEGIN")` / `"COMMIT"`).
- The connection (`db: Int`) is borrowed, not owned — the
  adapter never closes it. This matches kohau v0.1; lifecycle
  ownership moves into `kohau.sqlite.client` (cell-wrapped,
  v0.2) when that lands.
- The codec round-trip is not enforced — a buggy codec
  surfaces as `Ok(None)` from `find`, indistinguishable from
  "id absent". A future `MalformedRow` variant on
  `RepositoryError` would split them; today the demo's codec
  is trivial enough that this has not bitten anyone.
- `#[unstable]` warnings continue to fire on the
  generated-C path for some shim-linked extern calls even
  when the package opts in via `[unstable]` in `kai.toml`.
  Upstream bug in the `kai build` → `cc` flow when extern
  decls are reached transitively through a dependency;
  tracked as a follow-up against kaikai. Does not block
  tier1.
