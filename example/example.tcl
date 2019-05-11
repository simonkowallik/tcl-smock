proc sync_status_color {} {
  set sync_status [tmsh::show /cm sync-status field-fmt]
  foreach line [split $sync_status "\n"] {
    if {[regexp {^\s+color\s(.+)$} $line ignore match]} {
      set extracted_color $match
    }
  }
  return $extracted_color
}
# slightly better version: it's faster and more resilient
#proc sync_status_color {} {
#  set sync_status [tmsh::show /cm sync-status field-fmt]
#  foreach line [split $sync_status "\n"] {
#    if {[regexp {^\s+color\s(.+)$} $line ignore match]} {
#      return $match
#    }
#  }
#}
proc whats_the_status {} {
  set sync_color [sync_status_color]
  switch -- $sync_color {
    "green" {
      return "yep ok, let's do something!"
    }
    "blue" {
      return "lets wait for a little while"
    }
    default {
      return "oh nooo, something is not right!"
    }
  }
}

proc run_example {} {
if { [whats_the_status] eq "yep ok, let's do something!" } {
  return "[sync_status_color] is good! let's make some changes!"
} else {
  return "sync_status_color says: [sync_status_color], status is: [whats_the_status]"
}
}
