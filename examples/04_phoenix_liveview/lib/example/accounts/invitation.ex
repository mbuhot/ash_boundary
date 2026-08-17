defmodule Example.Accounts.Invitation do
  @moduledoc false

  use Ash.Resource,
    domain: Example.Accounts,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(false)
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :string, allow_nil?: false, public?: true
    attribute :accepted?, :boolean, allow_nil?: false, public?: true, default: false
  end

  relationships do
    belongs_to :author, Example.Accounts.Author do
      allow_nil? false
    end
  end

  actions do
    defaults [:read, :destroy, create: [:email, :accepted?]]
  end
end
