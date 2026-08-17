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

  @doc """
  Writes `sources` as files under `dir` and compiles them together through the parallel
  compiler, returning the first error message or `nil`.

  `Code.compile_string/1` compiles sequentially in the calling process, so it cannot
  produce the one situation this is for: two modules being compiled at once, each waiting
  on the other. Going through `Kernel.ParallelCompiler` is what makes
  `Code.ensure_compiled/1` return `{:error, :unavailable}`.
  """
  @spec parallel_error(Path.t(), [{Path.t(), String.t()}]) :: String.t() | nil
  def parallel_error(dir, sources) do
    paths =
      for {name, source} <- sources do
        path = Path.join(dir, name)
        File.write!(path, source)
        path
      end

    {result, _output} = with_io(:stderr, fn -> Kernel.ParallelCompiler.compile(paths) end)

    case result do
      {:error, [{_file, _position, message} | _rest], _warnings} -> message
      _compiled -> nil
    end
  end
end
