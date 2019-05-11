# tcl-smock
[![Travis Build Status](https://img.shields.io/travis/com/simonkowallik/tcl-smock/master.svg?label=travis%20build)](https://travis-ci.com/simonkowallik/tcl-smock)
[![Releases](https://img.shields.io/github/release/simonkowallik/tcl-smock.svg)](https://github.com/simonkowallik/tcl-smock/releases)
[![Commits since latest release](https://img.shields.io/github/commits-since/simonkowallik/tcl-smock/latest.svg)](https://github.com/simonkowallik/tcl-smock/commits)
[![Latest Release](https://img.shields.io/github/release-date/simonkowallik/tcl-smock.svg?color=blue)](https://github.com/simonkowallik/tcl-smock/releases/latest)

## smock, a simple mock package
I build smock for F5 iApp and iCall script function mocking to build basic unit tests.

When you build your own iApps or iCall scripts you often depend on commands in the tmsh:: or iapp:: namespace.
These again fetch state and information from the underlying BIG-IP system and it's configuration state.
Therefore even simple testing can get quite complicated, especially when introducing changes at a later time.

The idea with this mocking implementation is to capture this state when you first build and test your code for later re-tests.

`smock` is a very simple mock implementation which will basically `hijack` or simulate the output of a specific command in the given namespace.
That basically means it will produce the output (return value) based on your mock definition.

I think it is best explained by the below example.

## usage in short
```tcl
> tclsh

% ls
pkgIndex.tcl smock.tcl

% lappend auto_path "./"
% package require smock 1.0


% smock::init yournamespace function [function2]
% yournamespace::smock yournamespace::function arg1 arg2 {some return value}
% yournamespace::function arg1 arg2
% some return value

% yournamespace::assert { [yournamespace::function arg1 arg2] eq "some return value" }

% yournamespace::assert { [yournamespace::function arg1 arg2] eq "test assert" }
assertion failed: { [yournamespace::function arg1 arg2] eq "test assert" }

% catch { yournamespace::assert { [yournamespace::function arg1 arg2] eq "test assert" } } catch_err
1
% puts $catch_err
assertion failed: { [yournamespace::function arg1 arg2] eq "test assert" }

% yournamespace::smock_config +verbose

% yournamespace::assert { [yournamespace::function arg1 arg2] eq "some return value" }
assertion true: { [yournamespace::function arg1 arg2] eq "some return value" }

```

Also check the tests in this directory for inspiration.



## usage by example
Let's say you want to build a tcl proc to read the sync-status color of your BIG-IP setup.
When using tmsh you would type `show /cm sync-status` which will provide you with various output.

When using the equivalent `tmsh::show /cm sync-status field-fmt` command, you'll get similar output to the one below. `field-fmt` is a good option for easier parsing of the output.
```tcl
cm cmi-sync-status {
    color blue
    details.0.details bigip1.example.com: disconnected
    mode high-availability
    status Disconnected
    summary
}
```

You could create a procedure similar to this to extract the color:
```tcl
proc sync_status_color {} {
  set sync_status [tmsh::show /cm sync-status field-fmt]
  foreach line [split $sync_status "\n"] {
    if {[regexp {^\s+color\s(.+)$} $line ignore match]} {
      set extracted_color $match
    }
  }
  return $extracted_color
}
```
The procedure would output something like `green`, `yellow`, `red` or more uncommon and often missed `blue`, `grey` and `black`. It might also produce and empty return value in case something is wrong with the current system state.

To run this procedure you would need a BIG-IP, also you would probably take a decision or do something with the return value.

Here is a little (and bad) example:
```tcl
set sync_color [sync_status_color]
if { $sync_color eq "yellow" || $sync_color eq "red" } {
  puts "noo.. we can't proceed, device is not in sync!"
}
else {
  # make some changes
}
```
You probably already noticed that a lot of things can go wrong with this example, we completely missed 3 more sync states (blue, grey and black) and neither capture an empty string as a response.
So we should probably change that piece of code:
```tcl
proc whats_the_status {} {
  set sync_color [sync_status_color]
  switch -- $sync_color {
    "green" {
      return "yep ok, let's go!"
    }
    "blue" {
      return "lets wait for a little while"
    }
    default {
      return "oh nooo, something is not right!"
    }
  }
}
```

Here is some code that uses the above procs:
```tcl
if { [whats_the_status] eq "yep ok, let's do something!" } {
  return "[sync_status_color] is good! let's make some changes!"
} else {
  return "sync_status_color says: [sync_status_color], status is: [whats_the_status]"
}
```

Now the question is how can you test this? We know we need a BIG-IP, but not only that, we would also need to simulate all states we'd like to use in our code decisions!
That can get quite complicated and time consuming, which is where `smock` can save us some time and enable us to test various cases.

Let's warp the last code block in a procedure `run_example` and save everything to `example.tcl`. Then enter `tclsh`.

```tcl
# smock.tcl is one directory up, add that path and load smock 1.0
lappend auto_path "../"
package require smock 1.0

# initialize mocking for namespace 'tmsh' with a single function 'show'
smock::init tmsh show

# now let's define the output for the command we'd like to run.
tmsh::smock tmsh::show /cm sync-status field-fmt {cm cmi-sync-status {
    color blue
    details.0.details bigip1.example.com: disconnected
    mode high-availability
    status Disconnected
    summary
}}
```
try it:
```tcl
tmsh::show /cm sync-status field-fmt
cm cmi-sync-status {
    color blue
    details.0.details bigip1.example.com: disconnected
    mode high-availability
    status Disconnected
    summary
}

# great, let's run our example code using 'source', which immediately executes all code in the file - hence the run_example 'wrapping' proc!
source example.tcl

run_example
sync_status_color says: blue, status is: lets wait for a little while
```
Great, it works. Let's proceed.

```tcl
# smock also provides you with assertions, so you can properly build tests
tmsh::assert { [run_example] eq "sync_status_color says: blue, status is: lets wait for a little while" }

# nothing happend?
tmsh::assert { [run_example] eq "something we expect" }
assertion failed: { [run_example] eq "something we expect" }

# ok, so tmsh::assert { expr } it is! as run_example does not return the string "somethign we expect", it failed
```

```tcl
# what if the status would be red?
tmsh::smock tmsh::show /cm sync-status field-fmt {cm cmi-sync-status {
    color red
    details.0.details bigip2.example.com: connected
    details.1.details dg_syncfailover (Changes Pending): There is a possible change conflict between bigip2.example.com and bigip1.example.com.
    details.2.details  - Recommended action: Synchronize bigip1.example.com to group dg_syncfailover
    mode high-availability
    status Changes Pending
    summary There is a possible change conflict between bigip2.example.com and bigip1.example.com.
}}

run_example
sync_status_color says: red, status is: oh nooo, something is not right!

# ok, that was epxected so tmsh:assert could look like this to express our expectation:
tmsh::assert { [string match "*red*oh nooo*" [run_example]] }

# for more verbosity:
tmsh::smock_config +verbose

tmsh::assert { [string match "*red*oh nooo*" [run_example]] }
assertion true: { [string match "*red*oh nooo*" [run_example]] }
```

Good, that works as expected.
But what if somethig is strange is going on and there is no color?!
We'd expect to see no color in the output string but whats_the_status will capture that with it's default switch pattern, right?

```tcl
tmsh::smock tmsh::show /cm sync-status field-fmt {cm cmi-sync-status {
    color
    mode no color mode :-)
}}

# the assertion looks like this:
tmsh::assert { [run_example] eq "sync_status_color says: , status is: oh nooo, something is not right!" }
can't read "extracted_color": no such variable

# ouch? is our assertion broken?

run_example
can't read "extracted_color": no such variable

# no, it's our code!

```

Would we have found out that our code breaks if there is no color?
Ok, admitted you probably noticed the poor sync_status_color procedure before. :-)
Let's replace the poor version with a slighty better one

```tcl
proc sync_status_color {} {
  set sync_status [tmsh::show /cm sync-status field-fmt]
  foreach line [split $sync_status "\n"] {
    if {[regexp {^\s+color\s(.+)$} $line ignore match]} {
      return $match
    }
  }
}

# run our assertion:
tmsh::assert { [run_example] eq "sync_status_color says: , status is: oh nooo, something is not right!" }
assertion true: { [run_example] eq "sync_status_color says: , status is: oh nooo, something is not right!" }

# now run the example again
run_example
sync_status_color says: , status is: oh nooo, something is not right!
```

Better :-)