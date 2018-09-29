#!/bin/bash
set -e -u -o pipefail

extrude() {
    local TARGET_CHUNK=$1
    local CODEX_FILE=$2
    local INSIDE_LITERAL=0
    local CURRENT_CHUNK=''
    while read LINE ; do
        test "$LINE" = '////' && {
            if test $INSIDE_LITERAL -eq 0 ; then
                INSIDE_LITERAL=1
            else
                INSIDE_LITERAL=0
                CURRENT_CHUNK=''
            fi
            continue
        }
        test $INSIDE_LITERAL -ne 0 || continue
        test -n "$CURRENT_CHUNK" || {
            CURRENT_CHUNK=$LINE
            continue
        }
        test "$CURRENT_CHUNK" = "$TARGET_CHUNK" || continue
        case $LINE in
            /*)
                extrude "$LINE" "$CODEX_FILE"
                ;;
            *)
                echo "$LINE"
                ;;
        esac
    done 0<$CODEX_FILE
}

mkdir -p src

extrude '//codexpand.cpp' codex_expansion.adoc 1>src/codexpand.cpp
( cd src && g++ -Wall -o codexpand codexpand.cpp )
./src/codexpand codex.adoc | \
asciidoctor \
    -r asciidoctor-diagram \
    --backend html5 \
    --failure-level WARN \
    --verbose \
    - 1>codex.html 
file codex.html

extrude '//codexplain.cpp' codex_explanation.adoc 1>src/codexplain.cpp
( cd src && g++ -Wall -o codexplain codexplain.cpp )
