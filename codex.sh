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

WD=.codex
rm -rf $WD
mkdir -p $WD

fail() {
    echo "${ME}: error: $*"
    exit 1
}

parse() {
    local STATE=adoc
    local NAME=''
    local PART=0
    local FORM=0
    while IFS='' read -r LINE ; do
        case $STATE in

        adoc)
            # I'm parsing regular asciidoc text.
            case $LINE in

            ////)
                # A comment block started.
                STATE=block
                ;;

            *)
                # The line is part of the regular ascidoc content.
                echo -E "a:$LINE"
                ;;

            esac
            ;;

        block)
            # I'm parsing the first line of a comment block.
            case $LINE in

            ////)
                # The comment block ended.
                STATE=adoc
                ;;

            ///*)
                # The line does not tell if the block is one of the expected codex constructs.
                fail "unexpected slash heading at '$LINE'"
                ;;

            //*)
                # The block is a codex special.
                SPECIAL=${LINE#//}
                STATE=special
                ;;

            /*)
                # The block is another part of a codex file.
                NAME=$( realpath -m --relative-to=/ "$LINE" )
                STATE=file
                ;;

            *)
                # The block is another part of the current form of a codex chunk.
                NAME=$LINE
                STATE=chunk
                ;;

            esac
            ;;

        special)
            # I'm parsing a codex special.
            # FIXME: remove this state when all specials are covered by the state machine.
            case $LINE in

                ////)
                    STATE=adoc
                    echo "s:$SPECIAL"
                    ;;

            esac
            ;;

        file)
            # I'm parsing part $PART of file $NAME.
            case $LINE in

                ////)
                    # Part $PART of file $NAME ended.
                    STATE=adoc
                    echo "f:$NAME"
                    ;;

            esac
            ;;

        chunk)
            # I'm parsing part $PART of form $FORM of chunk $NAME.
            case $LINE in

                ////)
                    # Part $PART of form $FORM of chunk $NAME ended.
                    STATE=adoc
                    echo "c:$NAME"
                    ;;

            esac
            ;;

        esac
    done
}

expand "$TARGET" '' | \
parse
