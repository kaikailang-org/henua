# Changelog

All notable changes to henua are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project versions track Semantic Versioning loosely while
the surface is pre-1.0 (every release may break shape).

## [Unreleased]

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
