#!/bin/env bash

set -e -u -o pipefail

ME=$( basename $0 )

usage() {
    echo "usage: codex.sh file.adoc" 1>&2
    exit 1
}

test $# -gt 0 || usage
TARGET=$1
test -n "$TARGET" || usage
shift
test $# -eq 0 || usage
test -r "$TARGET" || TARGET="${TARGET}.adoc"

expand() {
    local PATH="$1"
    local STACK="$2"
    for F in $STACK ; do
        test "$F" = "$PATH" && {
            echo "$ME: //include error: inclusion loop detected" >&2
            echo "inclusion stack is:$STACK $PATH" >&2
            exit 1
        } || :
    done
    test -r "$PATH" || {
        echo "$ME: //include error: cannot read file '$PATH'" >&2
        exit 1
    }
    local STATE=0
    local INCLUDE=''
    while IFS='' read -r LINE ; do
        case $STATE in
        0)
            case $LINE in
            ////)
                STATE=1
                ;;
            *)
                echo -E "$LINE"
                ;;
            esac
            ;;
        1)
            case $LINE in
            //include)
                STATE=2
                ;;
            *)
                STATE=4
                echo ////
                echo -E "$LINE"
                ;;
            esac
            ;;
        2)
            case "$LINE" in
            /*)
                STATE=4
                echo ////
                echo //include
                echo -E "$LINE"
                ;;
            *)
                STATE=3
                INCLUDE="$LINE"
                ;;
            esac
            ;;
        3)
            case $LINE in
            ////)
                STATE=0
                expand "$INCLUDE" "$STACK $PATH"
                ;;
            *)
                STATE=4
                echo ////
                echo //include
                echo -E "$INCLUDE"
                echo -E "$LINE"
                ;;
            esac
            ;;
        4)
            case $LINE in
            ////)
                STATE=0
                ;;
            esac
            echo -E "$LINE"
            ;;
        esac
    done <"$PATH"
}

DB_DIR=.codex
rm -rf $DB_DIR
mkdir -p $DB_DIR

fail() {
    echo "${ME}: error: $*"
    exit 1
}

parse() {
    local STATE=adoc
    local FILE
    while IFS='' read -r LINE ; do
        case $STATE in

        adoc)
            case $LINE in

            ////)
                STATE=block
                ;;

            *)
                echo -E "a:$LINE"
                ;;

            esac
            ;;

        block)
            case $LINE in

            ////)
                STATE=adoc
                ;;

            ///*)
                fail "unexpected slash heading at '$LINE'"
                ;;

            //*)
                SPECIAL=${LINE#//}
                STATE=special
                ;;

            /*)
                FILE=$( realpath -m --relative-to=/ "$LINE" )
                STATE=file
                ;;

            *)
                CHUNK=$LINE
                STATE=chunk
                ;;

            esac
            ;;

        special)
            case $LINE in

                ////)
                    STATE=adoc
                    echo "s:$SPECIAL"
                    ;;

            esac
            ;;

        file)
            case $LINE in

                ////)
                    STATE=adoc
                    echo "f:$FILE"
                    ;;

            esac
            ;;

        chunk)
            case $LINE in

                ////)
                    STATE=adoc
                    echo "c:$CHUNK"
                    ;;

            esac
            ;;

        esac
    done
}

expand "$TARGET" '' | \
parse
