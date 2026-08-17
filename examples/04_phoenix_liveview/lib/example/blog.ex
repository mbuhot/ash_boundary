defmodule Example do
  @moduledoc """
  The blog domain.
  """

  use Ash.Domain, extensions: [AshBoundary, AshPhoenix]

  resources do
    resource Example.Post do
      define :list_published_posts, action: :list_published
      define :get_post_by_id, action: :by_id, args: [:id]
      define :create_post, action: :create
      define :list_posts, action: :read
      define :delete_post, action: :destroy
    end
  end

  @doc """
  Looks up a post by id.

  Returns `{:ok, post}`, `{:error, :not_found}`, or `{:error, message}`.
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
  Returns the titles of the published posts.
  """
  @spec published_post_titles() :: [String.t()]
  def published_post_titles do
    Enum.map(list_published_posts!(), & &1.title)
  end

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
