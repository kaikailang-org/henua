# henua

DDD building blocks for [kaikai](https://github.com/kaikailang-org/kaikai).
Repository, EventBus, Aggregate, Domain Events. Layer 4 of the kaikai
ecosystem stack; consumes [kohau](https://github.com/kaikailang-org/kohau)
for persistence and is consumed by [manutara](https://github.com/kaikailang-org/manutara)
(web) and hopu (background jobs).

> **Status:** v0.1 scaffolding shipped. Repository, EventBus,
> Aggregate, Domain Event, Validation, and Bounded Context
> conventions are in place with in-memory reference adapters.
> Database-backed adapters (Postgres, SQLite via `kohau`) and
> event-sourcing primitives are explicit v0.2 scope. Design and
> roadmap live in `docs/design.md`.

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
│   ├── aggregate.kai           # Aggregate apply / fold helpers
│   ├── domain_event.kai        # EventMeta + EventEnvelope[ev] conventions
│   ├── event_bus.kai           # EventBus convention + InMemoryEventBus[ev, e]
│   ├── validation.kai          # refinement-type validation helpers
│   └── bounded_context.kai     # doc-only module
├── examples/
│   ├── ledger/                 # Repository + EventBus + Aggregate end-to-end
│   └── catalog/                # Repository + refinement-type validation
└── tests/                      # tier1 fixtures, each with .out.expected
```

## Building

The kaikai toolchain (`kai`) on `PATH` is the only prerequisite.

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

TBD. Will match the kaikai ecosystem license (likely Apache-2.0 or MIT).
