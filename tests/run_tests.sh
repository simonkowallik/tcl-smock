#!/usr/bin/env bash

_tclsh=$(command -v tclsh8.4)
_tclsh=${_tclsh:-tclsh}

set -ev

$_tclsh tests/test.tcl
