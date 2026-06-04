# Changelog

All notable changes to henua are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project versions track Semantic Versioning loosely while
the surface is pre-1.0 (every release may break shape).

## [Unreleased]

### Changed

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
