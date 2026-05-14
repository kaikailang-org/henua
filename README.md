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
