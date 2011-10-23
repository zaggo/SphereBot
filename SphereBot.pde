/*
 * Copyright 2011 by Eberhard Rensch <http://pleasantsoftware.com/developer/3d>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>
 *
 * Part of this code is based on/inspired by the Helium Frog Delta Robot Firmware
 * by Martin Price <http://www.HeliumFrog.com>
 *
 * !!!!!!!!
 * This sketch needs the following non-standard libraries (install them in the Arduino library directory):
 * SoftwareServo: http://www.arduino.cc/playground/ComponentLib/Servo
 * TimerOne: http://www.arduino.cc/playground/Code/Timer1
 * !!!!!!!!
 */

#include <TimerOne.h>
#include <SoftwareServo.h>
#include "StepperModel.h"


#define TIMER_DELAY 64

/*
 * PINS
 */
 
#define XAXIS_DIR_PIN 7
#define XAXIS_STEP_PIN 8
#define XAXIS_ENABLE_PIN 6
#define XAXIS_ENDSTOP_PIN 3

#define YAXIS_DIR_PIN 10
#define YAXIS_STEP_PIN 11
#define YAXIS_ENABLE_PIN 9
#define YAXIS_ENDSTOP_PIN -1 // <0 0> No Endstop!

#define SERVO_PIN 2

/*
 * Other Configuration
 */

#define DEFAULT_PEN_UP_POSITION 50
#define XAXIS_MIN_STEPCOUNT -467
#define XAXIS_MAX_STEPCOUNT 467
#define DEFAULT_ZOOM_FACTOR 1. // With a Zoom-Faktor of .65, I can print gcode for Makerbot Unicorn without changes. 
                               // The zoom factor can be also manipulated by the propretiary code M402


/* --------- */

StepperModel xAxisStepper(XAXIS_DIR_PIN, XAXIS_STEP_PIN, XAXIS_ENABLE_PIN, XAXIS_ENDSTOP_PIN,
        XAXIS_MIN_STEPCOUNT, XAXIS_MAX_STEPCOUNT, 200.0, 16);
StepperModel rotationStepper(YAXIS_DIR_PIN, YAXIS_STEP_PIN, YAXIS_ENABLE_PIN, YAXIS_ENDSTOP_PIN,
        0, 0, 200.0, 16);

SoftwareServo servo;
boolean servoEnabled=true;

long intervals=0;
volatile long intervals_remaining=0;
volatile boolean isRunning=false;

// comm variables
const int MAX_CMD_SIZE = 256;
char buffer[MAX_CMD_SIZE]; // buffer for serial commands
char serial_char; // value for each byte read in from serial comms
int serial_count = 0; // current length of command
char *strchr_pointer; // just a pointer to find chars in the cmd string like X, Y, Z, E, etc
boolean comment_mode = false;
// end comm variables

// GCode States
double currentOffsetX = 0.;
double currentOffsetY = 0.;
boolean absoluteMode = true;
double feedrate = 2000.; // mm/minute
double zoom = DEFAULT_ZOOM_FACTOR;

const double maxFeedrate = 6000.;
// ------

void setup()
{
    Serial.begin(115200);

    clear_buffer();

    servo.attach(SERVO_PIN);
    servo.write(DEFAULT_PEN_UP_POSITION);
    
    if(servoEnabled)
    {
      for(int i=0;i<100;i++)
      {
          SoftwareServo::refresh();
          delay(4);
      }
    }
    
    //--- Activate the PWM timer
    Timer1.initialize(TIMER_DELAY); // Timer for updating pwm pins
    Timer1.attachInterrupt(doInterrupt);
  
#ifdef AUTO_HOMING
    xAxisStepper.autoHoming();
    xAxisStepper.setTargetPosition(0.);
    commitSteppers(maxFeedrate);
    delay(2000);
    xAxisStepper.enableStepper(false);
#endif
}

void loop() // input loop, looks for manual input and then checks to see if and serial commands are coming in
{
  get_command(); // check for Gcodes
  if(servoEnabled)
    SoftwareServo::refresh();
}

//--- Interrupt-Routine: Move the steppers
void doInterrupt()
{
  if(isRunning)
  {
      if (intervals_remaining-- == 0)
	 isRunning = false;
      else
      {
          rotationStepper.doStep(intervals);
          xAxisStepper.doStep(intervals);
      }
  }
}

void commitSteppers(double speedrate)
{
  long deltaStepsX = xAxisStepper.delta;
  if(deltaStepsX != 0L)
  {
    xAxisStepper.enableStepper(true);
  }

  long deltaStepsY = rotationStepper.delta;
  if(deltaStepsY != 0L)
  {
    rotationStepper.enableStepper(true);
  }
  long masterSteps = (deltaStepsX>deltaStepsY)?deltaStepsX:deltaStepsY;

  double deltaDistanceX = xAxisStepper.targetPosition-xAxisStepper.getCurrentPosition();
  double deltaDistanceY = rotationStepper.targetPosition-rotationStepper.getCurrentPosition();
  		
  // how long is our line length?
  double distance = sqrt(deltaDistanceX*deltaDistanceX+deltaDistanceY*deltaDistanceY);
		  	  
  // compute number of intervals for this move
  double sub1 = (60000.* distance / speedrate);
  double sub2 = sub1 * 1000.;
  intervals = (long)sub2/TIMER_DELAY;

  intervals_remaining = intervals;
  const long negative_half_interval = -intervals / 2;
  
  rotationStepper.counter = negative_half_interval;
  xAxisStepper.counter = negative_half_interval;

//  Serial.print("Speedrate:");
//  Serial.print(speedrate, 6);
//  Serial.print(" dX:");
//  Serial.print(deltaStepsX);
//  Serial.print(" dY:");
//  Serial.print(deltaStepsY);
//  Serial.print(" masterSteps:");
//  Serial.print(masterSteps);
//  Serial.print(" dDistX:");
//  Serial.print(deltaDistanceX);
//  Serial.print(" dDistY:");	
//  Serial.print(deltaDistanceY);
//  Serial.print(" distance:");
//  Serial.print(distance);
//  Serial.print(" sub1:");
//  Serial.print(sub1, 6);
//  Serial.print(" sub2:");
//  Serial.print(sub2, 6);
//  Serial.print(" intervals:");
//  Serial.print(intervals);
//  Serial.print(" negative_half_interval:");
//  Serial.println(negative_half_interval);
//  Serial.print("Y currentStepCount:");
//  Serial.print(rotationStepper.currentStepcount);
//  Serial.print(" targetStepCount:");
//  Serial.println(rotationStepper.targetStepcount);

  isRunning=true;
}

void get_command() // gets commands from serial connection and then calls up subsequent functions to deal with them
{
  if (!isRunning && Serial.available() > 0) // each time we see something
  {
    serial_char = Serial.read(); // read individual byte from serial connection
    
    if (serial_char == '\n' || serial_char == '\r') // end of a command character
    { 
      buffer[serial_count]=0;
      process_commands(buffer, serial_count);
      clear_buffer();
      comment_mode = false; // reset comment mode before each new command is processed
    }
    else // not end of command
    {
      if (serial_char == ';' || serial_char == '(') // semicolon signifies start of comment
      {
        comment_mode = true;
      }
      
      if (comment_mode != true) // ignore if a comment has started
      {
        buffer[serial_count] = serial_char; // add byte to buffer string
        serial_count++;
        if (serial_count > MAX_CMD_SIZE) // overflow, dump and restart
        {
          clear_buffer();
          Serial.flush();
        }
      }
    }
  }
}

void clear_buffer() // empties command buffer from serial connection
{
  serial_count = 0; // reset buffer placement
}

boolean getValue(char key, char command[], double* value)
{  
  // find key parameter
  strchr_pointer = strchr(buffer, key);
  if (strchr_pointer != NULL) // We found a key value
  {
    *value = (double)strtod(&command[strchr_pointer - command + 1], NULL);
    return true;  
  }
  return false;
}

void process_commands(char command[], int command_length) // deals with standardized input from serial connection
{
  if (command_length>0 && command[0] == 'G') // G code
  {
    int codenum = (int)strtod(&command[1], NULL);
    
    double tempX = xAxisStepper.getCurrentPosition();
    double tempY = rotationStepper.getCurrentPosition();
    
    double xVal;
    boolean hasXVal = getValue('X', command, &xVal);
    if(hasXVal) xVal*=zoom;
    double yVal;
    boolean hasYVal = getValue('Y', command, &yVal);
    if(hasYVal) yVal*=zoom;
    double iVal;
    boolean hasIVal = getValue('I', command, &iVal);
    if(hasIVal) iVal*=zoom;
    double jVal;
    boolean hasJVal = getValue('J', command, &jVal);
    if(hasJVal) jVal*=zoom;
    double rVal;
    boolean hasRVal = getValue('R', command, &rVal);
    if(hasRVal) rVal*=zoom;
    double pVal;
    boolean hasPVal = getValue('P', command, &pVal);
    
    getValue('F', command, &feedrate);

    xVal+=currentOffsetX;
    yVal+=currentOffsetY;
    
    if(absoluteMode)
    {
      if(hasXVal)
        tempX=xVal;
      if(hasYVal)
        tempY=yVal;
    }
    else
    {
      if(hasXVal)
        tempX+=xVal;
      if(hasYVal)
        tempY+=yVal;
    }
    
    switch(codenum)
    {
      case 0: // G0, Rapid positioning
        xAxisStepper.setTargetPosition(tempX);
        rotationStepper.setTargetPosition(tempY);
        commitSteppers(maxFeedrate);
        break;
      case 1: // G1, linear interpolation at specified speed
        xAxisStepper.setTargetPosition(tempX);
        rotationStepper.setTargetPosition(tempY);
        commitSteppers(feedrate);
        break;
      case 2: // G2, Clockwise arc
      case 3: // G3, Counterclockwise arc
        if(hasIVal && hasJVal)
        {
            double centerX=xAxisStepper.getCurrentPosition()+iVal;
            double centerY=rotationStepper.getCurrentPosition()+jVal;
            drawArc(centerX, centerY, tempX, tempY, (codenum==2));
        }
        else if(hasRVal)
        {
          //drawRadius(tempX, tempY, rVal, (codenum==2));
        }
        break;
      case 4: // G4, Delay P ms
        if(hasPVal)
        {
           unsigned long endDelay = millis()+ (unsigned long)pVal;
           while(millis()<endDelay)
           {
              delay(1);
              if(servoEnabled)
                SoftwareServo::refresh();
           }
        }
        break;
      case 90: // G90, Absolute Positioning
        absoluteMode = true;
        break;
      case 91: // G91, Incremental Positioning
        absoluteMode = false;
        break;
    }
  }  
  else if (command_length>0 && command[0] == 'M') // M code
  {
    double value;
    int codenum = (int)strtod(&command[1], NULL);
    switch(codenum)
    {   
      case 18: // Disable Drives
        xAxisStepper.resetStepper();
        rotationStepper.resetStepper();
        break;

      case 300: // Servo Position
        if(getValue('S', command, &value))
        {
          servoEnabled=true;
          if(value<0.)
            value=0.;
          else if(value>180.)
          {
            value=DEFAULT_PEN_UP_POSITION;
            servo.write((int)value);
            for(int i=0;i<100;i++)
            {
                SoftwareServo::refresh();
                delay(4);
            }           
            servoEnabled=false;
          }
          servo.write((int)value);
        }
        break;
        
      case 400: // Propretary: Reset X-Axis-Stepper settings to new object diameter
        if(getValue('S', command, &value))
        {
          xAxisStepper.resetSteppersForObjectDiameter(value);
          xAxisStepper.setTargetPosition(0.);
          commitSteppers(maxFeedrate);
          delay(2000);
          xAxisStepper.enableStepper(false);
        }
        break;
        
      case 401: // Propretary: Reset Y-Axis-Stepper settings to new object diameter
        if(getValue('S', command, &value))
        {
          rotationStepper.resetSteppersForObjectDiameter(value);
          rotationStepper.setTargetPosition(0.);
          commitSteppers(maxFeedrate);
          delay(2000);
          rotationStepper.enableStepper(false);
        }
        break;
        
       case 402: // Propretary: Set global zoom factor
        if(getValue('S', command, &value))
        {
          zoom = value;
        }

    }
  }  

  // done processing commands
  if (Serial.available() <= 0) {
    Serial.print("ok:");
    Serial.println(command);
  }
}

/* This code was ported from the Makerbot/ReplicatorG java sources */
void drawArc(double centerX, double centerY, double endpointX, double endpointY, boolean clockwise) 
{
  // angle variables.
  double angleA;
  double angleB;
  double angle;
  double radius;
  double length;

  // delta variables.
  double aX;
  double aY;
  double bX;
  double bY;

  // figure out our deltas
  double currentX = xAxisStepper.getCurrentPosition();
  double currentY = rotationStepper.getCurrentPosition();
  aX = currentX - centerX;
  aY = currentY - centerY;
  bX = endpointX - centerX;
  bY = endpointY - centerY;

  // Clockwise
  if (clockwise) {
    angleA = atan2(bY, bX);
    angleB = atan2(aY, aX);
  }
  // Counterclockwise
  else {
    angleA = atan2(aY, aX);
    angleB = atan2(bY, bX);
  }

  // Make sure angleB is always greater than angleA
  // and if not add 2PI so that it is (this also takes
  // care of the special case of angleA == angleB,
  // ie we want a complete circle)
  if (angleB <= angleA)
    angleB += 2. * M_PI;
  angle = angleB - angleA;
		
  // calculate a couple useful things.
  radius = sqrt(aX * aX + aY * aY);
  length = radius * angle;

  // for doing the actual move.
  int steps;
  int s;
  int step;

  // Maximum of either 2.4 times the angle in radians
  // or the length of the curve divided by the curve section constant
  steps = (int)ceil(max(angle * 2.4, length));

  // this is the real draw action.
  double newPointX = 0.;
  double newPointY = 0.;
  
  for (s = 1; s <= steps; s++) {
    // Forwards for CCW, backwards for CW
    if (!clockwise)
	step = s;
    else
	step = steps - s;

    // calculate our waypoint.
    newPointX = centerX + radius * cos(angleA + angle * ((double) step / steps));
    newPointY= centerY + radius	* sin(angleA + angle * ((double) step / steps));

    // start the move
    xAxisStepper.setTargetPosition(newPointX);
    rotationStepper.setTargetPosition(newPointY);
    commitSteppers(feedrate);
    
    while(isRunning)
    {
      delay(1);
      if(servoEnabled)
        SoftwareServo::refresh();
    };
  }
}

/* Make life easier for vim users */
/* vim:set filetype=cpp: */
