# load package from ../
lappend auto_path "../"
package require smock 2.0



# init 'mynamespace' with two mock'ed procs: f1 & f2
smock::init mynamespace f1 f2

# mock f1 proc with foo arg to produce "data bar" output
mynamespace::smock mynamespace::f1 foo {data bar}
mynamespace::f1 foo
# enable verbose output
mynamespace::smock_config {+verbose}
# test assertions with verbose output which should produce 'assertion true:...' messages
smock::assert { [string match "assertion true:*" [mynamespace::assert {[mynamespace::f1 foo] eq [mynamespace::f1 foo]}] ] }
smock::assert { [string match "assertion true:*" [mynamespace::assert {[mynamespace::f1 foo] eq {data bar}}] ] }

# disable verbosity
mynamespace::smock_config -verbose
# mock f2
mynamespace::smock mynamespace::f2 bar baz "my data {more data}"
mynamespace::f2 bar baz
mynamespace::assert {[mynamespace::f2 bar baz] eq "my data {more data}"}

# check if -verbose stops assert form producing output on success
mynamespace::assert { [mynamespace::assert {[mynamespace::f2 bar baz] eq "my data {more data}"}] eq "" }

mynamespace::assert { false ne true }
mynamespace::assert { 1 }
mynamespace::assert { true }

# init myOtherNS with f1 - f4
smock::init myOtherNS f1 f2 f3 f4
myOtherNS::smock myOtherNS::f1 foo {data bar}
myOtherNS::f1 foo
myOtherNS::smock_config {+verbose}
myOtherNS::assert {[myOtherNS::f1 foo] eq [myOtherNS::f1 foo]}
myOtherNS::assert {[myOtherNS::f1 foo] eq {data bar}}
myOtherNS::assert {[myOtherNS::f1 foo] ne {not data bar}}

myOtherNS::smock_config -verbose
myOtherNS::smock myOtherNS::f2 bar baz "my data {more data}"
myOtherNS::f2 bar baz
myOtherNS::assert {[myOtherNS::f2 bar baz] eq "my data {more data}"}

# test if assert throws a tcl error, error if it doesn't
if { ! [catch {
  myOtherNS::assert { false }
} err] } {
  return -code error "myOtherNS::assert { false } did not assert"
}

smock::assert { 1 }
smock::config +verbose
smock::assert { [string match "assertion true:*" [smock::assert { 1 }]] }

