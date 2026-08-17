#!/usr/bin/env bash
# Rejects an Elixir file whose comments or @moduledoc have grown into prose.
# Reads the PostToolUse hook payload on stdin.
set -uo pipefail

f=$(jq -r '.tool_response.filePath // .tool_input.file_path // empty' 2>/dev/null)

case "$f" in
  *.ex|*.exs) ;;
  *) exit 0 ;;
esac

[ -f "$f" ] || exit 0

# Generated project scaffolding keeps its stock comments.
case "$f" in
  */config/*|*/mix.exs|*/test_helper.exs) exit 0 ;;
  */application.ex|*/endpoint.ex|*/telemetry.ex|*/router.ex) exit 0 ;;
  */core_components.ex|*/layouts.ex|*/error_html.ex|*/error_json.ex) exit 0 ;;
esac

total=$(grep -c '' "$f")
[ "$total" -lt 20 ] && exit 0

comments=$(grep -c '^[[:space:]]*#' "$f" || true)
moduledoc=$(awk '
  /@moduledoc[[:space:]]+"""/ { inside = 1; next }
  inside && /^[[:space:]]*"""/ { inside = 0; next }
  inside { n++ }
  END { print n + 0 }
' "$f")

problems=""
[ "$((comments * 100))" -gt "$((total * 10))" ] &&
  problems="${problems}${comments} comment lines in ${total} lines, over the 10% limit. "
[ "$moduledoc" -gt 12 ] &&
  problems="${problems}@moduledoc is ${moduledoc} lines, over the 12 line limit. "

[ -z "$problems" ] && exit 0

jq -n --arg f "$f" --arg p "$problems" '{
  decision: "block",
  reason: ("\($f): \($p)See CLAUDE.md. Code carries no explanatory prose. Delete it, do not condense it or move it to a README.")
}'
exit 0
