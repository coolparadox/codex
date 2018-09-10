#!/bin/bash
set -e -u -o pipefail

tangle() {
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
        test "$CURRENT_CHUNK" = "$1" || continue
        case $LINE in
            /*)
                tangle "$LINE"
                ;;
            *)
                echo $LINE
                ;;
        esac
    done 0<system_specification.adoc
}

mkdir -p src
for FILE in 'codexpand.cpp' ; do
    TARGET=src/$FILE
    tangle "//$FILE" 1>$TARGET
done

pushd src 1>/dev/null
for TARGET in 'codexpand' ; do
    g++ -Wall -o $TARGET ${TARGET}.cpp
done
popd 1>/dev/null

./src/codexpand codedoc.adoc | \
asciidoctor \
    -r asciidoctor-diagram \
    --backend html5 \
    --failure-level WARN \
    --verbose \
    - 1>codedoc.html 
file codedoc.html
