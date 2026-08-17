defmodule DeliberateViolation.Billing do
  @moduledoc """
  The billing domain.
  """

  use Ash.Domain, extensions: [AshBoundary]

  boundary do
    deps [DeliberateViolation.Accounting]
  end

  resources do
    resource DeliberateViolation.Billing.Invoice do
      define :issue_invoice, action: :create
      define :get_invoice, action: :read, get_by: [:id]
    end
  end
end
