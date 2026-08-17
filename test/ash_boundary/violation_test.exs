defmodule AshBoundary.ViolationTest do
  # Installs a compiler tracer process-globally, so it must not race other tests.
  use ExUnit.Case, async: false

  alias AshBoundary.Test.BoundaryCheck

  @world [
    AshBoundary.Test.Blog,
    AshBoundary.Test.Blog.Post,
    AshBoundary.Test.Blog.Comment,
    AshBoundary.Test.Blog.Draft,
    AshBoundary.Test.Blog.Tag,
    AshBoundary.Test.Reports,
    AshBoundary.Test.Reports.AllowedCaller,
    AshBoundary.Test.Reports.ForbiddenCaller,
    AshBoundary.Test.Reports.ForbiddenCallerDraft,
    AshBoundary.Test.Isolated,
    AshBoundary.Test.Isolated.Caller,
    AshBoundary.Test.Analytics,
    AshBoundary.Test.Analytics.Metric,
    AshBoundary.Test.Dashboard,
    AshBoundary.Test.Dashboard.AllowedCaller
  ]

  test "reaching an exported resource from a declared dep is allowed" do
    references =
      BoundaryCheck.capture_references(AshBoundary.Test.Reports.AllowedCaller, """
      defmodule AshBoundary.Test.Reports.AllowedCaller do
        def run, do: AshBoundary.Test.Blog.Post.__info__(:module)
      end
      """)

    assert references != []
    assert BoundaryCheck.reference_errors(@world, references) == []
  end

  test "reaching a resource that has no domain-level define is caught" do
    references =
      BoundaryCheck.capture_references(AshBoundary.Test.Reports.ForbiddenCaller, """
      defmodule AshBoundary.Test.Reports.ForbiddenCaller do
        def run, do: AshBoundary.Test.Blog.Comment.__info__(:module)
      end
      """)

    assert BoundaryCheck.reference_errors(@world, references) == [
             {:not_exported, AshBoundary.Test.Reports.ForbiddenCaller,
              AshBoundary.Test.Blog.Comment}
           ]
  end

  test "reaching a resource with no code interface anywhere is caught the same way" do
    # `Draft` has neither a domain-level `define` nor a resource-level
    # `code_interface` — an even more basic case than `Comment`, which at least has
    # a resource-level one. Both are equally non-exported, and both are caught the
    # same way.
    references =
      BoundaryCheck.capture_references(AshBoundary.Test.Reports.ForbiddenCallerDraft, """
      defmodule AshBoundary.Test.Reports.ForbiddenCallerDraft do
        def run, do: AshBoundary.Test.Blog.Draft.__info__(:module)
      end
      """)

    assert BoundaryCheck.reference_errors(@world, references) == [
             {:not_exported, AshBoundary.Test.Reports.ForbiddenCallerDraft,
              AshBoundary.Test.Blog.Draft}
           ]
  end

  test "depending on two domains at once allows reaching each one's exports independently" do
    # `Dashboard` declares `deps [Blog, Analytics]` — two independent domains, each
    # contributing its own exported resource. This proves export/deps composition
    # holds beyond a single dependency, not just that two separate single-dep tests
    # each pass on their own.
    references =
      BoundaryCheck.capture_references(AshBoundary.Test.Dashboard.AllowedCaller, """
      defmodule AshBoundary.Test.Dashboard.AllowedCaller do
        def run do
          {AshBoundary.Test.Blog.Post.__info__(:module),
           AshBoundary.Test.Analytics.Metric.__info__(:module)}
        end
      end
      """)

    assert references != []
    assert BoundaryCheck.reference_errors(@world, references) == []
  end

  test "reaching another boundary at all without declaring it as a dep is caught" do
    # `AshBoundary.Test.Isolated` has no `boundary` section, which is the default a domain
    # gets just by adding the extension: it may reach nothing.
    references =
      BoundaryCheck.capture_references(AshBoundary.Test.Isolated.Caller, """
      defmodule AshBoundary.Test.Isolated.Caller do
        def run, do: AshBoundary.Test.Blog.Post.__info__(:module)
      end
      """)

    assert BoundaryCheck.reference_errors(@world, references) == [
             {:normal, AshBoundary.Test.Isolated.Caller, AshBoundary.Test.Blog.Post}
           ]
  end

  test "declaring a boundary injects no code, so the domain gains no references" do
    # This is the payoff of installing the declaration with function calls instead of an
    # injected `use Boundary`: boundary's tracer sees nothing extra in the domain, so no
    # spurious cross-boundary references are recorded against it.
    references =
      BoundaryCheck.capture_references(AshBoundary.Test.Traced, """
      defmodule AshBoundary.Test.Traced do
        use Ash.Domain,
          extensions: [AshBoundary],
          validate_config_inclusion?: false

        boundary do
          deps [AshBoundary.Test.Blog]
        end

        resources do
        end
      end
      """)

    assert references != []

    assert Enum.filter(references, &String.starts_with?(inspect(&1.to), "Boundary")) == []
  end

  test "writing the deps list in the DSL is not itself a violation" do
    # Naming another domain in `deps` puts an alias to it in the domain's own source, which
    # boundary's tracer records as a reference. It has to be permitted by the very
    # declaration it is part of.
    references =
      BoundaryCheck.capture_references(AshBoundary.Test.TracedDeps, """
      defmodule AshBoundary.Test.TracedDeps do
        use Ash.Domain,
          extensions: [AshBoundary],
          validate_config_inclusion?: false

        boundary do
          deps [AshBoundary.Test.Blog]
        end

        resources do
        end
      end
      """)

    assert BoundaryCheck.reference_errors([AshBoundary.Test.TracedDeps | @world], references) ==
             []
  end

  test "the fixture world itself is otherwise clean" do
    assert BoundaryCheck.errors(@world -- callers(), []) == []
  end

  defp callers do
    [
      AshBoundary.Test.Reports.AllowedCaller,
      AshBoundary.Test.Reports.ForbiddenCaller,
      AshBoundary.Test.Reports.ForbiddenCallerDraft,
      AshBoundary.Test.Isolated.Caller,
      AshBoundary.Test.Dashboard.AllowedCaller
    ]
  end
end
