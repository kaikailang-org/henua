# henua design

Living document for the DDD building-block package that runs on
top of kaikai and underneath manutara and hopu.

> **Status:** 0.5.0. Repository, Aggregate, Domain Event,
> EventBus, Validation, and Bounded Context conventions are in
> place with pure, in-memory reference implementations. The
> Repository ships in two complementary forms — the value form
> (`henua.repository`) and the port/effect form
> (`henua.repository_effect`, see Decision 9) — and the port has
> a SQLite adapter over `kohau`. What is left is in §*Roadmap*.

## Context

henua is the fourth layer of the kaikai ecosystem:

```
kaikai      (the language)
   ↓
ahu         (concurrency and fault-tolerance)
   ↓
kohau       (database / persistence)
   ↓
henua       (this project — DDD building blocks)
   ↓
   ├──▶ manutara    (web framework, LiveView-shaped)
   └──▶ hopu        (background jobs / queue / scheduler)
```

Names follow the Rapa Nui vocabulary established by `kaikai`.
`henua` means *land / territory / domain* — the DDD-vocabulary
mapping is direct.

henua's job, in one sentence: **provide the vocabulary and
minimal helpers for Aggregate, Repository, Domain Event, Event
Bus, and Bounded Context — built directly on kaikai primitives
(records, sum types, refinement types, `Result`, effect rows) —
without dragging in any framework opinions about persistence,
routing, transport, or scheduling.**

henua is **not** an ORM. See §*Why henua is not an ORM* below.

This document is updated as decisions are closed.

## Why henua is not an ORM

Object-relational mappers (Hibernate, ActiveRecord, Sequelize,
SQLAlchemy, GORM) are the canonical answer in many ecosystems to
"how do I persist domain objects?" The temptation to copy that
shape is real — schemas mapped to types, change-tracking, lazy
loading, identity maps, and migrations all worked for decades on
relational databases. But that shape carries assumptions kaikai
does not share, and answers questions henua deliberately leaves
to other layers.

| ORM solves | Because the host language has | kaikai has |
|---|---|---|
| Identity map + change tracking | Mutable objects + ambient session state | **Immutable records** — every "change" is a new value; tracking is a fold over the change set |
| Lazy loading | Implicit `null` references that touch the DB on access | **Explicit `Option[a]`** — absence is a value, never a magic side effect |
| Schema-from-types code gen | No way to introspect type definitions at run time | **No reflection / no type-level meta-programming** — schema definition lives where SQL or persistence layer wants it (kohau's job) |
| Migration runners | Production deployment that schedules schema changes between code releases | **Out of scope for henua** — migration tooling is a separate concern of the persistence layer |
| `N + 1` query mitigation | The lazy-loading default makes `N + 1` the path of least resistance | **No lazy loading**, so the problem does not exist; data is fetched eagerly through Repository methods that say so explicitly |

What an ORM does that henua *does* keep, reshaped:

- **The Repository abstraction** — separating "how to manipulate
  the aggregate in memory" from "how to persist it" is genuinely
  load-bearing. henua provides the `Repository` shape as a
  convention (functions named `save` / `find` / `delete` taking
  the repo and returning `Result[RepositoryError, ...]`) and a
  reference `InMemoryRepository[a, i]` for tests and
  prototyping. Database-backed implementations live in their
  own modules (`postgres_repository.kai`, `sqlite_repository.kai`)
  once `kohau` exists.
- **The Aggregate as a unit of consistency** — a cluster of
  associated objects manipulated as one. henua expresses this as
  a value type + a pure step function (`apply(state, event) ->
  state`), folded by the consumer.

What henua deliberately drops compared to ORMs:

- The `Session` / `EntityManager` / `Connection` ambient context.
  Effects are explicit in every row; the database connection
  capability lives in `kohau`'s effect.
- Inheritance hierarchies as a modelling tool. DDD aggregates
  in henua are sum types or records; vertical inheritance is
  not a kaikai construct.
- Annotations / decorators (`@Entity`, `@Column`). Records and
  sum types describe themselves; the persistence layer maps them.
- Lazy-loading proxies, dirty-checking caches, identity maps.
  These compensate for languages where the alternative
  (immutable values + explicit reads) is awkward.
- Code generation. kaikai has no macros. henua has no code gen.

What henua adds that ORMs do not have:

- **Refinement types for value invariants.** Domain types
  (`PositiveInt`, `Email`, `Slug`) carry their predicate in the
  type system (`kaikai/docs/refinements-and-contracts.md`);
  henua's validation helpers convert raw input into refined
  values at the boundary.
- **Effects in the row for every persistence operation.** Once
  `kohau`-backed adapters ship, every `save` / `find` / `delete`
  signature carries the database effect explicitly — no ambient
  `Connection` capability hiding under the operation.
- **The Aggregate apply pattern as a recursive fold.** Same
  shape as `ahu.cell`'s step function. The Aggregate is the
  pure-data sibling of the cell: one mutates over time inside a
  fiber; the other accumulates events into a new value at each
  fold step.

## The substrate kaikai provides

henua builds on these kaikai features, all already in main as of
0.56.x:

- **Records** (`type T = { field: U, ... }`) for entity state.
- **Sum types** (`type T = A | B(c, d) | ...`) for events and
  errors.
- **Refinement types** (`type T = Base where predicate(self)`)
  for value invariants — `kaikai/docs/refinements-and-contracts.md`.
- **Single-dispatch protocols** (`protocol P { ... }`,
  `impl P for T { ... }`) — `kaikai/docs/protocols.md`. (henua
  henua does not declare any protocols; convention-based shapes
  fit the load-bearing operations better — see §*Decisions*.)
- **`Result[e, a]` and `Option[a]`** from `stdlib/core` for
  fallible operations.
- **`Map[k, v]`** AVL-backed associative map from
  `stdlib/collections/map.kai`, used to back
  `InMemoryRepository`.
- **Effect rows (`/ e`)** for capability-tracking — open row
  variables flow user effects through henua's helpers without
  forcing a uniform effect list.
- **`#derive` annotations** for structural impls of `Show`,
  `Eq`, `Ord`, `Hash` when user aggregates need them.

henua does not redesign any of these. Where it discovers gaps,
the gap is documented in §*External dependencies on kaikai*.

## The surface

henua exposes eight modules under `henua/`:

```
┌──────────────────────────────────────────────────────────────┐
│ henua.repository                                             │
│   Repository convention + InMemoryRepository[a, i] adapter   │
│   (value form) save / find / delete / size / all             │
├──────────────────────────────────────────────────────────────┤
│ henua.repository_effect                                     │
│   Repository[a, i] effect (the port) + in-memory adapter     │
│   (effect form) Repository.find / .save / .delete            │
│   with_in_memory / with_in_memory_seeded                     │
├──────────────────────────────────────────────────────────────┤
│ henua.sqlite_repository                                      │
│   SQLite adapter for the port, via kohau                     │
│   with_sqlite / with_sqlite_delim / size                     │
├──────────────────────────────────────────────────────────────┤
│ henua.event_bus                                              │
│   EventBus convention + InMemoryEventBus[ev, e] adapter      │
│   subscribe / unsubscribe / publish / subscriber_count       │
├──────────────────────────────────────────────────────────────┤
│ henua.aggregate                                              │
│   apply_event(state, event, step)                            │
│   fold_events(initial, events, step)                         │
├──────────────────────────────────────────────────────────────┤
│ henua.domain_event                                           │
│   EventMeta, EventEnvelope[ev], envelope, event_of, meta_of  │
├──────────────────────────────────────────────────────────────┤
│ henua.validation                                             │
│   non_empty_string / string_length_between                   │
│   positive_int / non_negative_int / int_between              │
│   and_then chaining                                          │
├──────────────────────────────────────────────────────────────┤
│ henua.bounded_context                                        │
│   Documentation-only module describing the directory-per-    │
│   context convention                                         │
└──────────────────────────────────────────────────────────────┘
```

A consumer that needs only the Repository pattern pays for
nothing else. A consumer with no events needs nothing from
`event_bus` or `domain_event`. A consumer that uses kaikai
records and refinement types directly pays for none of henua —
henua is convention plus minimal helpers for cases where the
patterns recur, not a mandatory shell around every domain model.

### henua.repository

Persistence is split into **convention** (function shape, error
type, return convention) and **implementation** (the concrete
record type that stores entities).

- **`RepositoryError`** is the error type returned by any
  Repository operation: `NotFound | Conflict(String) | Backend(String)`.
- **`InMemoryRepository[a, i]`** is the reference
  implementation. Pure: `save` and `delete` return a fresh repo
  with the change applied. Backed by `Map[i, a]` from stdlib.
- **`save / find / delete / size / all`** are the surface.
  `save` is insert-or-replace by id; `find` distinguishes
  "absent" (`Ok(None)`) from "infrastructure failed"
  (`Err(Backend(...))`); `delete` returns `Err(NotFound)` if the
  id was not present.

The `Ok(None)` vs `Err(NotFound)` distinction in `find` is
load-bearing: a domain operation that needs an entity may
prefer to convert absence to a domain error
(`AccountNotKnown`), and that decision belongs in the caller,
not in the Repository.

### henua.repository_effect

The same Repository pattern as a **port** — the parametric effect
`Repository[a, i]` — rather than a value. A domain function
declares `/ Repository[a, i]` in its row and calls
`Repository.find / .save / .delete`; it cannot name a concrete
repository type. The adapter is the enclosing handler, installed
at the composition root:

- **`Repository[a, i]`** is the effect (the port): `find(key) :
  Option[a]`, `save(key, entity) : Unit`, `delete(key) : Bool`.
- **`with_in_memory(body)`** installs an in-memory adapter — a
  handler-local `Map[i, a]` cell threaded through the same
  `map.*` logic the value form uses (reused, not reimplemented).
- **`with_in_memory_seeded(seed, body)`** is the same adapter
  started from a pre-populated `Map[i, a]` (for fixtures/tests).

This is the hexagonal form: the domain depends on the port, never
the adapter, and the effect-row checker enforces it. It is the
surface manutara targets so a route's row inherits persistence
access. The full rationale and its relationship to the value form
are Decision 9; the fixture is
`tests/repository_effect_roundtrip.kai`.

Persistent adapters handle the same effect:
`sqlite_repository.with_sqlite` today, a Postgres one on the
roadmap. The port — op names, their types, `RepositoryError` for
infrastructure failures — is the contract.

### henua.event_bus

In-process synchronous broadcaster. `publish(bus, event)`
invokes every subscriber's handler in registration order
before returning.

- **`Handler[ev, e]`** is `(ev) -> Unit / e`. Every subscriber
  declares its own effect row; the bus propagates the union
  back into `publish`'s row.
- **`InMemoryEventBus[ev, e]`** is the reference
  implementation. Pure functional carrier: `subscribe` and
  `unsubscribe` return a fresh bus.
- **`subscribe`** returns the new bus paired with the
  registration index, so callers can later `unsubscribe(bus,
  index)` if needed.

Asynchronous and cross-process variants — persistent queues
(via `hopu`), message brokers, fan-out routers — are on the
roadmap (§*Roadmap*, 0.8.0).

### henua.aggregate

The Aggregate pattern, expressed as a pure step function.

- **`apply_event(state, event, step)`** applies one event.
- **`fold_events(initial, events, step)`** applies many.

henua deliberately does **not** ship a `protocol Aggregate { ... }`.
Protocol-based dispatch would force every aggregate's id
type into the same projection (`Self.Id`) which kaikai cannot
express without associated types (a feature the language
deliberately avoids — `kaikai/docs/protocols.md` §*What
protocols cannot do*).

### henua.domain_event

Convention: each bounded context defines one sum type listing
every domain event the context can emit. The helper module
ships:

- **`EventMeta`** record (id + millisecond Unix timestamp).
- **`EventEnvelope[ev]`** for wrapping an event with its
  metadata when persistence or replay is needed.

The caller is responsible for supplying the id (typically a
local counter or UUIDv7) and the timestamp (from a `Clock`
effect the caller already carries). henua does not embed
`Clock` in the helper, because adding it would bleed the effect
into every consumer.

### henua.validation

Predicate-based, not class-based. No `Validator` type, no
`Either` monad ceremony. The module ships:

- **`ValidationError`** sum type (`Empty | OutOfRange(String) |
  FormatMismatch(String) | Custom(String)`).
- **Helpers** for non-empty strings, string length bounds,
  positive / non-negative integers, integer ranges.
- **`and_then`** for chaining checks.

Domain code is recommended to declare its types as kaikai
refinement types (`type Email = String where matches ~r/.../`)
so the predicate lives in the type system. The henua helpers
exist for the boundary — converting raw `String` / `Int` input
into validated values and surfacing failures as
`Result[ValidationError, T]`.

### henua.bounded_context

Documentation-only module. The convention: one bounded context
per directory in the consumer's source tree, with cross-context
communication going through either an explicit `pub fn` call
(synchronous) or an integration event on the bus (asynchronous).
kaikai's module + privacy + orphan-rule machinery is sufficient;
henua does not add a `bounded_context` decorator or runtime
registry.

## Decisions

The nine load-bearing decisions behind henua's surface.

### Decision 1 — Repository as convention, not as protocol

The Repository shape (`save / find / delete` over a concrete
repo type) is enforced by **convention**, not by a kaikai
protocol.

Rationale:

- kaikai protocols are **pure** (`kaikai/docs/protocols.md`
  §*With effects*). The whole point of a Repository abstraction
  is to hide whether the backing store is in-memory (pure) or a
  remote database (effectful) — and a protocol cannot capture
  the effectful case.
- Convention generalises to future adapters (`postgres_repository`,
  `sqlite_repository`) without re-declaring a protocol every
  time. The single source of truth is this design doc + the
  shape of `InMemoryRepository`.
- A `Repository[a, i]` protocol would have to be single-dispatch
  on `Self`, but the load-bearing dimension of variation is
  `(a, i)` — the aggregate and id type — not the repository
  implementation. The protocol would be exercised at the wrong
  axis.

This decision rejects the *protocol* form and keeps the *value*
form (a concrete repo threaded explicitly). It does **not** reject
the *effect* form — modelling the Repository as a parametric
effect `Repository[a, i]` whose handlers are the adapters. That
form was added later as a complementary surface; see Decision 9.
The effect is, in fact, the surface that captures the effectful
case Decision 1's first bullet says "a protocol cannot capture".

### Decision 2 — InMemory adapter is pure (returns a new repo)

`save` / `delete` return a fresh `InMemoryRepository` rather
than mutating. Pure functional shape matches kaikai's core, and
it lets consumers thread the repo explicitly without ambient
state.

Rationale:

- kaikai records are immutable; ambient mutation would require
  a `Ref` effect that henua does not want to impose.
- Threading state explicitly makes Repository operations
  composable in a single `match` chain — every step's success
  produces the next step's repo.
- Database-backed adapters (Postgres, SQLite) will look
  different: they carry an effect row, and the "fresh repo"
  shape is replaced by ambient state managed by the
  underlying connection. That is exactly the right place for
  effects to enter; the in-memory adapter does not need them.

### Decision 3 — Aggregate as a step function, not a protocol

`Aggregate` is the pattern (aggregate root + pure step
function), not a kaikai type or protocol.

Rationale:

- Same reason as Decision 1: a protocol cannot express the
  natural variance ("each aggregate has its own id type with no
  uniform projection") that DDD aggregates exhibit.
- The recursive step-function shape matches `ahu.cell`'s
  pattern exactly. Users familiar with one are at home with the
  other.
- Specialisations (Aggregate roots with optimistic-concurrency
  versions, snapshot-based replays) are user-extensions, not
  framework concerns. henua stays minimal.

### Decision 4 — Sum types for domain events

Every bounded context declares one sum type for its domain
events. No `protocol DomainEvent`, no marker trait, no
inheritance.

Rationale:

- Sum types are kaikai's primary algebraic primitive. Sum-typing
  the event set gives the consumer exhaustive pattern matching
  for free — every subscriber that does not handle a new variant
  surfaces as a compile-time match-exhaustiveness error.
- A `protocol DomainEvent` would force every event's payload to
  fit a uniform shape, which contradicts the DDD principle that
  events carry domain-specific data.
- Past-tense naming (`AccountOpened`, not `OpenAccount`)
  preserves the "fact, not intention" semantics central to DDD.
  Convention is the right enforcement mechanism, not a
  framework decoration.

### Decision 5 — Refinement types for value invariants

Domain value types use kaikai's refinement-types-lite
(`type T = Base where predicate(self)`) rather than wrapper
classes or branded primitives.

Rationale:

- Refinements live in the type system — the typer narrows
  values at `match x { x : T -> ... }` arms and rejects
  arbitrary assignments to refined types.
- The predicate is decidable (no SMT, no constraint solver), so
  compile times stay flat.
- Wrapper classes (`class PositiveInt(value: Int)`) compensate
  for languages without refinement types. kaikai has them; the
  wrapper buys nothing.
- The henua validation helpers exist to convert raw input into
  refined-or-not-refined values **at the boundary** — once
  inside the domain, the refinement carries the invariant
  without further checking.

### Decision 6 — No `Either` monad, use `Result[e, a]`

Validation, repository, and event-bus operations all return
kaikai's stdlib `Result[e, a]`. No custom `Either`, no
`Validated[e, a]` accumulator type.

Rationale:

- `Result[e, a]` is the canonical fallible-computation carrier
  in kaikai stdlib (`stdlib/core/result.kai`); using it keeps
  henua interoperable with every other library.
- An accumulating `Validated[e, a]` (where multiple errors are
  collected before short-circuiting) is sometimes useful for
  form validation. henua leaves that to the caller — collect a
  `[ValidationError]` manually if needed. The accumulating
  helper is a non-essential add-on, not a load-bearing
  abstraction.
- One canonical carrier means the consumer learns one shape
  and the helpers compose.

### Decision 7 — No event sourcing in the core surface

The Aggregate apply-pattern is event-sourcing-compatible (a
state is a fold of events). But the core module surface does
not include the full event-sourcing apparatus: persistent
event streams, stream-versioning, snapshotting, replays.

Rationale:

- Event sourcing is a heavyweight architecture choice with
  consequences far beyond the type system. Forcing it as the
  default shape would be wrong; most consumers want the
  state-as-record + Repository.save pattern.
- The fold helper is in place (`aggregate.fold_events`), so the
  event-sourcing milestone can build on it without rework.
- See §*Roadmap* below.

### Decision 8 — Bounded context as convention, not as enforcement

Bounded contexts are recommended to live in their own
directory under the consumer's source tree. kaikai's modules +
visibility + orphan rule are sufficient enforcement; henua
does not ship a runtime registry, decorator, or macro for
context boundaries.

Rationale:

- kaikai's module system already provides the natural unit of
  context isolation. Adding a runtime concept would compete
  with the language.
- The integration event pattern (a third module that depends
  on both contexts but is depended on by neither) is a
  documentation convention, not a framework feature. henua ships
  the doc; the roadmap adds a typed router if usage data shows
  the absence is load-bearing.

### Decision 9 — Repository also as a port (effect), complementing the value form

`henua.repository_effect` exposes the Repository as a parametric
**effect** `Repository[a, i]`, alongside the value-form
`InMemoryRepository[a, i]` of `henua.repository`. The two are
layers, not competitors.

Background. Decision 1 chose convention-over-protocol and the
value form: a concrete repo threaded explicitly through `save /
find / delete`. That form is pure, immutable, and matches kaikai's
core — the right substrate for unit tests, fixtures, and
prototyping. But it has a property the broader ecosystem's "ports
and adapters" story (see `kaikai-docs/whitepaper-hexagonal.md`)
calls out as the *weaker* form: the domain's signature **names the
concrete repository type**, so the domain depends on the adapter,
not only on the port. That is closer to a service locator passed by
hand than to a late-bound port. henua 0.1.0 shipped only this form
— leaving the hexagonal property the ecosystem advertises (the
domain names *no* adapter, the compiler enforces the dependency
rule) on the table.

The effect form closes that gap. A domain function declares
`/ Repository[a, i]` in its row and calls `Repository.find /
Repository.save / Repository.delete`. It is **structurally
incapable** of naming a concrete repository — the language gives
it no handle to one. Which adapter is plugged in is decided by the
enclosing handler at the composition root
(`repository_effect.with_in_memory`, kohau-backed
`sqlite_repository.with_sqlite`, and `with_postgres` later). The effect-row checker
enforces the dependency rule that mainstream languages leave to
discipline + a DI container.

Why an *effect* succeeds where Decision 1 said a protocol fails:
a protocol is single-dispatch on `Self` and pure; an effect IS an
effect row and is parametric over `(a, i)` — exactly the axis of
variation Decision 1 identified. `effect Repository[a, i]` with ops
returning the generic `Option[a]` / `Bool` is verified to compile
and run against kai 0.98.0 (fixture
`tests/repository_effect_roundtrip.kai`).

The in-memory adapter is **built on the value form's logic, not a
reimplementation**: `with_in_memory`'s handler threads a
handler-local `Map[i, a]` cell through the same `map.put` /
`map.get` / `map.remove` operations the value form uses. The only
difference is who threads the state — the value form hands a fresh
repo to the caller; the handler threads it internally.

Guidance.

- **Value form** (`henua.repository`): a pure unit that threads
  state explicitly; the cheapest way to test pure logic with no
  handler ceremony; the substrate the in-memory adapter reuses.
- **Effect form** (`henua.repository_effect`): a domain operation
  whose repository dependency should be a compiler-checked port,
  swappable at the boundary without touching the domain; the
  surface downstream frameworks (manutara) target so a route's
  effect row inherits `Repository[a, i]` and the capability audit
  sees persistence access for free.

This is the same two-shape discipline ahu and kohau already pin
("pure form for tests / wrapped form for production"); henua now
matches it for the Repository. The fallible-adapter error story
(infrastructure failures from a real database) rides the adapter's
own result rather than `find`'s: `with_sqlite` returns
`Result[r, RepositoryError]`, and a statement that fails aborts the
body (the handler does not resume) with `Err(Backend(...))`.

The SQLite adapter takes kohau's client pid as a parameter and
keeps it inside the handler. kaikai rejects a function that returns
a `Pid` held in a record field (the pid lives only inside the
`with_client` scope that spawned the cell), so an earlier
`SqliteRepository` value carrying the pid could no longer be built;
the handler is the shape the type system leaves, and it is the port
the design already called for.

## Roadmap

One milestone per release. Shipped milestones are ticked; the
versions of the open ones are the planned order, not a promise.

- [x] **0.1.0** — Core vocabulary: Repository value form, Aggregate, Domain Event, in-memory EventBus, Validation, Bounded Context
- [x] **0.2.0** — Repository as a port: the `Repository[a, i]` effect with the in-memory adapter
- [x] **0.3.0** — Sources on `Result[Ok, Error]` (kaikai 0.104)
- [x] **0.4.0** — kohau's sqlite shim through `[native]`; tier1 CI
- [x] **0.5.0** — SQLite adapter as a handler of the Repository port (kaikai 0.174)
- [ ] **0.6.0** — Complete the port: `all` and `size` ops, transactions in the SQLite adapter
- [ ] **0.7.0** — Postgres adapter over `kohau.postgres.client`
- [ ] **0.8.0** — EventBus on ahu: a cell-wrapped, fault-isolated bus
- [ ] **0.9.0** — Serialised aggregate: one aggregate updated from many fibers
- [ ] **0.10.0** — Event sourcing: persistent streams, stream versions, snapshot + replay
- [ ] **0.11.0** — Integration events and a typed router between bounded contexts
- [ ] **0.12.0** — CQRS read models over the event bus
- [ ] **0.13.0** — Sagas / process managers on ahu's restart helpers
- [ ] **Unscheduled** — `Validated[e, a]`, only if a real use case asks for it

### Milestone notes

- **Port completion (0.6.0).** The value form already has `size`
  and `all`; the effect does not. kohau's client now ships
  `query_rows`, cursors and `with_tx`, which the SQLite adapter
  needs for `all` and for atomic multi-statement work.
- **Postgres (0.7.0).** Same shape as `with_sqlite`: the client
  pid enters as a parameter and stays inside the handler.
- **EventBus on ahu (0.8.0).** The README's principle — persistence
  and event handling expose a pure form and an ahu cell form — holds
  for the Repository through kohau's cell, but the bus has no cell
  form yet, and a panicking handler aborts the whole publish.
- **Event sourcing (0.10.0).** Persistent event streams,
  stream-version identifiers, snapshot+replay. The
  `aggregate.fold_events` helper is the building block; the
  milestone adds a stream type and a `replay(stream,
  initial_state, step)` helper that pulls events from storage.
- **Integration events + typed router (0.11.0).** A typed bridge
  between bounded contexts. Likely shape: `IntegrationEvent`
  envelope + a router that maps source-context events into
  integration events with explicit subscription rules. The
  bounded-context doc captures the convention today; the router
  ships if the convention is not enough.
- **CQRS read models (0.12.0).** Query-side projections that
  subscribe to the event bus and maintain read-optimised views. A
  `ReadModel[ev, s]` convention may ship — the milestone evaluates
  whether it warrants its own module or whether the existing
  Repository + EventBus combination is enough.
- **Sagas / Process Managers (0.13.0).** Long-running stateful
  coordinators across bounded contexts. Likely shape: a `Saga`
  is an Aggregate (state + step function) whose events arrive
  from multiple buses and whose actions emit commands to other
  contexts. Builds on `henua.aggregate`.
- **`Validated[e, a]`** for accumulating errors. Add if and
  only if a real use case (e.g. form validation in `manutara`)
  shows the short-circuiting `Result[e, a]` is awkward.

## Out of scope (permanent)

- **Code generation.** kaikai has no macros and no run-time
  reflection; henua will not invent them. Schema definitions,
  if needed, live in the persistence layer's own module.
- **Migration tooling.** Schema-migration is `kohau`'s concern.
- **Annotations / decorators on records.** kaikai records do
  not carry metadata. The Repository pattern works without them.
- **Active Record-style mixins.** Domain logic lives in
  ordinary functions over records, not in methods attached to
  the record type via a protocol. (kaikai protocols are
  available for `Show` / `Eq` / `Ord` / `Hash` only; behaviour
  with effects is expressed as ordinary functions.)
- **A `Supervisor`-style abstraction for sagas.** When sagas
  land, they will use `ahu`'s restart helpers and
  nurseries — not a henua-specific construct.

## Trade-offs vs other DDD frameworks

| Framework | What it ships | What henua does instead |
|---|---|---|
| **Java DDD (Axon, Spring Data, jMolecules)** | Annotated entities, repository interfaces with method-name conventions, event-sourcing engines | Records + sum types + Repository convention. No annotations. Event sourcing as an opt-in roadmap layer. |
| **Elixir Phoenix + Ash / Commanded** | Schema DSLs, change-set pipelines, opinionated context layout | Refinement types + validation helpers at the boundary. No DSL — kaikai records describe themselves. Context layout is a documented convention, not enforced. |
| **Go DDD-lite (Wild Workouts patterns)** | Hand-written repository interfaces, hand-rolled domain events, hand-rolled validation | henua provides reusable conventions for the same patterns. No interface explosion — Repository is one shape per implementation, not a per-aggregate interface declaration. |
| **F# DDD (the *Designing with Types* lineage)** | Discriminated unions, refinement-by-construction via smart constructors | Same shape, but with kaikai's refinement-types-lite the smart constructor becomes a one-liner returning `Result[ValidationError, T]`. |
| **Rust DDD (cqrs-es, lemma)** | Trait-heavy abstractions, complex generic bounds | henua avoids the protocol layer at the Repository level (Decision 1) — kaikai protocols are pure-only, which would fight the abstraction. Convention is the right tool. |

The shared insight across these frameworks: DDD is mostly
about **vocabulary** and **boundaries**, not about a specific
serialization or persistence story. henua keeps the
vocabulary tight (eight modules, ~1000 LOC) and lets the
persistence story live in `kohau`.

## External dependencies on kaikai

Capabilities that henua relies on, with their current status.

### Closed

1. **Single-dispatch protocols (m12.8).** Used internally by
   `#derive` for any aggregate that wants `Show` / `Eq` /
   `Hash` / `Ord` on its state.
2. **Refinement types (m12.6).** Used by consumers to declare
   value invariants; henua's validation helpers compose with
   the predicate.
3. **`Map[k, v]` AVL carrier.** Backs `InMemoryRepository`.
4. **`Result[e, a]` / `Option[a]` in stdlib core.** Used in
   every return shape.
5. **Effect rows on function types.** Used by the EventBus
   handler row variable `e`.
6. **`pub` self-resolution from package root** (kaikai#567).
   In-package fixtures resolve `import henua.repository` without
   a self-dependency in `kai.toml`.

### Open watch items

1. **Refinement-type narrowing through `Result`.** Today
   converting a `String` to a refined `Email` is a match-arm
   narrowing — the `String` value is checked against the
   refinement predicate, and on success the narrowed value is
   handed back as a refined type. henua's validation
   helpers return the base type after a regex check rather
   than the refined type; full Result-of-refined-type support
   is upstream m12.6.x #1.
2. **Aggregate concurrency primitives.** When a single
   aggregate is updated from multiple fibers concurrently,
   the `apply` step needs serialisation. henua leaves this to
   the consumer (e.g. wrap the aggregate in an `ahu.cell`);
   a `henua.serialized_aggregate` helper is on the roadmap
   (0.9.0).

## References

- `kaikai/docs/design.md`, `kaikai/docs/protocols.md`,
  `kaikai/docs/refinements-and-contracts.md`,
  `kaikai/docs/effects.md`, `kaikai/CLAUDE.md` — the upstream
  substrate.
- `ahu/docs/design.md` — sibling layer; shape and tone of
  this document follow it.
- Eric Evans, *Domain-Driven Design: Tackling Complexity in
  the Heart of Software* (2003) — the canonical DDD source
  for Aggregate, Repository, Domain Event, Bounded Context
  vocabulary.
- Vaughn Vernon, *Implementing Domain-Driven Design* (2013) —
  practical patterns, especially event-storming and the
  bounded-context map.
- Scott Wlaschin, *Domain Modeling Made Functional* (2018) —
  the F# DDD lineage; primary influence on henua's
  refinement-types-first approach over wrapper-class smart
  constructors.
- Eventide Project, *Microservices.io* — event-sourcing and
  CQRS reference patterns for henua's roadmap.
