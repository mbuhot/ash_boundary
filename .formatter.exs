# Used by "mix format"

# Regenerate with `mix spark.formatter --extensions AshBoundary`.
spark_locals_without_parens = [check: 1, deps: 1, dirty_xrefs: 1, exports: 1, type: 1]

[
  import_deps: [:ash, :spark],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test}/**/*.{ex,exs}"],
  locals_without_parens: spark_locals_without_parens,
  export: [locals_without_parens: spark_locals_without_parens]
]
