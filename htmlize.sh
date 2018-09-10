#!/bin/bash
set -v
exec asciidoctor -r asciidoctor-diagram --backend html5 --failure-level WARN --verbose codedoc.adoc 
