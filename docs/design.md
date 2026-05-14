# henua design

Living document for the DDD building-block package that runs on
top of kaikai and underneath manutara and hopu.

> **Status:** v0.1 scaffolding. Repository, Aggregate, Domain
> Event, EventBus, Validation, and Bounded Context conventions
> are in place. The shipped reference implementations are pure
> and in-memory; database-backed adapters live in follow-up
> work once `kohau` is available.

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
  v1 does not declare any protocols; convention-based shapes
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

henua exposes six modules under `henua/`:

```
┌──────────────────────────────────────────────────────────────┐
│ henua.repository                                             │
│   Repository convention + InMemoryRepository[a, i] adapter   │
│   save / find / delete / size / all                          │
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
- **`save / find / delete / size / all`** are the v1 surface.
  `save` is insert-or-replace by id; `find` distinguishes
  "absent" (`Ok(None)`) from "infrastructure failed"
  (`Err(Backend(...))`); `delete` returns `Err(NotFound)` if the
  id was not present.

The `Ok(None)` vs `Err(NotFound)` distinction in `find` is
load-bearing: a domain operation that needs an entity may
prefer to convert absence to a domain error
(`AccountNotKnown`), and that decision belongs in the caller,
not in the Repository.

Future adapters (`postgres_repository.kai`,
`sqlite_repository.kai`) will provide the same shape with
their effect row attached. The convention — function names,
return shape, error type — is the contract.

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
(via `hopu`), message brokers, fan-out routers — are explicit
v0.2 scope.

### henua.aggregate

The Aggregate pattern, expressed as a pure step function.

- **`apply_event(state, event, step)`** applies one event.
- **`fold_events(initial, events, step)`** applies many.

henua deliberately does **not** ship a `protocol Aggregate { ... }`
in v1. Protocol-based dispatch would force every aggregate's id
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

The eight load-bearing decisions for henua v0.1.

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
  framework concerns. v1 stays minimal.

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
  form validation. v1 leaves that to the caller — collect a
  `[ValidationError]` manually if needed. The accumulating
  helper is a non-essential add-on, not a load-bearing
  abstraction.
- One canonical carrier means the consumer learns one shape
  and the helpers compose.

### Decision 7 — No event sourcing in v0.1

The Aggregate apply-pattern is event-sourcing-compatible (a
state is a fold of events). But the v0.1 module surface does
not include the full event-sourcing apparatus: persistent
event streams, stream-versioning, snapshotting, replays.

Rationale:

- Event sourcing is a heavyweight architecture choice with
  consequences far beyond the type system. Forcing it as the
  default shape would be wrong; most consumers want the
  state-as-record + Repository.save pattern.
- The fold helper is in place (`aggregate.fold_events`), so a
  v0.2 event-sourcing module can build on it without rework.
- See §*Roadmap v0.2* below.

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
  documentation convention, not a framework feature. v1 ships
  the doc; v0.2 may ship a typed router if usage data shows
  the absence is load-bearing.

## Roadmap v0.2

Capabilities scoped out of v0.1, explicitly. The shape they
will take is sketched here so future contributors can match
real use cases to the right slot.

- **Persistent Repositories via kohau.** `henua.postgres_repository`,
  `henua.sqlite_repository` once `kohau` ships. Same
  `save / find / delete` convention with `/ kohau.Db` in every
  effect row.
- **Event sourcing.** Persistent event streams, stream-version
  identifiers, snapshot+replay. The `aggregate.fold_events`
  helper is the v0.1 building block; the v0.2 lane adds a
  stream type and a `replay(stream, initial_state, step)`
  helper that pulls events from storage.
- **CQRS read models.** Query-side projections that subscribe
  to the event bus and maintain read-optimised views. A
  `ReadModel[ev, s]` convention may ship — the design lane
  evaluates whether it warrants its own module or whether the
  existing Repository + EventBus combination is enough.
- **Sagas / Process Managers.** Long-running stateful
  coordinators across bounded contexts. Likely shape: a `Saga`
  is an Aggregate (state + step function) whose events arrive
  from multiple buses and whose actions emit commands to other
  contexts. Builds on `henua.aggregate` once the use case is
  concrete.
- **Integration events + typed router.** A typed bridge
  between bounded contexts. Likely shape: `IntegrationEvent`
  envelope + a router that maps source-context events into
  integration events with explicit subscription rules. v1's
  bounded-context doc captures the convention; v0.2 may add
  the helper if the convention is not enough.
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
  land in v0.2, they will use `ahu`'s restart helpers and
  nurseries — not a henua-specific construct.

## Trade-offs vs other DDD frameworks

| Framework | What it ships | What henua does instead |
|---|---|---|
| **Java DDD (Axon, Spring Data, jMolecules)** | Annotated entities, repository interfaces with method-name conventions, event-sourcing engines | Records + sum types + Repository convention. No annotations. Event sourcing as opt-in v0.2 layer. |
| **Elixir Phoenix + Ash / Commanded** | Schema DSLs, change-set pipelines, opinionated context layout | Refinement types + validation helpers at the boundary. No DSL — kaikai records describe themselves. Context layout is a documented convention, not enforced. |
| **Go DDD-lite (Wild Workouts patterns)** | Hand-written repository interfaces, hand-rolled domain events, hand-rolled validation | henua provides reusable conventions for the same patterns. No interface explosion — Repository is one shape per implementation, not a per-aggregate interface declaration. |
| **F# DDD (the *Designing with Types* lineage)** | Discriminated unions, refinement-by-construction via smart constructors | Same shape, but with kaikai's refinement-types-lite the smart constructor becomes a one-liner returning `Result[ValidationError, T]`. |
| **Rust DDD (cqrs-es, lemma)** | Trait-heavy abstractions, complex generic bounds | henua avoids the protocol layer at the Repository level (Decision 1) — kaikai protocols are pure-only, which would fight the abstraction. Convention is the right tool. |

The shared insight across these frameworks: DDD is mostly
about **vocabulary** and **boundaries**, not about a specific
serialization or persistence story. henua keeps the
vocabulary tight (six modules, ~600 LOC) and lets the
persistence story live in `kohau`.

## External dependencies on kaikai

Capabilities that henua relies on, with their current status.

### Closed (as of kaikai 0.56.1)

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

### Open watch items

1. **`pub` self-resolution from package root** (kaikai#567).
   `kai.toml` currently uses the `henua = { path = "." }`
   workaround so in-package fixtures resolve `import
   henua.repository`. Closes when kaikai adds the manifest
   directory to the implicit search path.
2. **Refinement-type narrowing through `Result`.** Today
   converting a `String` to a refined `Email` is a match-arm
   narrowing — the `String` value is checked against the
   refinement predicate, and on success the narrowed value is
   handed back as a refined type. v1 of henua's validation
   helpers return the base type after a regex check rather
   than the refined type; full Result-of-refined-type support
   is upstream m12.6.x #1.
3. **Aggregate concurrency primitives.** When a single
   aggregate is updated from multiple fibers concurrently,
   the `apply` step needs serialisation. v1 leaves this to
   the consumer (e.g. wrap the aggregate in an `ahu.cell`);
   a `henua.serialized_aggregate` helper may ship in v0.2 once
   the pattern recurs.

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
  CQRS reference patterns scoped for henua v0.2.
