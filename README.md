# henua

DDD building blocks for [kaikai](https://github.com/kaikailang-org/kaikai).
Repository, EventBus, Aggregate, Domain Events. Layer 4 of the kaikai
ecosystem stack; consumes [kohau](https://github.com/kaikailang-org/kohau)
for persistence and is consumed by [manutara](https://github.com/kaikailang-org/manutara)
(web) and hopu (background jobs).

> **Status:** scaffolding. Not production-ready, no v0.1 yet. Design
> tracking against `docs/design.md`.

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

This is not optional. Implementations that bypass ahu — direct
mutation, raw `spawn`, ad-hoc supervision — are out of scope for
henua. If a use case can't be expressed via ahu primitives, the gap
gets filed against ahu, not worked around inside henua.

Implementer agents working on henua MUST read ahu's `docs/design.md`
before writing module surfaces, and prefer ahu primitives over raw
kaikai primitives wherever both are available.

## Layout (target)

```
henua/
├── README.md
├── kai.toml
├── docs/
│   ├── design.md
│   └── examples.md
├── henua/                      # the importable kaikai modules
│   ├── repository.kai          # Repository[A, I] protocol + InMemory adapter
│   ├── aggregate.kai           # Aggregate root patterns
│   ├── domain_event.kai        # Domain event sum-type conventions
│   ├── event_bus.kai           # EventBus[E] protocol + InMemory adapter
│   ├── bounded_context.kai     # conventions doc, no code yet
│   └── validation.kai          # refinement-type validation helpers
├── examples/
│   ├── ledger/                 # canonical ledger DDD example
│   └── catalog/                # bounded-context demo
└── tests/
    └── ...                     # tier1 fixtures
```

## License

TBD. Will match the kaikai ecosystem license (likely Apache-2.0 or MIT).
