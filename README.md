# henua

DDD building blocks for [kaikai](https://github.com/kaikailang-org/kaikai).
Repository, EventBus, Aggregate, Domain Events. Layer 4 of the kaikai
ecosystem stack; consumes [kohau](https://github.com/kaikailang-org/kohau)
for persistence and is consumed by [manutara](https://github.com/kaikailang-org/manutara)
(web) and hopu (background jobs).

> **Status:** Repository (as a value and as the `Repository[a, i]`
> effect), EventBus, Aggregate, Domain Event, Validation, and
> Bounded Context conventions are in place with in-memory reference
> adapters, plus a SQLite adapter for the Repository port via
> `kohau`. Postgres and event-sourcing primitives are still ahead.
> Design and roadmap live in `docs/design.md`.

## Why

henua is the *land / territory / domain* layer (the name is Rapa Nui
for *land / territory*, matching the Tangata Manu vocabulary that
kaikai's ecosystem uses). It exists to keep DDD vocabulary —
Aggregate, Repository, Domain Event, Bounded Context — out of the
infrastructure layers below it (kaikai's effects + actors, ahu's
streams/cells, kohau's DB clients) and out of the consumer
frameworks above it (manutara, hopu).

henua is NOT an ORM. It does not generate code. It does not impose
migrations. It is a thin DDD vocabulary on top of kohau's adapters.

## Foundational principle: henua builds on ahu

**henua is built on top of [ahu](https://github.com/kaikailang-org/ahu),
not on raw kaikai primitives.** Repositories, EventBus subscribers,
and long-running domain services live as ahu cells (Layer 2) wrapped
in restart helpers (Layer 3) when they need fault tolerance. The
pure stateless functions (`save / find / delete` over an immutable
repository value) are the *low-level* surface; the *ergonomic*
surface that downstream code uses is the cell-wrapped form, which
gives request/reply messaging, supervised lifecycle, and pipe
composition.

Concretely: any module that introduces persistence or event handling
exposes both shapes — a pure function operating on a value, and a
cell-based wrapper that runs the same operation inside an ahu cell.
The pure form is for tests, fixtures, and prototyping; the cell form
is for production.

For the Repository, the cell sits behind the port. Domain code names
only the `Repository[a, i]` effect; the SQLite adapter
(`sqlite_repository.with_sqlite`) handles it by talking to kohau's
cell-wrapped client. A cell's pid lives only inside the scope that
spawned it, so adapters take it as a parameter and keep it inside
their handler rather than storing it in a value.

This is not optional. Implementations that bypass ahu — direct
mutation, raw `spawn`, ad-hoc supervision — are out of scope for
henua. If a use case can't be expressed via ahu primitives, the gap
gets filed against ahu, not worked around inside henua.

Implementer agents working on henua MUST read ahu's `docs/design.md`
before writing module surfaces, and prefer ahu primitives over raw
kaikai primitives wherever both are available.

## Layout

```
henua/
├── README.md
├── kai.toml
├── Makefile                    # tier0/tier1 fixture drivers
├── docs/
│   ├── design.md               # spec, decisions, roadmap
│   └── examples.md             # walk-through of the example programs
├── henua/                      # the importable kaikai modules
│   ├── repository.kai          # Repository convention + InMemoryRepository[a, i]
│   ├── repository_effect.kai   # Repository[a, i] effect (the port) + in-memory adapter
│   ├── sqlite_repository.kai   # SQLite adapter for the port, via kohau
│   ├── aggregate.kai           # Aggregate apply / fold helpers
│   ├── domain_event.kai        # EventMeta + EventEnvelope[ev] conventions
│   ├── event_bus.kai           # EventBus convention + InMemoryEventBus[ev, e]
│   ├── validation.kai          # refinement-type validation helpers
│   └── bounded_context.kai     # doc-only module
├── examples/
│   ├── ledger/                 # Repository + EventBus + Aggregate end-to-end
│   ├── catalog/                # Repository + refinement-type validation
│   └── repository_port/        # domain code against the Repository effect
└── tests/                      # tier1 fixtures, each with .out.expected
```

## Building

The kaikai toolchain (`kai`) on `PATH`, version 0.174.0 or newer, is
the only prerequisite. The SQLite fixtures also need libsqlite3.

```sh
make tier1                      # compile every fixture, diff stdout vs golden
make clean                      # remove the build/ tree
```

Or directly:

```sh
kai build examples/ledger/main.kai  -o build/ledger
kai build examples/catalog/main.kai -o build/catalog
```

## License

[MIT](LICENSE).
