# Used by "mix format"
[
  import_deps: [:ash, :ash_boundary],
  # `violation/` is not compiled by any normal build (see mix.exs), but it is real
  # source code shipped in this example, so it is format-checked like everything else.
  inputs: ["{mix,.formatter}.exs", "{config,lib,test,violation}/**/*.{ex,exs}"]
]
