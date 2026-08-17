defmodule Example.Accounts do
  @moduledoc """
  The accounts domain.
  """

  use Ash.Domain, extensions: [AshBoundary, AshPhoenix]

  resources do
    resource Example.Accounts.Author do
      define :list_authors, action: :list_alphabetical
      define :get_author_by_id, action: :by_id, args: [:id]
      define :create_author, action: :create
      define :delete_author, action: :destroy
    end

    resource Example.Accounts.Invitation
  end

  @doc """
  Records an invitation for `email`.
  """
  @spec invite_author(String.t()) :: :ok | {:error, String.t()}
  def invite_author(email) do
    case Ash.create(Example.Accounts.Invitation, %{email: email}) do
      {:ok, _invitation} -> :ok
      {:error, error} -> {:error, Exception.message(error)}
    end
  end

  @doc """
  Counts the invitations nobody has accepted yet.
  """
  @spec pending_invitation_count() :: non_neg_integer()
  def pending_invitation_count do
    Example.Accounts.Invitation
    |> Ash.read!(action: :pending)
    |> length()
  end

  @doc """
  Looks up an author by id.

  Returns `{:ok, author}`, `{:error, :not_found}`, or `{:error, message}`.
  """
  @spec fetch_author(term()) ::
          {:ok, Example.Accounts.Author.t()} | {:error, :not_found | String.t()}
  def fetch_author(id) do
    case get_author_by_id(id) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, author} -> {:ok, author}
      {:error, error} -> {:error, Example.Accounts.Errors.translate(error)}
    end
  end
end
