# Used by "mix format"
[
  import_deps: [:ash, :ash_boundary],
  # `antipattern/` is not compiled by any normal build (see mix.exs), but it is real
  # source code shipped in this example, so it is format-checked like everything else.
  inputs: ["{mix,.formatter}.exs", "{config,lib,test,antipattern}/**/*.{ex,exs}"]
]
