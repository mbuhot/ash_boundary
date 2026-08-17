[
  import_deps: [:ash, :ash_boundary, :phoenix, :phoenix_live_view],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  # No normal build compiles `violation/` or `violation_form/` (see mix.exs). Both hold real source
  # code that this example ships, so the format check covers them like everything else. Example 4
  # does the same for its own `violation/`.
  inputs: ["*.{heex,ex,exs}", "{config,lib,test,violation,violation_form}/**/*.{heex,ex,exs}"]
]
