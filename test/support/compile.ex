defmodule AshBoundary.Test.Compile do
  @moduledoc """
  Compiles a module from source and hands back whatever it raised.

  Compile-time errors from a Spark transformer are only observable by actually compiling
  a module, and the compiler is chatty while doing it — protocol consolidation notices,
  redefinition warnings. Both helpers swallow that noise so a failing assertion shows the
  error under test and nothing else.
  """

  import ExUnit.CaptureIO

  @doc """
  Compiles `source`, returning the exception it raised, or `nil` if it compiled cleanly.
  """
  @spec error(String.t()) :: Exception.t() | nil
  def error(source) do
    {result, _output} =
      with_io(:stderr, fn ->
        try do
          Code.compile_string(source)
          nil
        rescue
          error -> error
        end
      end)

    result
  end

  @doc """
  Compiles `source`, returning the modules it defined.
  """
  @spec modules(String.t()) :: [module()]
  def modules(source) do
    {compiled, _output} = with_io(:stderr, fn -> Code.compile_string(source) end)

    Enum.map(compiled, fn {module, _binary} -> module end)
  end
end
