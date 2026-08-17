# 04: A deliberate violation, caught

This example has a domain with an internal resource. A sibling domain reaches
straight into that resource in two ways: a plain function call, and a genuine
Ash relationship. The compiler catches both.

`test/deliberate_violation/violation_test.exs` shells out to a real, isolated
`mix compile --warnings-as-errors` run. The test asserts on the real exit code
and the real output, every time `mix test` runs. See "How the violation is
isolated and proven" below.

## The domains

| Module | Exported? | Role |
| --- | --- | --- |
| `DeliberateViolation.Accounting` | yes (a boundary's root always is) | domain that owns ledger data |
| `DeliberateViolation.Accounting.LedgerEntry` | **no** | the real, ETS-backed resource. Has its own `code_interface` (`create`, `read`) for use inside the domain |
| `DeliberateViolation.Accounting.Summary` | yes | the domain's entire public API: two generic actions, `:record` and `:total` |
| `DeliberateViolation.Billing` | yes | domain that owns invoices, shipped clean. `boundary do deps [...Accounting] end` |
| `DeliberateViolation.Billing.Invoice` | yes | has `attribute :ledger_entry_id, :uuid`, no relationship, and a `:ledger_total` calculation that calls `Accounting`'s exported `Summary` facade (via `total_ledger_balance!/0`) |
| `DeliberateViolation.Violation.Billing` | yes | not compiled by any normal build. Same domain as `Billing`, same honest `deps` line, reaching past it anyway |
| `DeliberateViolation.Violation.Billing.Invoice` | yes | the alias-style violation: `belongs_to :ledger_entry, ...Accounting.LedgerEntry` |
| `DeliberateViolation.Violation.Billing.LedgerEntryCaller` | n/a | the call-style violation: `LedgerEntry.create!/1`, called directly |
| `DeliberateViolation` | n/a | the app's root boundary, plain `use Boundary`, mandatory in every example (see sample 1) |

This mirrors example 3's shape: `Accounting`/`LedgerEntry`/`Summary` here play
the role `Customers`/`Customer`/`Directory` play there. A facade resource keeps
the exported surface equal to the interface, so `LedgerEntry` stays internal no
matter what any other domain declares. See the "Design note: the facade
resource" section in example 3 for the full rationale.

## Two ways in, both caught

`DeliberateViolation.Billing` is shipped clean. It never mentions `LedgerEntry`
anywhere. `DeliberateViolation.Violation.Billing` is the same domain with two
lines changed, one per way of reaching into another boundary's internal
module.

**The alias-style violation**, in `violation/billing/invoice.ex`:

```elixir
relationships do
  belongs_to :ledger_entry, DeliberateViolation.Accounting.LedgerEntry do
    allow_nil? false
    attribute_writable? true
    public? true
  end
end
```

A relationship names a module and calls nothing on it. `boundary` does not
check this kind of reference by default (`check: [aliases: false]` is its
documented default, per example 3's "Alias checking is on by default"
section). AshBoundary enables alias checking for every domain it manages, with
zero project-level `mix.exs` configuration. That is the only reason this
`belongs_to` is caught at all. This example's `mix.exs` sets no
`boundary: [default: [check: ...]]` of any kind. That is deliberate: the whole
point is that this works out of the box.

**The call-style violation**, in `violation/billing/ledger_entry_caller.ex`:

```elixir
alias DeliberateViolation.Accounting.LedgerEntry

def run do
  LedgerEntry.create!(%{description: "Reached in directly", amount: 0})
end
```

`create!/1` is real. `LedgerEntry`'s own `code_interface` generates it,
exactly as in sample project 2. It would return a real, valid record if this
call were allowed to run. `boundary` never asks what the function does or how
it came to exist. It asks only whether the module,
`DeliberateViolation.Accounting.LedgerEntry`, is exported by its owner
boundary. It is not, so the call is forbidden.

**One command catches both**, run against the isolated `violation/` tree (see
below):

```
$ MIX_ENV=violation mix compile --warnings-as-errors
...
warning: forbidden reference to DeliberateViolation.Accounting.LedgerEntry
  (module DeliberateViolation.Accounting.LedgerEntry is not exported by its owner boundary DeliberateViolation.Accounting)
  violation/billing/invoice.ex:35

warning: forbidden reference to DeliberateViolation.Accounting.LedgerEntry
  (module DeliberateViolation.Accounting.LedgerEntry is not exported by its owner boundary DeliberateViolation.Accounting)
  violation/billing/ledger_entry_caller.ex:18
```

This exits `1`. `boundary` prints nothing further after the two warnings. It
prints no trailing "Compilation failed due to warnings..." summary line for
this kind of warning (some other warning types do log a separate summary).
`--warnings-as-errors` depends on the exit code, `1`, to fail the build.

Without `--warnings-as-errors`, the same command reports the same two warnings
verbatim and exits `0`:

```
$ MIX_ENV=violation mix compile
...
warning: forbidden reference to DeliberateViolation.Accounting.LedgerEntry
  (module DeliberateViolation.Accounting.LedgerEntry is not exported by its owner boundary DeliberateViolation.Accounting)
  violation/billing/invoice.ex:35

warning: forbidden reference to DeliberateViolation.Accounting.LedgerEntry
  (module DeliberateViolation.Accounting.LedgerEntry is not exported by its owner boundary DeliberateViolation.Accounting)
  violation/billing/ledger_entry_caller.ex:18
```

`boundary` reports a cross-boundary violation as a compiler warning by
default, never a hard failure. Every example in this series has to account
for this detail. Without `--warnings-as-errors`, the compiler tells you about
the violation, but it stops nothing. A CI pipeline that runs plain
`mix compile` and treats a clean exit code as good news lets both violations
through. `--warnings-as-errors` turns the warning into something a build can
fail on. That is why every example in this series, including this one's own
gate below, runs with that flag.

See "How the violation is isolated and proven" for how the output above was
captured, by the same subprocess this example's own test suite runs.

## The contrast case: reaching into what IS exported

`DeliberateViolation.Billing.Invoice`'s `:ledger_total` calculation
(`lib/deliberate_violation/billing/calculations/ledger_total.ex`) makes the
same shape of cross-domain call as the violation above, a module outside
`Accounting` calling into it. It calls the exported
`DeliberateViolation.Accounting.total_ledger_balance!/0`:

```elixir
alias DeliberateViolation.Accounting

@impl Ash.Resource.Calculation
def calculate(invoices, _opts, _context) do
  total = Accounting.total_ledger_balance!()
  {:ok, Enum.map(invoices, fn _invoice -> total end)}
end
```

Note the name: `total_ledger_balance!/0` is nullary and returns the *whole
ledger's* balance, the same value for every invoice. That is a deliberate,
disclosed simplification for this contrast case, not a per-invoice figure —
unlike example 3's `Customers.customer_display_names/1`, which batches by a
list of ids and returns a different answer per record. A name implying
"this invoice's total" would misdescribe what the function does.

`DeliberateViolation.Billing` declares `boundary do deps
[DeliberateViolation.Accounting] end`, the same `deps` line
`DeliberateViolation.Violation.Billing` declares. Only one thing differs:
which module on the other side of the line gets referenced, `Accounting`
(exported) or `Accounting.LedgerEntry` (not exported). `mix compile
--warnings-as-errors` against the shipped `lib/` tree exits `0`, with no
warnings. `mix test` (below) proves the calculation genuinely returns a value
computed from the other domain's ETS-backed data.

The compiler stays out of the way, silently, for every reference that
respects the boundary. It speaks up only for the two that don't.

## Running it

```
mix deps.get
mix format --check-formatted
mix compile --warnings-as-errors
mix test
```

Run `mix deps.get` before `mix format --check-formatted`. `.formatter.exs`'s
`import_deps` needs the deps present on disk to resolve, and fails with
`Unknown dependency :ash given to :import_deps` on a clean checkout otherwise.
All four commands succeed. Nothing in `lib/` or in this default `mix test`
run is expected to fail. `mix test` runs four tests, in two files:

- `DeliberateViolation.BillingTest` proves the clean, shipped state works end
  to end: a ledger entry is recorded through `Accounting`'s exported `Summary`
  facade, an invoice is issued through `Billing`'s exported interface, and
  loading `:ledger_total` returns a real value computed from the other
  domain's ETS table.
- `DeliberateViolation.ViolationTest` is the automated proof described above.
  It runs as part of this same, green `mix test` run, because what it proves
  (that the isolated `MIX_ENV=violation` build fails in the documented way)
  is itself a passing assertion. See the next section.

## How the violation is isolated and proven

`violation/` holds the deliberately-coupled `DeliberateViolation.Violation.Billing`
domain: real, complete code, not a fragment. `mix.exs` keeps it out of every
normal build, the same way example 3 keeps `antipattern/` out of its own:

```elixir
defp elixirc_paths(:violation), do: ["lib", "violation"]
defp elixirc_paths(_env), do: ["lib"]
```

This matches example 3's approach, for the same reason: `boundary` reports
violations as warnings, and this project's own `mix compile`/`mix test` gate
has to stay green, so code that is expected not to compile under
`--warnings-as-errors` cannot live in the paths those commands touch.

**This example departs from example 3 in what proves the isolated build
actually fails.** Example 3's `antipattern/` is verified by a documented,
reproducible README walkthrough: a human runs `MIX_ENV=antipattern mix
compile --warnings-as-errors` and reads the output. That is the right amount
of ceremony there, because example 3's point is the decoupling pattern; the
antipattern build failing is supporting evidence, not the point itself.

Here, the point of the entire example is that a violation gets caught, so it is
checked automatically rather than left to a manual reproduction step.
`test/deliberate_violation/violation_test.exs`
shells out to the isolated build itself, as a subprocess, from inside an
ordinary `ExUnit` test that `mix test` runs every time:

```elixir
{output, exit_code} =
  System.cmd("mix", ["compile", "--warnings-as-errors"],
    cd: File.cwd!(),
    env: [{"MIX_ENV", "violation"}],
    stderr_to_stdout: true
  )

assert exit_code == 1
assert output =~ """
       warning: forbidden reference to DeliberateViolation.Accounting.LedgerEntry
         (module DeliberateViolation.Accounting.LedgerEntry is not exported by its owner boundary DeliberateViolation.Accounting)
         violation/billing/invoice.ex:35\
       """
assert output =~ """
       warning: forbidden reference to DeliberateViolation.Accounting.LedgerEntry
         (module DeliberateViolation.Accounting.LedgerEntry is not exported by its owner boundary DeliberateViolation.Accounting)
         violation/billing/ledger_entry_caller.ex:18\
       """
```

A second test in the same file makes the same call without
`--warnings-as-errors` and asserts the inverse: exit `0`, same warnings
present. Together the two tests turn the `exit 0` vs. `exit 1` distinction
explained above into executable assertions, in place of README prose.

**Why a subprocess**: `boundary`'s
forbidden-reference check is wired in as a Mix compiler (`compilers:
[:boundary] ++ Mix.compilers()`). It runs as a distinct step in a `mix compile`
invocation. `Code.compile_file/1` never triggers it. Only a real, separate
`mix compile` run exercises the check. The test runs that command against a
genuinely separate `MIX_ENV` and `_build/violation/`, so it cannot disturb
this example's own shipped build artifacts.

One practical consequence: the first time `mix test` runs against a fresh
checkout, that subprocess has to compile this project's dependencies for the
`:violation` env from scratch (mirroring example 3's note about its own
`antipattern` env). This can take roughly a minute. Every run after that
reuses `_build/violation/` and is fast. The test carries a five-minute
timeout to accommodate the cold-start case.

## Gate

Same as every example in this series, run from within this directory:

```
mix deps.get && mix format --check-formatted && mix compile --warnings-as-errors && mix test
```

**What "green" means for an example whose whole point is a violation:** this
gate must be green, unconditionally. `mix compile --warnings-as-errors` here
compiles only `lib/` (via `elixirc_paths`) and must exit `0` with no
warnings. `mix test` must pass, including `DeliberateViolation.ViolationTest`.
That test passing is the demonstration: it means the separate, isolated
`MIX_ENV=violation mix compile --warnings-as-errors` genuinely exited `1`
with the two expected warnings when the test invoked it. A green result on
that isolated, `violation`-env build, the one thing this gate never runs
directly, would mean the violation was not caught. That is the failure mode
this whole example exists to prevent.

`violation/` is format-checked (it is listed in `.formatter.exs` inputs) but,
like `antipattern/` in example 3, is never compiled by the default `:dev` or
`:test` env. That is the reason the violation can ship as real, complete
code, and not as a prose description of one.
