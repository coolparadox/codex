#!/bin/sh
set -e
set -x
ghc -o codexpand codexpand.hs
ghc -o codexplain codexplain.hs
cd ..
./bridge/codexpand 0<codex.adoc | \
./bridge/codexplain 3>/dev/null | \
tee bridge/codex.adoc | \
asciidoctor \
    -r asciidoctor-diagram \
    --backend html5 \
    --failure-level WARN \
    --verbose \
    - 1>codex.html
file codex.html
