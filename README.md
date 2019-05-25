# tcl-smock
[![Travis Build Status](https://img.shields.io/travis/com/simonkowallik/tcl-smock/master.svg?label=travis%20build)](https://travis-ci.com/simonkowallik/tcl-smock)
[![Releases](https://img.shields.io/github/release/simonkowallik/tcl-smock.svg)](https://github.com/simonkowallik/tcl-smock/releases)
[![Commits since latest release](https://img.shields.io/github/commits-since/simonkowallik/tcl-smock/latest.svg)](https://github.com/simonkowallik/tcl-smock/commits)
[![Latest Release](https://img.shields.io/github/release-date/simonkowallik/tcl-smock.svg?color=blue)](https://github.com/simonkowallik/tcl-smock/releases/latest)

## smock, a simple mock package
I build smock for F5 iApp and iCall script function mocking for basic unit tests.

When you build your own iApps or iCall scripts you often depend on commands in the tmsh:: or iapp:: namespace.
These again use state and information from the underlying BIG-IP system and it's configuration state.
Therefore even simple testing can get quite complicated and time consuming, especially with future code updates.

The idea with this mocking implementation is to capture this state when you first build and test your code for later re-tests. In addition you can easily change the captured state - it's text in the end - and therefore test unexpected behaviour.

`smock` is a very simple mock implementation which will basically `hijack` or simulate the output of a specific command in the given namespace, which means it will produce the output (return value) based on your mock definition.

## usage in short
```tcl
> tclsh

% ls
pkgIndex.tcl smock.tcl

# load package from current working directory
% lappend auto_path "./"
% package require smock 2.0

# init yournamespace with proc 'function'
% smock::init yournamespace function [function2]

# mock yournamespace::function with the given parameters.
# The last argument is always the return value of the given command
% yournamespace::smock yournamespace::function arg1 arg2 {some return value}

# test
% yournamespace::function arg1 arg2
% some return value

# assert
% smock::assert { true }
% smock::assert { false }
assertion failed: { false }

% smock::assert { [yournamespace::function arg1 arg2] eq "some return value" }
% smock::assert { [yournamespace::function arg1 arg2] eq "test assert" }
assertion failed: { [yournamespace::function arg1 arg2] eq "test assert" }

% catch { smock::assert { [yournamespace::function arg1 arg2] eq "test assert" } } catch_err
1
% puts $catch_err
assertion failed: { [yournamespace::function arg1 arg2] eq "test assert" }

# enable successful assert output
% smock::config +verbose

% smock::assert { [yournamespace::function arg1 arg2] eq "some return value" }
assertion true: { [yournamespace::function arg1 arg2] eq "some return value" }
% smock::assert { true }
assertion true: { true }

```

Also check the tests directory for inspiration.


## usage by example
Let's say you want to build a procedure to read the sync-status color of your BIG-IP setup.
When using tmsh you would type `show /cm sync-status` which will provide you with the color alongside other useful information.

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
The procedure would output something like `green`, `yellow`, `red` or more uncommon and often missed `blue`, `grey` and `black`.
To run this procedure you would need a BIG-IP, also you would probably take a decision or do something with the return value.

Here is a little example:
```tcl
set sync_color [sync_status_color]
if { $sync_color eq "yellow" || $sync_color eq "red" } {
  puts "noo.. we can't proceed, device is not in sync!"
}
else {
  # make some changes
}
```
You probably already noticed that a lot can go wrong with this example, we completely missed 3 sync states (blue, grey and black) and neither take care of any unepxeced response.
So we should probably change the code to:
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

Here is some code that uses the above procedure to take a decision and do something with it:
```tcl
if { [whats_the_status] eq "yep ok, let's do something!" } {
  return "[sync_status_color] is good! let's make some changes!"
} else {
  return "sync_status_color says: [sync_status_color], status is: [whats_the_status]"
}
```

Now the question is how can we test this? We know we need a BIG-IP, but not only that, we would also need to simulate all states we'd like to use in our code decisions!
That can get quite complicated and time consuming, which is where `smock` can save us some time and enable us to test various cases.

Let's warp the last code block in a procedure `run_example` and save everything to `example.tcl`. Then enter `tclsh`.

```tcl
# smock.tcl is one directory up, add that path and load smock 2.0
lappend auto_path "../"
package require smock 2.0

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

Let's try it:
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
Great, it works. Let's proceed with assertions.

```tcl
# smock also provides you with assertions, so you can properly build tests
smock::assert { [run_example] eq "sync_status_color says: blue, status is: lets wait for a little while" }

# nothing happend?
smock::assert { [run_example] eq "something we expect" }
assertion failed: { [run_example] eq "something we expect" }

# ok, so smock::assert { expr } it is! as run_example does not return the string "something we expect", it failed
```
Now let's test additional sync status colors (sync states):
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
smock::assert { [string match "*red*oh nooo*" [run_example]] }

# for more verbosity:
smock::config +verbose

smock::assert { [string match "*red*oh nooo*" [run_example]] }
assertion true: { [string match "*red*oh nooo*" [run_example]] }
```

Good, that works as expected.
But what if somethig is strange is going on and there is no color?!
We'd expect to see no color in the output string but `whats_the_status` will capture that with it's default switch pattern, right?

```tcl
tmsh::smock tmsh::show /cm sync-status field-fmt {cm cmi-sync-status {
    color
    mode no color mode :-)
}}

# our assertion looks like this:
smock::assert { [run_example] eq "sync_status_color says: , status is: oh nooo, something is not right!" }
can't read "extracted_color": no such variable

# ouch? is our assertion broken?

run_example
can't read "extracted_color": no such variable

# no, it's our code!

```

Ok, admitted you probably noticed the poor `sync_status_color` procedure before. :-)
But would we have found that issue in manual testing? Likely not as it is very unlikely to occur, except this one time in production.
Let's replace the poor version with a slighty better one:

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
smock::assert { [run_example] eq "sync_status_color says: , status is: oh nooo, something is not right!" }
assertion true: { [run_example] eq "sync_status_color says: , status is: oh nooo, something is not right!" }

# now run the example again
run_example
sync_status_color says: , status is: oh nooo, something is not right!
```

Better :-)
