# Architecture Language — TheLIST

Shared vocabulary for every suggestion the `improve-codebase-architecture` skill
makes. Use these terms exactly — don't substitute "component", "service", "API",
or "boundary". Consistent language is the whole point.

## Terms

**Module**
Anything with an interface and an implementation. Scale-agnostic — applies
equally to a Dart function, a class, a Riverpod provider, a repository, or a
full layer slice.
_Avoid_: unit, component, service.

**Interface**
Everything a caller must know to use the module correctly: the type signature,
invariants, ordering constraints, error modes, required configuration, and
performance characteristics.
_Avoid_: API, signature (too narrow — those refer only to the type-level surface).

**Implementation**
What is inside a module — its body of code. Distinct from **Adapter**.

**Depth**
Leverage at the interface — the amount of behaviour a caller (or test) can
exercise per unit of interface they must learn. A module is **deep** when a large
amount of behaviour sits behind a small interface. **Shallow** = interface nearly
as complex as the implementation.

**Seam**
A place where behaviour can be altered without editing in that place. Where a
module's interface lives. This project has three real seams (two adapters each):
- Time: production = wall clock / test = `FakeClock`
- Sync transport: production = Supabase / test = `FakeMemoryTransport`
- Database: production = Drift+SQLite / test = `InMemoryDrift`
_Avoid_: boundary (overloaded with DDD bounded context).

**Adapter**
A concrete thing that satisfies an interface at a seam.

**Leverage**
What callers get from depth: more capability per unit of interface they must learn.

**Locality**
What maintainers get from depth: change, bugs, knowledge concentrated in one
place rather than spread across callers.

## Principles

- **Depth is a property of the interface, not the implementation.** A deep module
  can be internally composed of small, swappable parts — they just aren't part of
  the interface.
- **The deletion test.** Imagine deleting the module. If complexity vanishes, it
  was a pass-through. If complexity reappears across N callers, it was earning its
  keep.
- **The interface is the test surface.** Callers and tests cross the same seam.
  If you want to test *past* the interface, the module is probably the wrong shape.
- **One adapter = hypothetical seam. Two adapters = a real seam.** Don't
  introduce a seam unless something actually varies across it.

## Project-specific seam inventory

| Seam | Production adapter | Test adapter | Enforced by |
|---|---|---|---|
| Time | wall clock (`DateTime.now()`) | `FakeClock` | `no-datetime-now` grep gate |
| Sync transport | Supabase (`lib/sync/` only) | `FakeMemoryTransport` | `layer-no-supabase-outside-sync` grep gate |
| Database | Drift + SQLite | `InMemoryDrift` | `layer-no-drift-in-ui` grep gate |
| UI tokens | — | — | `no-raw-hex`, `no-raw-spacing` grep gates |
| UI components | `List*` components | — | `no-material-visual` grep gate |

## Rejected framings

- **"Boundary"** — overloaded with DDD. Say **seam** or **interface**.
- **"Service"** — implies a networked or remote thing. This is a local-first app;
  use **module** or **repository** or **engine** as appropriate.
- **"Component"** — use **widget** for Flutter UI elements, **module** for
  everything else.
