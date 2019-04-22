#!/bin/sh
set -e
set -x
ghc -o codexpand codexpand.hs
cd ..
./bridge/codexpand 0<codex.adoc
