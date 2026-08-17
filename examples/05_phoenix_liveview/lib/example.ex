defmodule Example do
  @moduledoc """
  The blog domain, and the top-level boundary of the application's non-web half.

  This module plays two roles at once, and that is deliberate. It is an `Ash.Domain` with the
  `AshBoundary` extension, the same kind of domain as the ones in examples 1 to 4. It is also the
  boundary that claims the whole `Example.*` namespace, which is the role that `BasicBoundary` and
  `DeliberateViolation` play in the earlier examples.

  ## Why the domain is the top-level module

  This application has one domain, so it does not nest the domain under an extra level as
  `Example.Blog`. That nesting looks natural and creates a real problem.
  `Boundary.Checker.validate_dep_allowed/4` lets a boundary depend only on a sibling, a parent, or
  a dep of its parent. `mix phx.new` generates `Example` and `ExampleWeb` as top-level siblings. A
  domain at `Example.Blog` becomes a child of `Example`, and the top-level `ExampleWeb` can then
  no longer name it as a dep:

      warning: Example.Blog can't be listed as a dependency because it's not a sibling,
      a parent, or a dep of some ancestor

  AshBoundary's DSL exposes only `deps`. It has no `top_level?` option to promote a domain out of
  its parent. The fix therefore belongs in the module layout, not in the library. `Example` is the
  domain, `Example.Post` is the resource, and `Example` and `ExampleWeb` are the top-level
  siblings that `ExampleWeb`'s `deps: [Example]` entry needs. A single-domain Ash and Phoenix
  application does this routinely.

  `Example.Application` is the one module in this namespace that this boundary does not claim. It
  carries `top_level?: true`, for the reason its own moduledoc gives.

  ## Exports

  `Example.Post` carries domain-level `define`s, so `AshBoundary` puts it in `exports` beside this
  module. `ExampleWeb` declares `deps: [Example, ...]`. The web layer can then match
  `%Example.Post{}` and read its fields.

  ## The `AshPhoenix` extension

  `extensions: [AshBoundary, AshPhoenix]` generates a `form_to_<name>` function for each `define`
  below, such as `form_to_create_post/1`. Each one returns an `%AshPhoenix.Form{}` already bound
  to this domain's resource and action. `AshPhoenix.Transformers.AddFormCodeInterfaces` builds
  them, and the name is always `form_to_` plus the interface name.

  This matters for the boundary, not only for convenience. The web layer builds its form by
  calling `Example.form_to_create_post/1`, an ordinary exported interface function on this module.
  It never names `Example.Post` to construct a form. It can also build a form only for an action
  that this module declares. `Example.Post`'s `:moderate` action has no `define`, so no
  `form_to_moderate_post/1` function exists, and
  `violation_form/example_web/live/undefined_form_live.ex` proves that the web layer cannot reach that
  action through a form.

  ## Results are plain data, including errors

  The generated code interface functions below are real and exported. The two hand-written
  functions in this module, `fetch_post/1` and `published_post_titles/0`, exist for a specific
  reason. What a function returns is as much a part of a boundary's contract as which modules it
  exposes.

  `get_post_by_id/1` returns `{:error, %Ash.Error.Invalid{}}` when no such post exists. That
  struct lives in the `:ash` application. A LiveView that wrote this code:

      case Example.get_post_by_id(id) do
        {:ok, post} -> ...
        {:error, %Ash.Error.Invalid{}} -> ...
      end

  would make a forbidden reference to `Ash.Error.Invalid`. The compiler catches it, and
  `violation/example_web/live/ash_error_match_live.ex` proves it. You cannot allow that one struct
  on its own. `boundary`'s app check works at application level, so permitting
  `Ash.Error.Invalid` also permits `Ash.read!/1`, `Ash.Query`, and the rest of `:ash`. This is the
  same class of trade-off as the module-level granularity of `exports` that `AshBoundary`'s docs
  already accept. See the README.

  The domain translates instead. `fetch_post/1` returns `{:ok, %Example.Post{}}`,
  `{:error, :not_found}`, or `{:error, message}` with a binary message. Any caller can match on
  that data without a reference to `Ash.*`. No restriction applies to this module. It can call
  `Ash.Error.*` and `Exception.message/1` freely, and that code belongs here.

  The same rule applies to loading. No function here returns a struct that still needs
  `Ash.load/2` before a template can render it. The read actions on `Example.Post` carry
  `prepare build(load: [...])`, so calculated fields arrive populated.
  """

  use Ash.Domain, extensions: [AshBoundary, AshPhoenix]

  resources do
    resource Example.Post do
      # These domain-level defines make `AshBoundary` export `Example.Post`. The export is what
      # lets `ExampleWeb` name the module and match the struct.
      #
      # The `AshPhoenix` extension also generates a `form_to_<name>` function for each define
      # here. `create_post` below is therefore what makes `Example.form_to_create_post/1` exist.
      define :list_published_posts, action: :list_published
      define :get_post_by_id, action: :by_id, args: [:id]
      define :create_post, action: :create
      # `list_posts` returns every post, published or not. `delete_post` completes an ordinary
      # domain API. The web layer uses neither. The test suite uses them to clear the shared ETS
      # table between tests, through this exported interface rather than by reaching into the
      # resource.
      define :list_posts, action: :read
      define :delete_post, action: :destroy
      # `Example.Post` also has a `:moderate` update action. It has no `define` here, on purpose.
      # No `form_to_moderate_post/1` function therefore exists, and the web layer has no way to
      # build a form for that action. See the moduledoc.
    end
  end

  @doc """
  Looks up a post by id. Translates every Ash-level failure into plain data.

  Returns `{:ok, post}`, `{:error, :not_found}`, or `{:error, message}` with a binary message. It
  never returns `{:error, %Ash.Error.Invalid{}}`. The moduledoc explains why that difference is
  load-bearing and not a matter of style.
  """
  @spec fetch_post(term()) :: {:ok, Example.Post.t()} | {:error, :not_found | String.t()}
  def fetch_post(id) do
    case get_post_by_id(id) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, post} -> {:ok, post}
      {:error, error} -> {:error, translate_error(error)}
    end
  end

  @doc """
  Returns the titles of the published posts, as a plain list of binaries.

  This is a deliberately data-shaped alternative to returning structs. Sometimes the right answer
  to "what does the web layer need?" is a list of strings, not a resource.
  """
  @spec published_post_titles() :: [String.t()]
  def published_post_titles do
    Enum.map(list_published_posts!(), & &1.title)
  end

  # Turns any Ash error into plain data. `Ash.Error.to_error_class/1` normalises the single-error
  # and error-class shapes into one shape. The rest is ordinary pattern matching. It happens here,
  # inside the domain's own boundary, so that no caller has to do it.
  defp translate_error(error) do
    errors =
      error
      |> Ash.Error.to_error_class()
      |> Map.get(:errors, [])

    if Enum.any?(errors, &match?(%Ash.Error.Query.NotFound{}, &1)) do
      :not_found
    else
      Exception.message(error)
    end
  end
end
