defmodule DecouplingViaCalculation.Customers.Directory do
  @moduledoc """
  The customers domain's public interface.
  """

  use Ash.Resource, domain: DecouplingViaCalculation.Customers

  alias DecouplingViaCalculation.Customers.Customer

  actions do
    action :register, :uuid do
      description "Registers a customer and returns only its id."

      argument :first_name, :string, allow_nil?: false
      argument :family_name, :string, allow_nil?: false

      run fn input, _context ->
        customer =
          Customer.create!(%{
            first_name: input.arguments.first_name,
            family_name: input.arguments.family_name
          })

        {:ok, customer.id}
      end
    end

    action :display_names, :map do
      description "Maps each of the given customer ids to that customer's display name."

      argument :ids, {:array, :uuid}, allow_nil?: false

      run fn input, _context ->
        names =
          input.arguments.ids
          |> Enum.uniq()
          |> Customer.by_ids!()
          |> Map.new(&{&1.id, &1.display_name})

        {:ok, names}
      end
    end
  end
end
