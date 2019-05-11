package provide smock 1.0
package require Tcl 8.4

namespace eval ::smock {
  # export init only
  namespace export init
  variable ::ns
  variable ::func
}
proc ::smock::init {ns args} {
  set ::smock::ns $ns
  uplevel 1 {
    namespace eval $::smock::ns {
      array set ::data {}
      set ::${::smock::ns}::verbose 0
    }
  }
  # all function bodies need to be generated
  # generate procs
  foreach ::smock::func $args {
    uplevel 1 {
      set fbody "return \[lindex \[array get ::${::smock::ns}::data \[join \"${::smock::ns}::${::smock::func} \$args\" \" \"\]\] 1\]"
      proc ${::smock::ns}::${::smock::func} {args} $fbody
    }
  }
  uplevel 1 {
    set fbody {if {[llength $args] < 2} {return -code error "requires at least two arguments: cmd data"}}
    append fbody {;set cmd [join [lrange $args 0 end-1] " "]}
    append fbody {;set data [lindex $args end]}
    append fbody {;set li {}}
    append fbody {;lappend li $cmd}
    append fbody {;lappend li $data}
    append fbody ";array set ::${::smock::ns}::data \$li"
    proc ${::smock::ns}::smock {args} $fbody

    set fbody {if {![uplevel 1 expr $args]} {return -code error "assertion failed: $args"}}
    append fbody " elseif { \$${::smock::ns}::verbose }"
    append fbody { { return -code ok "assertion ok: $args" } else {return -code ok {}}}
    proc ${::smock::ns}::assert {args} $fbody

    set fbody "switch -- \$args { \"+verbose\" {set ::${::smock::ns}::verbose 1} \"-verbose\" {set ::${::smock::ns}::verbose 0} }"
    proc ${::smock::ns}::smock_config {args} $fbody
  }
}