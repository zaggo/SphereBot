#!/bin/sh
## \
exec tclsh "$0" ${1+"$@"}

# Feeds a gcode File to the SphereBot.
# 
# Write a line to the serial device and wait for an "ok" response.
#
# Configure:

set BAUDRATE 57600
set DEVICE /dev/ttyUSB1


# End configuration


set fileToFeed [lindex $argv 0]


set fdIn [open $fileToFeed]
set fdOut [open $DEVICE r+]
fconfigure $fdOut -mode $BAUDRATE,n,8,1


while {[gets $fdIn line] >= 0} {
    puts $line
    puts $fdOut $line
    flush $fdOut
    while {[gets $fdOut answer]} {
        puts "\t$answer"
        if {[regexp {^ok:} $answer]} {
            break
        }
    }
}

close $fdIn
close $fdOut
