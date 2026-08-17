defmodule Example.Accounts.Author do
  @moduledoc false

  use Ash.Resource,
    domain: Example.Accounts,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
  end

  attributes do
    uuid_primary_key :id

    attribute :name, :string, allow_nil?: false, public?: true
    attribute :handle, :string, allow_nil?: false, public?: true
  end

  relationships do
    has_many :invitations, Example.Accounts.Invitation
  end

  calculations do
    calculate :display_name, :string, Example.Accounts.Author.Calculations.DisplayName do
      public? true
    end
  end

  aggregates do
    count :pending_invitations, :invitations do
      filter expr(accepted? == false)
      public? true
    end
  end

  actions do
    defaults [:read, :destroy, create: [:name, :handle]]

    read :list_alphabetical do
      prepare build(load: [:display_name, :pending_invitations], sort: [name: :asc])
    end

    read :by_id do
      argument :id, :uuid, allow_nil?: false
      get? true
      filter expr(id == ^arg(:id))
      prepare build(load: [:display_name, :pending_invitations])
    end

    update :invite do
      require_atomic? false
      argument :email, :string, allow_nil?: false
      change manage_relationship(:email, :invitations, type: :create, value_is_key: :email)
    end
  end
end
