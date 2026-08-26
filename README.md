Source code for https://gafferongames.com

## Building

The site builds with pinned Hugo 0.124.1 extended, the exact version that
generated the committed public/. The system hugo is never used.

    make build

This downloads the pinned Hugo release for your platform (macOS or Linux),
verifies it against the official release checksums, caches it under dist/
keyed by version, and regenerates public/.

    make local

Serves a live preview at http://127.0.0.1:1313 with the same pinned binary.
