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

## Use the DSL

A domain module carries `define`s, not hand-written functions. Behaviour is
declared on a resource as an action, a calculation, or an aggregate, and exposed
with a domain-level `define`. A bare `def` on a domain module means the DSL was
not used.

Code interfaces return what Ash returns. Never write a wrapper whose job is
translating an Ash error into plain data. Where a caller outside a domain must
match an `Ash.Error.*` struct, name that module in the caller's boundary `deps`:
entries are module-granular for external applications, so the struct is
permitted while the rest of `:ash` stays checked.

## Demonstrating a violation

Show it as commented-out code in the real source file, with the correct usage
directly below it. A reader uncomments one line to watch the compiler reject it.

One short line of explanation above the commented code, no more. Name what is
not allowed. Do not explain the mechanism behind it.

    # Reading a resource through Ash is not allowed
    # assign(socket, posts: Ash.read!(Example.Blog.Post))
    assign(socket, posts: Example.Blog.list_published_posts!())
 The commented code
must describe a path the surrounding contract actually allows: never leave a
clause that could not match, or that implies control flow the code rules out.

It must also be a real boundary violation, meaning a reference the compiler
rejects for crossing a boundary. A missing function, an undefined interface, or
a call to a different action demonstrates something other than this library.

And it must be code a competent developer would plausibly write by accident, a
relationship into another domain's resource being the usual one. If nobody would
write it, blocking it proves nothing.

Do not build fixture directories, extra `MIX_ENV`s, `elixirc_paths` entries, or
tests that shell out to `mix compile`. Do not paste captured compiler output
into a README. The library's own test suite already proves that `boundary`
catches violations.

## Documentation

Describe what the library is and what it does. Never argue for it. A README
section that exists to persuade gets deleted.

Assume the reader knows Elixir, Mix and Ash. Do not explain `--warnings-as-errors`,
`MIX_ENV`, `mix docs`, dependency scoping, or any other general tooling behaviour.
Document what this library does. Everything else is the reader's own knowledge or
another project's documentation.

Prefer short sentences, the active voice, and no em dash.
