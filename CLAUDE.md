# Conventions

## Code carries no explanatory prose

Write the code a competent Elixir developer would write. Nothing more.

- No comment that explains *why* a line is written a certain way.
- No comment that cites library internals, quotes compiler output, or records
  what an experiment proved.
- No comment that points a reader at a README section.
- `@moduledoc` is one flat sentence naming the module, or `@moduledoc false`.
  Never an essay, a bulleted argument, or a numbered list of details.
- Delete prose. Do not condense it, and do not relocate it into a README.

Keep only:

- Generator boilerplate that ships with `mix new` or `mix phx.new`. A reader
  should see a normal generated project.
- A one-line marker naming a deliberate violation in a fixture file.

Explanation belongs in the example READMEs, which are already comprehensive.
A file that needs a comment to be understood usually needs a better name or a
smaller function instead.

## Banned register

Do not write in this style, in code or in documentation:

- "Three details below are load-bearing, not stylistic"
- "The point of this example, in one module"
- "The fix is not an exception. It is a one-line preparation."
- "Verified by compiling it"

No emphasis for its own sake. No two-sentence constructions where the second
sentence restates the first for effect. State the fact once and stop.

## Documentation

Describe what the library is and what it does. Never argue for it. A README
section that exists to persuade gets deleted.

Prefer short sentences, the active voice, and no em dash.
