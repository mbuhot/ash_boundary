defmodule Example.Post do
  @moduledoc """
  The blog post resource. `Example` exports it, because the resource carries domain-level
  `define`s. The export matters, because the point of this example is that a web layer can
  receive these structs and match on them.

  ## Every attribute uses a plain type, deliberately

  `uuid_primary_key` produces a plain binary. `title`, `body`, and `author` are `:string`.
  `word_count` is `:integer`. `published?` is `:boolean`. No attribute here is an
  `Ash.CiString`, an `Ash.Type.Union` value, or any other struct in the `Ash.*` namespace.

  This is a deliberate simplification of the example. It is not a property of the mechanism.
  `ExampleWeb`'s boundary forbids all references into the `:ash` application, and `boundary`'s
  app check works at application level. A `:ci_string` attribute therefore hands the web layer
  an `%Ash.CiString{}` to render. A template that matches that struct, or calls
  `Ash.CiString.value/1`, makes a real forbidden reference. Plain types keep every field the
  LiveView touches a binary, an integer, or a boolean. The claim of zero `Ash.*` surface in the
  web layer then holds with no exception. An application that wants case-insensitive strings
  must translate at the domain edge, as `Example.fetch_post/1` translates errors, or accept
  an `Ash.*` reference in its web layer.

  ## `:excerpt` is a calculation, and the read action loads it

  Ash loads no calculation by default. The obvious way to get `:excerpt` into a template is a
  call to `Ash.load!(post, :excerpt)` in the web layer. This example forbids that call. The
  `:list_published` action carries `prepare build(load: [:excerpt])` instead. The struct that
  `Example.list_published_posts!/0` returns is therefore already loaded, and the LiveView
  only reads a field. See `Example`'s moduledoc for why this is the correct fix and not a
  workaround.
  """

  use Ash.Resource,
    domain: Example,
    data_layer: Ash.DataLayer.Ets

  ets do
    # Examples 1 to 4 use `private? true`, which scopes the ETS table to the process that created
    # it. That setting suits a test-only example. It is wrong here. A web request runs in a
    # different process from the one that seeded the data, as `Example.Application.start/2` shows,
    # and each LiveView mount is another process again. A private table therefore renders an empty
    # list on every page. A real application wants a shared table. That choice is also why this
    # example's tests clear the table between runs instead of relying on process isolation.
    private?(false)
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string, allow_nil?: false, public?: true
    attribute :body, :string, allow_nil?: false, public?: true
    attribute :author, :string, allow_nil?: false, public?: true
    attribute :published?, :boolean, allow_nil?: false, public?: true, default: true
  end

  calculations do
    # A plain `:string` calculation. Ash does not load it unless something asks for it. That
    # fact makes it the interesting case here. The domain asks for it, in `:list_published`
    # below, so the web layer never has to.
    calculate :excerpt, :string, Example.Post.Calculations.Excerpt do
      public? true
    end

    # A plain `:integer`, for the same reason, and written as an `expr/1` calculation to show
    # that the loading story is identical whichever style a calculation uses.
    calculate :word_count, :integer, expr(length(string_split(body))) do
      public? true
    end
  end

  actions do
    defaults [:read, :destroy, create: [:title, :body, :author, :published?]]

    read :list_published do
      filter expr(published? == true)

      # This is the most important line in the example after `ExampleWeb`'s boundary declaration.
      # It loads both calculations here, in the domain. The struct that reaches the LiveView is
      # therefore complete, and the LiveView needs no `Ash.load/2` call. It could not make that
      # call anyway.
      prepare build(load: [:excerpt, :word_count], sort: [title: :asc])
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
      prepare build(load: [:excerpt, :word_count])
    end

    # A real update action that the domain deliberately does not declare. `Example`'s `resources`
    # block has no `define` for it.
    #
    # This action exists to prove a property of the form mechanism. The `AshPhoenix` extension
    # generates a `form_to_<name>` function for each `define` on the domain, and only for those.
    # There is no `define` for `:moderate`, so `Example.form_to_moderate_post/1` does not exist,
    # and the web layer cannot build a form for this action.
    # `violation_form/example_web/live/undefined_form_live.ex` proves that.
    update :moderate do
      accept [:published?]
    end
  end
end
