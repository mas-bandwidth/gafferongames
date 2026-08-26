#!/bin/sh
# Bring already-deployed gafferongames.com article pages in line with the
# current source, without a rebuild. Two edits per article page:
#
#   1. remove the "no longer posting / check out my new blog" notice at the TOP
#      of the article body (the one immediately after the article-style div
#      opens). The same notice at the BOTTOM of the article is left alone.
#   2. insert the Patreon supporter block just above the article tags.
#
# Both edits are idempotent and identify their target by POSITION, not by text,
# so re-running is a no-op and a page rebuilt from source is never damaged.
#
# Runs against a document root (the live server's html dir, or a checkout's
# public/ dir). Article pages only: DOCROOT/post/*/index.html. Pages missing a
# structural anchor are left untouched and reported.
#
# POSIX sh + awk on purpose: it must run on the Linode with no toolchain.
#
# Usage:
#   ./patch-supporter-cta.sh DOCROOT            # dry run (default)
#   ./patch-supporter-cta.sh DOCROOT --apply    # write changes
#   ./patch-supporter-cta.sh DOCROOT --apply post/fix_your_timestep  # one page

set -eu

DOCROOT="${1:?usage: patch-supporter-cta.sh DOCROOT [--apply] [post/slug]}"
MODE="${2:-dry-run}"
ONLY="${3:-}"

MARKER='mb-patreon-cta'
ANCHOR='<div class="article-tags">'
BODY_OPEN='<div class="article-style" itemprop="articleBody">'
NOTICE='no longer posting new content'

# \n escapes: awk -v expands them, and BSD awk rejects literal newlines in -v.
# The mb-patreon-cta class doubles as the idempotency marker, and matches the
# block the Hugo template override emits on a rebuild.
BLOCK='<div class="mb-patreon-cta" style="max-width:640px;margin:3rem auto 2.5rem;padding:2rem 1.25rem 0;border-top:1px solid rgba(0,0,0,.12);text-align:center;font-size:1.4rem;line-height:1.5;font-weight:600">\nEnjoying my articles and open source code?<br>\n<a href="https://www.patreon.com/MasBandwidth/membership" style="display:inline-block;margin-top:1.25rem;padding:1.6rem 4rem;border-radius:12px;background:#ff8800;color:#fff;font-size:2.3rem;font-weight:800;text-decoration:none">Support my work!</a>\n</div>'

patched=0; skipped=0; unmatched=0

# getting-started, jupyter and snail are Academia theme demo pages: still
# deployed and still tracked in public/, but no longer generated from any
# content/post/*.md. The Hugo build never touches them, so neither does this.
ORPHANS=' getting-started jupyter snail '

for f in "$DOCROOT"/post/*/index.html; do
  [ -f "$f" ] || continue
  case "$f" in */post/page/*) continue ;; esac
  slug=$(basename "$(dirname "$f")")
  case "$ORPHANS" in *" $slug "*) continue ;; esac
  if [ -n "$ONLY" ]; then
    case "$f" in *"$ONLY"*) ;; *) continue ;; esac
  fi

  have_cta=no; grep -q "$MARKER" "$f" && have_cta=yes
  # The top notice is present only if the notice line sits within the first few
  # lines after the article body opens; awk decides that precisely below.
  need_top=$(awk -v body="$BODY_OPEN" -v notice="$NOTICE" '
    index($0, body) { at = NR }
    at && NR > at && NR <= at + 2 && index($0, notice) { print "yes"; exit }
  ' "$f")
  [ -n "$need_top" ] || need_top=no

  if [ "$have_cta" = yes ] && [ "$need_top" = no ]; then
    skipped=$((skipped+1))
    continue
  fi
  if ! grep -qF "$ANCHOR" "$f"; then
    echo "unmatched (no anchor): $f"
    unmatched=$((unmatched+1))
    continue
  fi

  if [ "$MODE" = "--apply" ]; then
    awk -v block="$BLOCK" -v anchor="$ANCHOR" -v body="$BODY_OPEN" \
        -v notice="$NOTICE" -v have_cta="$have_cta" '
      function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }

      # Buffer the article-body opener and the line after it, so the leading
      # <hr> of the top notice can be dropped along with the notice itself.
      index($0, body) && !seen_body { seen_body = 1; print; hold_at = NR; next }

      seen_body && !top_removed && NR == hold_at + 1 {
        if (trim($0) == "<hr>") { held = $0; next }
        print; next
      }

      seen_body && !top_removed && held != "" && index($0, notice) {
        # Drop the held <hr>, this notice paragraph, and the h3 + closing <hr>.
        held = ""; dropping = 1; top_removed = 1; next
      }

      dropping {
        if (trim($0) == "<hr>") { dropping = 0 }
        next
      }

      # Not the top notice after all: flush the held <hr> before continuing.
      held != "" { print held; held = "" }

      have_cta != "yes" && !cta_done && index($0, anchor) { print block; cta_done = 1 }
      { print }
      END { if (held != "") print held }
    ' "$f" > "$f.mbcta.tmp" && mv "$f.mbcta.tmp" "$f"
    echo "patched: $f (top-notice-removed=$need_top cta-inserted=$([ "$have_cta" = yes ] && echo no || echo yes))"
  else
    echo "would patch: $f (remove-top=$need_top insert-cta=$([ "$have_cta" = yes ] && echo no || echo yes))"
  fi
  patched=$((patched+1))
done

echo "done. patched=$patched skipped=$skipped unmatched=$unmatched (mode: $MODE)"
