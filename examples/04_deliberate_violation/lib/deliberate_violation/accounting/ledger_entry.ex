defmodule DeliberateViolation.Accounting.LedgerEntry do
  @moduledoc """
  This is the real, ETS-backed resource. It is internal.
  `DeliberateViolation.Accounting` names it with a bare `resource` entry below, with no
  domain-level `define`. The rest of this example reaches into this module.

  Sample project 2 makes the same point: an internal module can still hold callable
  functions of its own. `code_interface` below generates real, ordinary functions.
  Only the caller's location is restricted, because this module is not exported.
  `boundary` never inspects how a function came to exist. It checks only whether the
  module the function lives on is exported by its owner boundary.
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
