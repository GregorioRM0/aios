#!/usr/bin/env bash
# Unfinished work with no task: notes whose frontmatter `status:` says the work is still open
# (proposal, draft, in progress…) and that no open `- [ ]` task links to with a [[wikilink]],
# neither in a project note nor in the newest daily note. READ-ONLY.
#
# Why: /today and the carries read TASKS, not documents. A multi-phase plan saved as a note
# and closed as done after its first phase has no exit — nothing ever surfaces the rest.
#
# Called by /close-day (daily) and /today (Mondays).
# Output: one `unfinished-work:` line per finding, or `unfinished-work: none`. Always exits 0.
#
# Status vocabulary: operators write `status:` in their own language. Override the default
# list with AIOS_OPEN_STATUSES as a `|`-separated, case-insensitive list.

VAULT="${AIOS_VAULT:-$HOME/aios/vault}"
NOTES="$VAULT/00 - notes"
CAL="$VAULT/01 - calendar"
OPEN="${AIOS_OPEN_STATUSES:-proposal|proposed|draft|in progress|in-progress|wip|open|pending|partial}"
[ -d "$NOTES" ] || { echo "unfinished-work: none (no notes folder at $NOTES)"; exit 0; }

# Open tasks that can link a document: project notes + the newest daily note.
newest=$(find "$CAL" -type f -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md' 2>/dev/null | sort | tail -1)
open_tasks=$( { cat "$NOTES/projects/"*.md 2>/dev/null; [ -n "$newest" ] && cat "$newest"; } | grep -E '^[[:space:]]*- \[ \]' )

found=0
while IFS= read -r -d '' f; do
  status=$(awk 'NR==1 && $0!="---"{exit} NR>1 && $0=="---"{exit} /^status:/{sub(/^status:[[:space:]]*/,""); gsub(/["'"'"']/,""); print; exit}' "$f")
  [ -n "$status" ] || continue
  printf '%s\n' "$status" | grep -qiE "^($OPEN)\$" || continue
  base=$(basename "$f" .md)
  if ! printf '%s\n' "$open_tasks" | grep -qF "[[$base"; then
    echo "unfinished-work: ${f#$NOTES/} (status: $status) — no open task links to it"
    found=$((found+1))
  fi
done < <(find "$NOTES" -type f -name '*.md' \
  -not -path "$NOTES/logs/*" -not -path "$NOTES/context/*" -not -path "$NOTES/projects/*" -print0)

[ "$found" -eq 0 ] && echo "unfinished-work: none"
exit 0
