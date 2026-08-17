defmodule Example.Accounts do
  @moduledoc """
  The accounts domain.
  """

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    resource Example.Accounts.Directory do
      define :contributors, action: :contributors
      define :register_author, action: :register, args: [:name, :handle]
      define :author_bylines, action: :bylines, args: [:author_ids]
      define :invite_author, action: :invite, args: [:author_id, :email]
      define :remove_author, action: :remove, args: [:author_id]
    end

    resource Example.Accounts.Author
    resource Example.Accounts.Invitation
  end
end
