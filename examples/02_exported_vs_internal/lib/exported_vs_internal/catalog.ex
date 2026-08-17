defmodule ExportedVsInternal.Catalog do
  @moduledoc """
  A single Ash domain, extended with `AshBoundary`. It holds two resources with a code
  interface each. `AshBoundary` exports only one of them:

    * `ExportedVsInternal.Catalog.Product` carries a domain-level `define` below, in
      this `resources` block. `AshBoundary` marks both `Product` and this domain module
      as exported. Outside code may call `ExportedVsInternal.Catalog.get_product!/1`,
      the domain-level interface, freely. See `ExportedVsInternal.Storefront`.

    * `ExportedVsInternal.Catalog.InternalPricing` carries no domain-level `define`. Its
      `resource` entry below is bare. `AshBoundary` leaves `InternalPricing` out of
      `exports`. The resource module still declares its own `code_interface do define
      :record, ... ; define :calculate, ... end`. This code interface generates real,
      callable functions, `InternalPricing.record!/1` and `InternalPricing.calculate!/1`.
      These functions work the same as any other public function on the module.
      `boundary` sees a module reference; it does not check whether Ash calls a function
      a code interface. The functions work when called from inside
      `ExportedVsInternal.Catalog.*`. See `ExportedVsInternal.Catalog.InternalReports`.
      The compiler rejects a call to either function from outside this namespace. See
      the README.

  A domain-level `define` makes a resource exported. A resource-level `code_interface`
  makes a resource's own module easier to call, from wherever `boundary` already permits
  reaching that module. `boundary` permits reaching a module from outside its owning
  domain only when a domain-level `define` names that module.
  """

  use Ash.Domain, extensions: [AshBoundary]

  resources do
    resource ExportedVsInternal.Catalog.Product do
      define :create_product, action: :create
      define :get_product, action: :read, get_by: [:id]
    end

    resource ExportedVsInternal.Catalog.InternalPricing
  end
end
