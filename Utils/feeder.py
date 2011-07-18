#!/usr/bin/python

# Feeds a gcode File to the SphereBot.
# 
# Write a line to the serial device and wait for an "ok" response.

# prerequisite:  http://pyserial.sourceforge.net
#   Installation on Ubuntu: sudo aptitude install python-serial




# Configure:
BAUDRATE = 57600
DEVICE = "/dev/ttyUSB1"
DEVICE = "/dev/tty.PL2303-00001004"
DEVICE = "/dev/tty.PL2303-00004006"

# End configuration



import sys
import serial
import re
from optparse import OptionParser

def y_displacement(x):
    # look into file egg-displace.dat for documentation
    return (0.00795338*x*x + 0.0734545*x + 0.15711)

lastX = 0.0

def correctDisplacement(lineIn):
    # extract x and y
    # calculate new y
    # return line with alter y

    global lastX
    foundY = False

    line = lineIn.upper()
    words = pattern.findall(line)
    for word in words:
        if word[0] == 'X':
            lastX = eval(word[1:])

        if word[0] == 'Y':
            y = eval(word[1:])
            foundY=True

    if foundY:
        y = y + y_displacement(lastX)
    else:
        return lineIn

    lineOut=""
    for word in words:
        if word[0] == 'Y':
            lineOut = lineOut + "Y{0}".format(y)
        else:
            lineOut = lineOut + word

    return lineOut

def penChange(lineIn):
    # Test Line for a Pen change request (M1)
    # If true, wait for user input

    if penChangePattern.match(lineIn):
        raw_input('Change pen ... press <Return> when finished ')
    

######################## Main #########################

parser = OptionParser(usage="usage: %prog [options] gcode-file")
parser.add_option("-e", "--egg-displace", dest="wantDisplaceCorrection",
                  action="store_true", default=False,
                  help="Correct displacement if drawn on a egg. The tip of the egg is pointing right hand.")
parser.add_option("-d", "--dont-send", dest="wantToSend",
                  action="store_false", default=True,
                  help="Dont send GCode to SphereBot")

(options, args) = parser.parse_args()



if len(args) != 1:
    parser.error("incorrect number of arguments: need one gcode file to send to the sphereBot!")


if options.wantDisplaceCorrection:
    pattern = re.compile('([(!;].*|\s+|[a-zA-Z0-9_:](?:[+-])?\d*(?:\.\d*)?|\w\#\d+|\(.*?\)|\#\d+\=(?:[+-])?\d*(?:\.\d*)?)')

penChangePattern = re.compile('^M01')

fileToFeed = args[0]
gcode = open(fileToFeed, "r")

if options.wantToSend:
    sphereBot = serial.Serial(DEVICE, BAUDRATE, timeout=30)

currentLine = 0.0
lines = gcode.readlines()
totalLines = len(lines)
for line in lines:
    currentLine = currentLine + 1

    print line, "({0:.1f}%)".format((currentLine / totalLines)*100),

    penChange(line)

    if options.wantDisplaceCorrection:
        line = correctDisplacement(line)
        print ">> ", line,


    if options.wantToSend:
        sphereBot.write(line)

        response = sphereBot.readline()
        while response[:3] != "ok:":
            print "  ", response,
            response = sphereBot.readline()

