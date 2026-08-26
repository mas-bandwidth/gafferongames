#!/bin/sh
# Stage one gafferongames.com article for Glenn's eyeball, in place, on the
# live server. Backs the served tree up first, patches exactly ONE article,
# and leaves the rest of the site untouched pending his word.
#
# Runs from this checkout; needs `ssh linux` to be working.
#
#   ./scripts/deploy-sample.sh              # dry run: locate + report only
#   ./scripts/deploy-sample.sh --apply      # backup, patch one article
#   ./scripts/deploy-sample.sh --apply SLUG # a different article
#
# The default sample is fix_your_timestep: the site's best known article, so
# a regression there is obvious at a glance.

set -eu

HOST=linux
MODE="${1:-dry-run}"
SLUG="${2:-fix_your_timestep}"
STAMP=$(date -u +%Y%m%dT%H%M%SZ)

echo "== locating the served tree on $HOST"
DOCROOT=$(ssh -o BatchMode=yes "$HOST" 'for d in /var/www/gafferongames.com/html /var/www/gafferongames/html /var/www/gafferongames.com /var/www/html /usr/share/nginx/html; do [ -f "$d/post/'"$SLUG"'/index.html" ] && { echo "$d"; exit 0; }; done; exit 1') || {
  echo "could not find the served tree; inspect by hand before going further" >&2
  exit 1
}
echo "docroot: $DOCROOT"

if [ "$MODE" != "--apply" ]; then
  echo "(dry run; re-run with --apply to back up and patch $SLUG)"
  exit 0
fi

echo "== backing up the served tree"
BACKUP="/root/gafferongames-backup-$STAMP.tar.gz"
ssh -o BatchMode=yes "$HOST" "tar czf $BACKUP -C $DOCROOT ."
ssh -o BatchMode=yes "$HOST" "ls -la $BACKUP"
echo "backup: $HOST:$BACKUP"

echo "== copying the patcher up"
scp -o BatchMode=yes scripts/patch-supporter-cta.sh "$HOST:/tmp/patch-supporter-cta.sh"

echo "== patching one article: $SLUG"
ssh -o BatchMode=yes "$HOST" "sh /tmp/patch-supporter-cta.sh $DOCROOT --apply post/$SLUG"

echo "== verifying over HTTP"
sleep 2
URL="https://gafferongames.com/post/$SLUG/"
curl -s "$URL" -o /tmp/verify-$SLUG.html
echo "  CTA present:        $(grep -c 'mb-patreon-cta' /tmp/verify-$SLUG.html)"
echo "  membership link:    $(grep -c 'patreon.com/MasBandwidth/membership' /tmp/verify-$SLUG.html)"
echo "  top notice removed: $(sed -n '/article-style/,/article-tags/p' /tmp/verify-$SLUG.html | head -3 | grep -c 'no longer posting' | sed 's/^0$/yes/; s/^[1-9].*$/NO/')"
echo
echo "Glenn's eyeball: $URL"
echo "Site-wide roll is HELD. The RECOMMENDED roll is an rsync of the rebuilt"
echo "tree with deletion, which also fixes meta descriptions and removes the"
echo "deleted theme demo pages (getting-started, jupyter, snail, authors/admin,"
echo "tags/academia) in one move:"
echo "  rsync -av --delete public/ $HOST:$DOCROOT/"
echo "The no-rebuild alternative patches in place, then deletes the demo pages:"
echo "  ssh $HOST 'sh /tmp/patch-supporter-cta.sh $DOCROOT --apply'"
echo "  ssh $HOST 'cd $DOCROOT && rm -rf post/getting-started post/jupyter post/snail authors/admin tags/academia'"
echo "Roll back with:"
echo "  ssh $HOST 'tar xzf $BACKUP -C $DOCROOT'"
