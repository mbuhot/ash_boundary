defmodule DeliberateViolation.Accounting.LedgerEntry do
  @moduledoc """
  The real, ETS-backed resource — and **internal**, because
  `DeliberateViolation.Accounting` names it with a bare `resource` entry, with no
  domain-level `define`. This is the module the rest of this example reaches into.

  As in sample project 2, being internal does not mean this module has no callable
  functions of its own: `code_interface` below generates real, ordinary ones. Only where
  they may be called from is restricted, and only because this module is not exported —
  `boundary` never inspects how a function came to exist, only whether the module it
  lives on is exported by its owner boundary.
  """

  use Ash.Resource,
    domain: DeliberateViolation.Accounting,
    data_layer: Ash.DataLayer.Ets

  ets do
    private?(true)
  end

  attributes do
    uuid_primary_key :id
    attribute :description, :string, allow_nil?: false, public?: true
    attribute :amount, :integer, allow_nil?: false, public?: true
  end

  actions do
    defaults [:read, create: [:description, :amount]]
  end

  code_interface do
    define :create
    define :read, action: :read
  end
end
