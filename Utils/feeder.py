#!/usr/bin/python

# Feeds a gcode File to the SphereBot.
# 
# Write a line to the serial device and wait for an "ok" response.

# prerequisite:  http://pyserial.sourceforge.net
#   Installation on Ubuntu: sudo aptitude install python-serial




# Configure:
BAUDRATE = 57600
DEVICE = "/dev/ttyUSB1"
DEVICE = "/dev/tty.PL2303-00004006"
DEVICE = "/dev/tty.PL2303-00001004"

# End configuration



import sys
import serial


fileToFeed = sys.argv[1]
gcode = open(fileToFeed, "r")
sphereBot = serial.Serial(DEVICE, BAUDRATE, timeout=30)

currentLine = 0.0
lines = gcode.readlines()
totalLines = len(lines)
for line in lines:
    currentLine = currentLine + 1
    print line, "({0:.1f}%)".format((currentLine / totalLines)*100),
    sphereBot.write(line)

    response = sphereBot.readline()
    while response[:3] != "ok:":
        print "  ", response,
        response = sphereBot.readline()


gcode.close()
sphereBot.close()

