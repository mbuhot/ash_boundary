defmodule Example.Accounts.Directory do
  @moduledoc false

  use Ash.Resource, domain: Example.Accounts

  require Ash.Query

  alias Example.Accounts.Author

  actions do
    action :contributors, {:array, :map} do
      run fn _input, _context ->
        {:ok, Enum.map(Ash.read!(Author, action: :list_alphabetical), &contributor/1)}
      end
    end

    action :register, :map do
      argument :name, :string, allow_nil?: false
      argument :handle, :string, allow_nil?: false

      run fn input, _context ->
        Author
        |> Ash.create(Map.take(input.arguments, [:name, :handle]),
          load: [:display_name, :pending_invitations]
        )
        |> case do
          {:ok, author} -> {:ok, contributor(author)}
          {:error, error} -> {:error, error}
        end
      end
    end

    action :bylines, :map do
      argument :author_ids, {:array, :uuid}, allow_nil?: false

      run fn input, _context ->
        Author
        |> Ash.Query.filter(id in ^input.arguments.author_ids)
        |> Ash.Query.load(:display_name)
        |> Ash.read()
        |> case do
          {:ok, authors} -> {:ok, Map.new(authors, &{&1.id, &1.display_name})}
          {:error, error} -> {:error, error}
        end
      end
    end

    action :invite, :map do
      argument :author_id, :uuid, allow_nil?: false
      argument :email, :string, allow_nil?: false

      run fn input, _context ->
        with {:ok, author} <- Ash.get(Author, input.arguments.author_id),
             {:ok, invited} <-
               Ash.update(author, %{email: input.arguments.email},
                 action: :invite,
                 load: [:display_name, :pending_invitations]
               ) do
          {:ok, contributor(invited)}
        end
      end
    end

    action :remove do
      argument :author_id, :uuid, allow_nil?: false

      run fn input, _context ->
        with {:ok, author} <- Ash.get(Author, input.arguments.author_id) do
          Ash.destroy(author)
        end
      end
    end
  end

  defp contributor(author) do
    %{
      id: author.id,
      display_name: author.display_name,
      pending_invitations: author.pending_invitations
    }
  end
end
