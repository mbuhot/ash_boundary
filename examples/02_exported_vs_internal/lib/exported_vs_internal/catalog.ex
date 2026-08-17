defmodule ExportedVsInternal.Catalog do
  @moduledoc """
  A single Ash domain, extended with `AshBoundary`, whose whole job is putting two
  superficially similar resources side by side to show they are exported very
  differently:

    * `ExportedVsInternal.Catalog.Product` carries a domain-level `define` below (in
      this `resources` block), so `AshBoundary` computes both `Product` and this domain
      module itself as **exported**. Outside code may call
      `ExportedVsInternal.Catalog.get_product!/1` (the domain-level interface) freely —
      see `ExportedVsInternal.Storefront`.

    * `ExportedVsInternal.Catalog.InternalPricing` carries no domain-level `define` — its
      `resource` entry below is bare — so `AshBoundary` leaves it out of `exports`
      entirely, even though the resource module itself declares its *own*
      `code_interface do define :record, ... ; define :calculate, ... end`. That
      resource-level code interface generates real, callable functions
      (`InternalPricing.record!/1`, `InternalPricing.calculate!/1`), the same as any
      other public function on the module — `boundary` does not know or care that Ash
      calls them a "code interface"; it just sees a module reference. Those functions
      work perfectly when called from *inside* `ExportedVsInternal.Catalog.*` (see
      `ExportedVsInternal.Catalog.InternalReports`), and are rejected by the compiler
      the moment something outside this namespace calls them (see the README).

  This is the distinction sample project 2 exists to make sharp: **"has a code
  interface" and "is exported" are independent facts.** A domain-level `define` is what
  makes a resource exported; a resource-level `code_interface` only makes a resource's
  own module easier to call — from wherever `boundary` already permits reaching that
  module, which is nowhere outside its owning domain unless a domain-level `define`
  says otherwise.
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
