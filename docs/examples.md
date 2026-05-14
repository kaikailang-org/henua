# henua examples

Two end-to-end programs that exercise the v0.1 surface. Each one
lives under `examples/<name>/main.kai` and is built with `kai
build examples/<name>/main.kai -o build/<name>` from the package
root.

## examples/ledger — Repository + EventBus + Aggregate

A minimal double-entry-shaped ledger. The example demonstrates:

- **Aggregate**: `Account` is a record (`{ id, balance_minor }`)
  paired with a pure step function `apply(acc, event) -> acc`.
- **Domain events**: `LedgerEvent` sum type with three variants:
  `AccountOpened`, `Credited`, `Debited`. Past-tense names; the
  variants encode facts, not commands.
- **Repository**: `InMemoryRepository[Account, AccountId]` holds
  accounts keyed by id. Every state change is `save`-d back.
- **EventBus**: `InMemoryEventBus[LedgerEvent, Stdout]` broadcasts
  every event to a single tracing subscriber.

Walk-through:

1. **Create** an empty repository and an empty bus. Subscribe a
   tracing handler.
2. **Open alice and bob** by emitting `AccountOpened` for each.
   Each commit folds the event into the aggregate, persists it,
   and publishes the event.
3. **Credit alice 100, debit bob 30.** Same commit path. The
   tracer prints each event as it fires.
4. **Read back final balances** from the repository.

The key insight: every state change goes through the same
four-step shape — `aggregate.apply_event → repository.save →
event_bus.publish`. There is no place ambient state can hide;
every transition is visible at the call site.

Expected output (from `examples/ledger/main.out.expected`):

```
event: opened alice
event: opened bob
event: credited alice +100
event: debited bob -30
--- final ---
account alice balance=100
account bob balance=-30
subscribers=1
```

## examples/catalog — Repository + refinement-type validation

A small product catalog. The example demonstrates:

- **Refinement types**: `ProductId` is declared as `String where
  matches ~r/^[a-z][a-z0-9-]{0,31}$/`. The predicate is enforced
  at narrowing sites via match-arm typing.
- **Validation at the boundary**: `mk_product(id, name,
  price_minor)` checks the three inputs against henua's
  validation helpers and returns `Result[ValidationError,
  Product]`. Only validated products reach the repository.
- **Composing validations**: the function chains four checks
  (non-empty id, slug-shaped id, non-empty name, positive
  price). The first failure short-circuits and surfaces as a
  `ValidationError` variant.
- **Repository persistence**: validated products are saved to
  `InMemoryRepository[Product, String]`. Invalid inputs leave
  the repository unchanged.

Walk-through:

1. Attempt to register five products. Each call to
   `try_register` validates the input, persists on success, and
   prints either `registered: <id>` or `rejected '<input>':
   <error>`.
2. Two of the five fail validation:
   - `"Cherry"` — capital `C` rejected by the slug refinement.
   - `"durian"` with empty name — caught by `non_empty_string`.
3. Print the final catalog by reading every entry from the repo
   via `repository.all`.

The key insight: the refinement type `ProductId = String where
matches ~r/^[a-z][a-z0-9-]{0,31}$/` is **not** something the
consumer has to check manually at every call site. It is part of
the type. The validation helpers exist at the boundary, where
raw input first enters the domain; once a value has been
validated it can travel through the rest of the codebase
without re-checking.

Expected output (from `examples/catalog/main.out.expected`):

```
registered: apple
registered: banana-pro
rejected 'Cherry': FormatMismatch(id must match ^[a-z][a-z0-9-]{0,31}$)
rejected 'durian': Empty
registered: elderberry
--- catalog ---
size=3
product apple: Apple @ 150
product banana-pro: Banana Pro @ 250
product elderberry: Elderberry @ 75
```

## Running the examples

Both examples build with the kaikai toolchain on `PATH`:

```sh
kai build examples/ledger/main.kai  -o build/ledger
kai build examples/catalog/main.kai -o build/catalog
build/ledger
build/catalog
```

The `Makefile` (when present) wraps these into `make tier1`,
diffing each binary's stdout against its `.out.expected` golden.

## What the examples deliberately do not show

- **Cross-context interactions.** Both examples are single
  bounded context. Integration events and cross-context buses
  are v0.2 work (`docs/design.md` §*Roadmap v0.2*).
- **Event sourcing.** The ledger example persists the
  *aggregate*, not the *event stream*. The aggregate is rebuilt
  on every save via `aggregate.apply_event`; the events are
  emitted on the bus and otherwise discarded. An
  event-sourcing example will land alongside the v0.2
  persistent-stream module.
- **Concurrent updates.** Both examples run sequentially. When
  multiple fibers update the same aggregate, the consumer
  needs to serialise — typically by wrapping the aggregate in
  an `ahu.cell`. See `docs/design.md` §*External dependencies on
  kaikai* watch items.
- **Database-backed repositories.** The in-memory adapter is
  the only one shipped in v0.1. `kohau`-backed Postgres /
  SQLite adapters live in `henua/postgres_repository.kai` and
  `henua/sqlite_repository.kai` once `kohau` is available.
