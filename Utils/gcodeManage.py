#!/usr/bin/python

# Some usfull gcode info - manipulation functions
# 

# prerequisite:  http://pyserial.sourceforge.net
#   Installation on Ubuntu: sudo aptitude install python-serial




# Configure:

# End configuration



import sys
import re
import serial

class Range:
    def __init__(self):
        self.min = 999999
        self.max = -999999

    def __str__(self):
        return 'Range({self.min}, {self.max})'.format(self=self)

    def adjust(self, value):
        """
        If value is out of range expand range
        """
        if value > self.max:
            self.max = value
        if value < self.min:
            self.min = value


fileToFeed = sys.argv[1]
gcode = open(fileToFeed, "r")


xRange = Range()
yRange = Range()
pattern = re.compile('([(!;].*|\s+|[a-zA-Z0-9_:](?:[+-])?\d*(?:\.\d*)?|\w\#\d+|\(.*?\)|\#\d+\=(?:[+-])?\d*(?:\.\d*)?)')

lines = gcode.readlines()
for line in lines:
    line = line.lower()
    words = pattern.findall(line)
    for word in words:
        if word[0] == 'x':
            x = eval(word[1:])
            xRange.adjust(x)
        if word[0] == 'y':
            y = eval(word[1:])
            yRange.adjust(y)
    
print "x=", xRange, " y=",yRange
