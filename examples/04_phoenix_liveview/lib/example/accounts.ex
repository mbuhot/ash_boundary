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
      define :invite_author, action: :invite, args: [:email]
      define :delete_author, action: :destroy
    end

    resource Example.Accounts.Invitation
  end
end
