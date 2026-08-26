#!/bin/sh
# Bring already-deployed gafferongames.com article pages in line with the
# current source, without a rebuild. Two edits per article page:
#
#   1. remove every "no longer posting / check out my new blog" notice block
#      (each article carried one at the top of the body and one at the bottom)
#   2. insert the Patreon supporter block just above the article tags
#
# A notice block is identified by its exact 4-line structure (<hr>, the notice
# paragraph, the check-out-my-new-blog heading, <hr>), so the edits are
# idempotent and a page rebuilt from current source (which contains no notice)
# is never touched.
#
# Runs against a document root (the live server's html dir, or a checkout's
# public/ dir). Article pages only: DOCROOT/post/*/index.html. Pages missing
# the structural anchor are left untouched and reported.
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
NOTICE='no longer posting new content'
HEADING='Please check out my new blog'

# \n escapes: awk -v expands them, and BSD awk rejects literal newlines in -v.
# The mb-patreon-cta class doubles as the idempotency marker, and matches the
# block the Hugo template override emits on a rebuild.
BLOCK='<div class="mb-patreon-cta" style="max-width:640px;margin:3rem auto 2.5rem;padding:2rem 1.25rem 0;border-top:1px solid rgba(0,0,0,.12);text-align:center;font-size:1.4rem;line-height:1.5;font-weight:600">\nEnjoying my articles and open source code?<br>\n<a href="https://www.patreon.com/MasBandwidth/membership" style="display:inline-block;margin-top:1.25rem;padding:1.6rem 4rem;border-radius:12px;background:#ff8800;color:#fff;font-size:2.3rem;font-weight:800;text-decoration:none">Support my work!</a>\n</div>'

# getting-started, jupyter and snail were Academia theme demo pages, generated
# from no source and ruled deleted. The deploy removes their directories; this
# never writes into them.
ORPHANS=' getting-started jupyter snail '

patched=0; skipped=0; unmatched=0

for f in "$DOCROOT"/post/*/index.html; do
  [ -f "$f" ] || continue
  case "$f" in */post/page/*) continue ;; esac
  slug=$(basename "$(dirname "$f")")
  case "$ORPHANS" in *" $slug "*) continue ;; esac
  if [ -n "$ONLY" ]; then
    case "$f" in *"$ONLY"*) ;; *) continue ;; esac
  fi

  need_cta=yes; grep -q "$MARKER" "$f" && need_cta=no
  # The h3 tag exists only in the body blocks; the notice TEXT also appears in
  # the meta description, which only a rebuild can correct.
  need_notice=no; grep -q '<h3 id="please-check-out-my-new-blog' "$f" && need_notice=yes

  if [ "$need_cta" = no ] && [ "$need_notice" = no ]; then
    skipped=$((skipped+1))
    continue
  fi
  if ! grep -qF "$ANCHOR" "$f"; then
    echo "unmatched (no anchor): $f"
    unmatched=$((unmatched+1))
    continue
  fi

  if [ "$MODE" = "--apply" ]; then
    awk -v block="$BLOCK" -v anchor="$ANCHOR" -v notice="$NOTICE" \
        -v heading="$HEADING" -v need_cta="$need_cta" '
      function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
      { L[NR] = $0 }
      END {
        i = 1
        while (i <= NR) {
          if (trim(L[i]) == "<hr>" && i + 3 <= NR && \
              index(L[i+1], notice) && index(L[i+2], heading) && \
              trim(L[i+3]) == "<hr>") { i += 4; continue }
          if (need_cta == "yes" && !cta_done && index(L[i], anchor)) {
            print block
            cta_done = 1
          }
          print L[i]
          i++
        }
      }
    ' "$f" > "$f.mbcta.tmp" && mv "$f.mbcta.tmp" "$f"
    echo "patched: $f (notices-removed=$need_notice cta-inserted=$need_cta)"
  else
    echo "would patch: $f (remove-notices=$need_notice insert-cta=$need_cta)"
  fi
  patched=$((patched+1))
done

echo "done. patched=$patched skipped=$skipped unmatched=$unmatched (mode: $MODE)"
