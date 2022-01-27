#/ Controller version = 2.70.07.00
#/ Date = 9/2/2021 7:12 PM
#/ User remarks = 
#0
! - Axis 0 X1(LOWER) Axis X Home program
! - User Unit : mm
! - Modifiers : ESY

GLOBAL INT HomeFlag(64) !nHomeDone(32)
GLOBAL REAL Save(64)(5)
INT TimeOut, HomingBuffer, AXIS, Direction, Repeatability_Patch
REAL Search_Vel, Commut_current, Home_Offset

!*******************************************************************	
! PLC user variable initialize START


! AXIS 	= 0				! axis number	
! PLC user variable initialize END

!*****************************************************************************
! User Define Variable
AXIS = 0
HomingBuffer = 0
Direction = -1	! Right = 1, Left = -1

nHomeDone(AXIS)	= 0

Search_Vel = 40
Home_Offset = -10
Repeatability_Patch = 0
!*****************************************************************************

!*****************************************************************************
! Define to default
TimeOut = 1000
Commut_current = XRMS(AXIS) * 0.6
HomeFlag(AXIS) = 0
!*****************************************************************************

!*****************************************************************************
! Set parameters for motor flags
DISP "Buffer %.0f: %.0f axis home start", HomingBuffer, AXIS
DISABLE (AXIS)
TILL ^MST(AXIS).#ENABLED
WAIT 100

SAFETYGROUP(AXIS)
Save(AXIS)(0) = VEL(AXIS)
Save(AXIS)(1) = ACC(AXIS)
Save(AXIS)(2) = DEC(AXIS)
Save(AXIS)(3) = KDEC(AXIS)
Save(AXIS)(4) = JERK(AXIS)

MFLAGS(AXIS).#DEFCON = 1
MFLAGS(AXIS).#OPEN = 0
FCLEAR; WAIT 100
!*****************************************************************************
CERRI(AXIS) = 1
CERRA(AXIS) = 1
CERRV(AXIS) = 1
!*****************************************************************************
!Set Dynamic brake Off
VELBRK(AXIS) = XVEL(AXIS)
MFLAGS(AXIS).#DBRAKE = 0
!*****************************************************************************

!*****************************************************************************
! Set Motion parameters for homing
VEL(AXIS) = Search_Vel
ACC(AXIS) = 1500
DEC(AXIS) = ACC(AXIS)
JERK(AXIS) = ACC(AXIS)*15
KDEC(AXIS) = JERK(AXIS)
!*****************************************************************************

!*****************************************************************************
! Disable the default response of the hardware and software limits
FMASK(AXIS).#CPE = 1
FDEF(AXIS).#CPE = 1
FMASK(AXIS).#RL = 1
FDEF(AXIS).#RL = 1
FMASK(AXIS).#LL = 1
FDEF(AXIS).#LL = 0
FDEF(AXIS).#SRL = 0
FDEF(AXIS).#SLL = 0
WAIT 10
!*****************************************************************************

!*****************************************************************************
! Commutation for each motor

!*****************************************************************************
MFLAGS(AXIS).#OPEN=1
WAIT 10
!*****************************************************************************
! Start homing - look for limit switch
DISP "Buffer %.0f: %.0f axis home start, move to search limit", HomingBuffer, AXIS
ENABLE (AXIS)
WAIT 5000
TILL MST(AXIS).#ENABLED

MFLAGS(AXIS).#OPEN=0
WAIT 10

IF Direction = 1
	JOG (AXIS), +
	TILL FAULT(AXIS).#RL, (TimeOut * 120)
	IF ^FAULT(AXIS).#RL
		DISP "Buffer %.0f: %.0f axis search limit fault", HomingBuffer, AXIS
		GOTO Time_Out
	END
ELSEIF Direction = -1
	JOG (AXIS), -
	TILL FAULT(AXIS).#LL, (TimeOut * 120)
	IF ^FAULT(AXIS).#LL
		DISP "Buffer %.0f: %.0f axis search limit fault", HomingBuffer, AXIS
		GOTO Time_Out
	END
END
HALT (AXIS)
TILL MST(AXIS).#INPOS
WAIT 500

DISP "Buffer %.0f: %.0f axis search limit complete, move to search index", HomingBuffer, AXIS
IST(AXIS).#IND = 1
WAIT 10
IST(AXIS).#IND = 0
WAIT 10
JOG/V (AXIS),(-Direction*Search_Vel/2)
TILL IST(AXIS).#IND,(TimeOut * 40)
IF ^IST(AXIS).#IND
	DISP "Buffer %.0f: %.0f axis search index fault", HomingBuffer, AXIS
	GOTO Time_Out
END
HALT (AXIS)
TILL MST(AXIS).#INPOS
WAIT 500
IF Repeatability_Patch
	PTP/E (AXIS), IND(AXIS) + POW(2,(E_SCMUL(AXIS)-3))*EFAC(AXIS)
	TILL MST(AXIS).#INPOS
	WAIT 500
	SET FPOS(AXIS) = FPOS(AXIS) - IND(AXIS) - GETCONF(265, AXIS)
ELSE
	SET FPOS(AXIS) = FPOS(AXIS) - IND(AXIS)
END
DISP "Buffer %.0f: %.0f axis search index complete", HomingBuffer, AXIS
!*****************************************************************************

!*****************************************************************************
! Move to zero position
PTP/E AXIS, 0
TILL MST(AXIS).#INPOS
WAIT 500
!*****************************************************************************

!*****************************************************************************
! Move to offset
PTP/E AXIS, Home_Offset
TILL MST(AXIS).#INPOS
WAIT 1000
SET FPOS(AXIS) = FPOS(AXIS) - FPOS(AXIS)
!*****************************************************************************

!*****************************************************************************
! Set software limits and unmask left/right limit faults
FMASK(AXIS).#CPE = 1
FDEF(AXIS).#CPE = 1
FMASK(AXIS).#RL = 1
FDEF(AXIS).#RL = 1
FMASK(AXIS).#LL = 1
FDEF(AXIS).#LL = 1
FDEF(AXIS).#SRL = 0
FDEF(AXIS).#SLL = 0
CERRI(AXIS)=1
!*****************************************************************************

!*****************************************************************************
! Set home done flags and encoder filter
HomeFlag(AXIS) = 1
DISP "Buffer %.0f: %.0f axis home complete", HomingBuffer, AXIS
!*****************************************************************************

!*****************************************************************************
! Set home done flags and encoder filter
!CALL INPUTSHAPING
!WAIT 1000
nHomeDone(AXIS) = 1
DISP "Buffer %.0f: %.0f axis home complete", HomingBuffer, AXIS
!*****************************************************************************
!*****************************************************************************
! Restore previous motion parameters
Restore:
VEL(AXIS)=Save(AXIS)(0)
ACC(AXIS)=Save(AXIS)(1)
DEC(AXIS)=Save(AXIS)(2)
KDEC(AXIS)=Save(AXIS)(3)
JERK(AXIS) = Save(AXIS)(4)
!*****************************************************************************
STOP

!*****************************************************************************
! Time out
Time_Out:
DISP "Buffer %.0f: %.0f axis home fault, Time_Out", HomingBuffer, AXIS
HALT (AXIS)
TILL MST(AXIS).#INPOS, TimeOut
DISABLE (AXIS)
GOTO Restore
STOP
!*****************************************************************************

!*****************************************************************************
! Set software limits and unmask left/right limit faults
ON ^PST(0).#RUN
	AXIS = 0
	FMASK(AXIS).#CPE = 1
	FDEF(AXIS).#CPE = 1
	FMASK(AXIS).#RL = 1
	FMASK(AXIS).#LL = 1
	FDEF(AXIS).#RL = 1
	FDEF(AXIS).#LL = 1
	FDEF(AXIS).#SRL = 0
	FDEF(AXIS).#SLL = 0
DISP "Buffer 0: 0 axis safety enable all"
RET
!*****************************************************************************

#1
! - Axis 1 Y1(LOWER) Axis X Home program
! - User Unit : mm
! - Modifiers : ESY

GLOBAL INT HomeFlag(64) !nHomeDone(32)
GLOBAL REAL Save(64)(5)
INT TimeOut, HomingBuffer, AXIS, Direction, Repeatability_Patch
REAL Search_Vel, Commut_current, Home_Offset

!*******************************************************************	
! PLC user variable initialize START


! AXIS 	= 0				! axis number	
! PLC user variable initialize END

!*****************************************************************************
! User Define Variable
AXIS = 1
HomingBuffer = 1
Direction = -1	! Right = 1, Left = -1

nHomeDone(AXIS)	= 0

Search_Vel = 40
Home_Offset = -15
Repeatability_Patch = 0
!*****************************************************************************

!*****************************************************************************
! Define to default
TimeOut = 1000
Commut_current = XRMS(AXIS) * 0.6
HomeFlag(AXIS) = 0
!*****************************************************************************

!*****************************************************************************
! Set parameters for motor flags
DISP "Buffer %.0f: %.0f axis home start", HomingBuffer, AXIS
DISABLE (AXIS)
TILL ^MST(AXIS).#ENABLED
WAIT 100

SAFETYGROUP(AXIS)
Save(AXIS)(0) = VEL(AXIS)
Save(AXIS)(1) = ACC(AXIS)
Save(AXIS)(2) = DEC(AXIS)
Save(AXIS)(3) = KDEC(AXIS)
Save(AXIS)(4) = JERK(AXIS)

MFLAGS(AXIS).#DEFCON = 1
MFLAGS(AXIS).#OPEN = 0
FCLEAR; WAIT 100
!*****************************************************************************
CERRI(AXIS) = 1
CERRA(AXIS) = 1
CERRV(AXIS) = 1
!*****************************************************************************
!Set Dynamic brake Off
VELBRK(AXIS) = XVEL(AXIS)
MFLAGS(AXIS).#DBRAKE = 0
!*****************************************************************************

!*****************************************************************************
! Set Motion parameters for homing
VEL(AXIS) = Search_Vel
ACC(AXIS) = 1500
DEC(AXIS) = ACC(AXIS)
JERK(AXIS) = ACC(AXIS)*15
KDEC(AXIS) = JERK(AXIS)
!*****************************************************************************

!*****************************************************************************
! Disable the default response of the hardware and software limits
FMASK(AXIS).#CPE = 1
FDEF(AXIS).#CPE = 1
FMASK(AXIS).#RL = 1
FDEF(AXIS).#RL = 1
FMASK(AXIS).#LL = 1
FDEF(AXIS).#LL = 0
FDEF(AXIS).#SRL = 0
FDEF(AXIS).#SLL = 0
WAIT 10
!*****************************************************************************

!*****************************************************************************
! Commutation for each motor

!*****************************************************************************
MFLAGS(AXIS).#OPEN=1
WAIT 10
!*****************************************************************************
! Start homing - look for limit switch
DISP "Buffer %.0f: %.0f axis home start, move to search limit", HomingBuffer, AXIS
ENABLE (AXIS)
WAIT 5000
TILL MST(AXIS).#ENABLED

MFLAGS(AXIS).#OPEN=0
WAIT 10

IF Direction = 1
	JOG (AXIS), +
	TILL FAULT(AXIS).#RL, (TimeOut * 120)
	IF ^FAULT(AXIS).#RL
		DISP "Buffer %.0f: %.0f axis search limit fault", HomingBuffer, AXIS
		GOTO Time_Out
	END
ELSEIF Direction = -1
	JOG (AXIS), -
	TILL FAULT(AXIS).#LL, (TimeOut * 120)
	IF ^FAULT(AXIS).#LL
		DISP "Buffer %.0f: %.0f axis search limit fault", HomingBuffer, AXIS
		GOTO Time_Out
	END
END
HALT (AXIS)
TILL MST(AXIS).#INPOS
WAIT 500

DISP "Buffer %.0f: %.0f axis search limit complete, move to search index", HomingBuffer, AXIS
IST(AXIS).#IND = 1
WAIT 10
IST(AXIS).#IND = 0
WAIT 10
JOG/V (AXIS),(-Direction*Search_Vel/2)
TILL IST(AXIS).#IND,(TimeOut * 40)
IF ^IST(AXIS).#IND
	DISP "Buffer %.0f: %.0f axis search index fault", HomingBuffer, AXIS
	GOTO Time_Out
END
HALT (AXIS)
TILL MST(AXIS).#INPOS
WAIT 500
IF Repeatability_Patch
	PTP/E (AXIS), IND(AXIS) + POW(2,(E_SCMUL(AXIS)-3))*EFAC(AXIS)
	TILL MST(AXIS).#INPOS
	WAIT 500
	SET FPOS(AXIS) = FPOS(AXIS) - IND(AXIS) - GETCONF(265, AXIS)
ELSE
	SET FPOS(AXIS) = FPOS(AXIS) - IND(AXIS)
END
DISP "Buffer %.0f: %.0f axis search index complete", HomingBuffer, AXIS
!*****************************************************************************

!*****************************************************************************
! Move to zero position
PTP/E AXIS, 0
TILL MST(AXIS).#INPOS
WAIT 500
!*****************************************************************************

!*****************************************************************************
! Move to offset
PTP/E AXIS, Home_Offset
TILL MST(AXIS).#INPOS
WAIT 1000
SET FPOS(AXIS) = FPOS(AXIS) - FPOS(AXIS)
!*****************************************************************************

!*****************************************************************************
! Set software limits and unmask left/right limit faults
FMASK(AXIS).#CPE = 1
FDEF(AXIS).#CPE = 1
FMASK(AXIS).#RL = 1
FDEF(AXIS).#RL = 1
FMASK(AXIS).#LL = 1
FDEF(AXIS).#LL = 1
FDEF(AXIS).#SRL = 0
FDEF(AXIS).#SLL = 0
CERRI(AXIS)=1
!*****************************************************************************

!*****************************************************************************
! Set home done flags and encoder filter
HomeFlag(AXIS) = 1
DISP "Buffer %.0f: %.0f axis home complete", HomingBuffer, AXIS
!*****************************************************************************

!*****************************************************************************
! Set home done flags and encoder filter
!CALL INPUTSHAPING
!WAIT 1000
nHomeDone(AXIS) = 1
DISP "Buffer %.0f: %.0f axis home complete", HomingBuffer, AXIS
!*****************************************************************************
!*****************************************************************************
! Restore previous motion parameters
Restore:
VEL(AXIS)=Save(AXIS)(0)
ACC(AXIS)=Save(AXIS)(1)
DEC(AXIS)=Save(AXIS)(2)
KDEC(AXIS)=Save(AXIS)(3)
JERK(AXIS) = Save(AXIS)(4)
!*****************************************************************************
STOP

!*****************************************************************************
! Time out
Time_Out:
DISP "Buffer %.0f: %.0f axis home fault, Time_Out", HomingBuffer, AXIS
HALT (AXIS)
TILL MST(AXIS).#INPOS, TimeOut
DISABLE (AXIS)
GOTO Restore
STOP
!*****************************************************************************

!*****************************************************************************
! Set software limits and unmask left/right limit faults
ON ^PST(1).#RUN
	AXIS = 1
	FMASK(AXIS).#CPE = 1
	FDEF(AXIS).#CPE = 1
	FMASK(AXIS).#RL = 1
	FMASK(AXIS).#LL = 1
	FDEF(AXIS).#RL = 1
	FDEF(AXIS).#LL = 1
	FDEF(AXIS).#SRL = 0
	FDEF(AXIS).#SLL = 0
DISP "Buffer 1: 1 axis safety enable all"
RET
!*****************************************************************************

#2
! - Axis 2 Y2(LOWER) Axis X Home program
! - User Unit : mm
! - Modifiers : ESY

GLOBAL INT HomeFlag(64) !nHomeDone(32)
GLOBAL REAL Save(64)(5)
INT TimeOut, HomingBuffer, AXIS, Direction, Repeatability_Patch
REAL Search_Vel, Commut_current, Home_Offset

!*******************************************************************	
! PLC user variable initialize START


! AXIS 	= 2				! axis number	
! PLC user variable initialize END

!*****************************************************************************
! User Define Variable
AXIS = 2
HomingBuffer = 2
Direction = -1	! Right = 1, Left = -1

nHomeDone(AXIS)	= 0

Search_Vel = 40
Home_Offset = -20
Repeatability_Patch = 0
!*****************************************************************************

!*****************************************************************************
! Define to default
TimeOut = 1000
Commut_current = XRMS(AXIS) * 0.6
HomeFlag(AXIS) = 0
!*****************************************************************************

!*****************************************************************************
! Set parameters for motor flags
DISP "Buffer %.0f: %.0f axis home start", HomingBuffer, AXIS
DISABLE (AXIS)
TILL ^MST(AXIS).#ENABLED
WAIT 100

SAFETYGROUP(AXIS)
Save(AXIS)(0) = VEL(AXIS)
Save(AXIS)(1) = ACC(AXIS)
Save(AXIS)(2) = DEC(AXIS)
Save(AXIS)(3) = KDEC(AXIS)
Save(AXIS)(4) = JERK(AXIS)

MFLAGS(AXIS).#DEFCON = 1
MFLAGS(AXIS).#OPEN = 0
FCLEAR; WAIT 100
!*****************************************************************************
CERRI(AXIS) = 1
CERRA(AXIS) = 1
CERRV(AXIS) = 1
!*****************************************************************************
!Set Dynamic brake Off
VELBRK(AXIS) = XVEL(AXIS)
MFLAGS(AXIS).#DBRAKE = 0
!*****************************************************************************

!*****************************************************************************
! Set Motion parameters for homing
VEL(AXIS) = Search_Vel
ACC(AXIS) = 1500
DEC(AXIS) = ACC(AXIS)
JERK(AXIS) = ACC(AXIS)*15
KDEC(AXIS) = JERK(AXIS)
!*****************************************************************************

!*****************************************************************************
! Disable the default response of the hardware and software limits
FMASK(AXIS).#CPE = 1
FDEF(AXIS).#CPE = 1
FMASK(AXIS).#RL = 1
FDEF(AXIS).#RL = 1
FMASK(AXIS).#LL = 1
FDEF(AXIS).#LL = 0
FDEF(AXIS).#SRL = 0
FDEF(AXIS).#SLL = 0
WAIT 10
!*****************************************************************************

!*****************************************************************************
! Commutation for each motor

!*****************************************************************************
MFLAGS(AXIS).#OPEN=1
WAIT 10
!*****************************************************************************
! Start homing - look for limit switch
DISP "Buffer %.0f: %.0f axis home start, move to search limit", HomingBuffer, AXIS
ENABLE (AXIS)
WAIT 5000
TILL MST(AXIS).#ENABLED

MFLAGS(AXIS).#OPEN=0
WAIT 10

IF Direction = 1
	JOG (AXIS), +
	TILL FAULT(AXIS).#RL, (TimeOut * 120)
	IF ^FAULT(AXIS).#RL
		DISP "Buffer %.0f: %.0f axis search limit fault", HomingBuffer, AXIS
		GOTO Time_Out
	END
ELSEIF Direction = -1
	JOG (AXIS), -
	TILL FAULT(AXIS).#LL, (TimeOut * 120)
	IF ^FAULT(AXIS).#LL
		DISP "Buffer %.0f: %.0f axis search limit fault", HomingBuffer, AXIS
		GOTO Time_Out
	END
END
HALT (AXIS)
TILL MST(AXIS).#INPOS
WAIT 500

DISP "Buffer %.0f: %.0f axis search limit complete, move to search index", HomingBuffer, AXIS
IST(AXIS).#IND = 1
WAIT 10
IST(AXIS).#IND = 0
WAIT 10
JOG/V (AXIS),(-Direction*Search_Vel/2)
TILL IST(AXIS).#IND,(TimeOut * 40)
IF ^IST(AXIS).#IND
	DISP "Buffer %.0f: %.0f axis search index fault", HomingBuffer, AXIS
	GOTO Time_Out
END
HALT (AXIS)
TILL MST(AXIS).#INPOS
WAIT 500
IF Repeatability_Patch
	PTP/E (AXIS), IND(AXIS) + POW(2,(E_SCMUL(AXIS)-3))*EFAC(AXIS)
	TILL MST(AXIS).#INPOS
	WAIT 500
	SET FPOS(AXIS) = FPOS(AXIS) - IND(AXIS) - GETCONF(265, AXIS)
ELSE
	SET FPOS(AXIS) = FPOS(AXIS) - IND(AXIS)
END
DISP "Buffer %.0f: %.0f axis search index complete", HomingBuffer, AXIS
!*****************************************************************************

!*****************************************************************************
! Move to zero position
PTP/E AXIS, 0
TILL MST(AXIS).#INPOS
WAIT 500
!*****************************************************************************

!*****************************************************************************
! Move to offset
PTP/E AXIS, Home_Offset
TILL MST(AXIS).#INPOS
WAIT 1000
SET FPOS(AXIS) = FPOS(AXIS) - FPOS(AXIS)
!*****************************************************************************

!*****************************************************************************
! Set software limits and unmask left/right limit faults
FMASK(AXIS).#CPE = 1
FDEF(AXIS).#CPE = 1
FMASK(AXIS).#RL = 1
FDEF(AXIS).#RL = 1
FMASK(AXIS).#LL = 1
FDEF(AXIS).#LL = 1
FDEF(AXIS).#SRL = 0
FDEF(AXIS).#SLL = 0
CERRI(AXIS)=1
!*****************************************************************************

!*****************************************************************************
! Set home done flags and encoder filter
HomeFlag(AXIS) = 1
DISP "Buffer %.0f: %.0f axis home complete", HomingBuffer, AXIS
!*****************************************************************************

!*****************************************************************************
! Set home done flags and encoder filter
!CALL INPUTSHAPING
!WAIT 1000
nHomeDone(AXIS) = 1
DISP "Buffer %.0f: %.0f axis home complete", HomingBuffer, AXIS
!*****************************************************************************
!*****************************************************************************
! Restore previous motion parameters
Restore:
VEL(AXIS)=Save(AXIS)(0)
ACC(AXIS)=Save(AXIS)(1)
DEC(AXIS)=Save(AXIS)(2)
KDEC(AXIS)=Save(AXIS)(3)
JERK(AXIS) = Save(AXIS)(4)
!*****************************************************************************
STOP

!*****************************************************************************
! Time out
Time_Out:
DISP "Buffer %.0f: %.0f axis home fault, Time_Out", HomingBuffer, AXIS
HALT (AXIS)
TILL MST(AXIS).#INPOS, TimeOut
DISABLE (AXIS)
GOTO Restore
STOP
!*****************************************************************************

!*****************************************************************************
! Set software limits and unmask left/right limit faults
ON ^PST(2).#RUN
	AXIS = 2
	FMASK(AXIS).#CPE = 1
	FDEF(AXIS).#CPE = 1
	FMASK(AXIS).#RL = 1
	FMASK(AXIS).#LL = 1
	FDEF(AXIS).#RL = 1
	FDEF(AXIS).#LL = 1
	FDEF(AXIS).#SRL = 0
	FDEF(AXIS).#SLL = 0
DISP "Buffer 2: 2 axis safety enable all"
RET
!*****************************************************************************

#3
! - Axis 3 T(THETA) Axis X Home program
! - User Unit : mm
! - Modifiers : ESY

GLOBAL INT HomeFlag(64) !nHomeDone(32)
GLOBAL REAL Save(64)(5)
INT TimeOut, HomingBuffer, AXIS, Direction, Repeatability_Patch
REAL Search_Vel, Commut_current, Home_Offset

!*******************************************************************	
! PLC user variable initialize START


! AXIS 	= 3				! axis number	
! PLC user variable initialize END

!*****************************************************************************
! User Define Variable
AXIS = 3
HomingBuffer = 3
Direction = -1	! Right = 1, Left = -1

nHomeDone(AXIS)	= 0

Search_Vel = 5
Home_Offset = 0
Repeatability_Patch = 0
!*****************************************************************************

!*****************************************************************************
! Define to default
TimeOut = 1000
Commut_current = XRMS(AXIS) * 0.6
HomeFlag(AXIS) = 0
!*****************************************************************************

!*****************************************************************************
! Set parameters for motor flags
DISP "Buffer %.0f: %.0f axis home start", HomingBuffer, AXIS
DISABLE (AXIS)
TILL ^MST(AXIS).#ENABLED
WAIT 100

SAFETYGROUP(AXIS)
Save(AXIS)(0) = VEL(AXIS)
Save(AXIS)(1) = ACC(AXIS)
Save(AXIS)(2) = DEC(AXIS)
Save(AXIS)(3) = KDEC(AXIS)
Save(AXIS)(4) = JERK(AXIS)

MFLAGS(AXIS).#DEFCON = 1
MFLAGS(AXIS).#OPEN = 0
FCLEAR; WAIT 100
!*****************************************************************************
CERRI(AXIS) = 1
CERRA(AXIS) = 1
CERRV(AXIS) = 1
!*****************************************************************************
!Set Dynamic brake Off
VELBRK(AXIS) = XVEL(AXIS)
MFLAGS(AXIS).#DBRAKE = 0
!*****************************************************************************

!*****************************************************************************
! Set Motion parameters for homing
VEL(AXIS) = Search_Vel
ACC(AXIS) = 1500
DEC(AXIS) = ACC(AXIS)
JERK(AXIS) = ACC(AXIS)*15
KDEC(AXIS) = JERK(AXIS)
!*****************************************************************************

!*****************************************************************************
! Disable the default response of the hardware and software limits
FMASK(AXIS).#CPE = 1
FDEF(AXIS).#CPE = 1
FMASK(AXIS).#RL = 1
FDEF(AXIS).#RL = 1
FMASK(AXIS).#LL = 1
FDEF(AXIS).#LL = 0
FDEF(AXIS).#SRL = 0
FDEF(AXIS).#SLL = 0
WAIT 10
!*****************************************************************************

!*****************************************************************************
! Commutation for each motor

!*****************************************************************************

!*****************************************************************************
! Start homing - look for limit switch
DISP "Buffer %.0f: %.0f axis home start, move to search limit", HomingBuffer, AXIS
ENABLE (AXIS)
WAIT 5000
TILL MST(AXIS).#ENABLED

IF Direction = 1
	JOG (AXIS), +
	TILL FAULT(AXIS).#RL, (TimeOut * 120)
	IF ^FAULT(AXIS).#RL
		DISP "Buffer %.0f: %.0f axis search limit fault", HomingBuffer, AXIS
		GOTO Time_Out
	END
ELSEIF Direction = -1
	JOG (AXIS), -
	TILL FAULT(AXIS).#LL, (TimeOut * 120)
	IF ^FAULT(AXIS).#LL
		DISP "Buffer %.0f: %.0f axis search limit fault", HomingBuffer, AXIS
		GOTO Time_Out
	END
END
HALT (AXIS)
TILL MST(AXIS).#INPOS
WAIT 500

DISP "Buffer %.0f: %.0f axis search limit complete, move to search index", HomingBuffer, AXIS
IST(AXIS).#IND = 1
WAIT 10
IST(AXIS).#IND = 0
WAIT 10
JOG/V (AXIS),(-Direction*Search_Vel/2)
TILL IST(AXIS).#IND,(TimeOut * 40)
IF ^IST(AXIS).#IND
	DISP "Buffer %.0f: %.0f axis search index fault", HomingBuffer, AXIS
	GOTO Time_Out
END
HALT (AXIS)
TILL MST(AXIS).#INPOS
WAIT 500
IF Repeatability_Patch
	PTP/E (AXIS), IND(AXIS) + POW(2,(E_SCMUL(AXIS)-3))*EFAC(AXIS)
	TILL MST(AXIS).#INPOS
	WAIT 500
	SET FPOS(AXIS) = FPOS(AXIS) - IND(AXIS) - GETCONF(265, AXIS)
ELSE
	SET FPOS(AXIS) = FPOS(AXIS) - IND(AXIS)
END
DISP "Buffer %.0f: %.0f axis search index complete", HomingBuffer, AXIS
!*****************************************************************************

!*****************************************************************************
! Move to zero position
PTP/E AXIS, 0
TILL MST(AXIS).#INPOS
WAIT 500
!*****************************************************************************

!*****************************************************************************
! Move to offset
PTP/E AXIS, Home_Offset
TILL MST(AXIS).#INPOS
WAIT 1000
SET FPOS(AXIS) = FPOS(AXIS) - FPOS(AXIS)
!*****************************************************************************

!*****************************************************************************
! Set software limits and unmask left/right limit faults
FMASK(AXIS).#CPE = 1
FDEF(AXIS).#CPE = 1
FMASK(AXIS).#RL = 1
FDEF(AXIS).#RL = 1
FMASK(AXIS).#LL = 1
FDEF(AXIS).#LL = 1
FDEF(AXIS).#SRL = 0
FDEF(AXIS).#SLL = 0
CERRI(AXIS)=1
!*****************************************************************************

!*****************************************************************************
! Set home done flags and encoder filter
HomeFlag(AXIS) = 1
DISP "Buffer %.0f: %.0f axis home complete", HomingBuffer, AXIS
!*****************************************************************************

!*****************************************************************************
! Set home done flags and encoder filter
!CALL INPUTSHAPING
!WAIT 1000
nHomeDone(AXIS) = 1
DISP "Buffer %.0f: %.0f axis home complete", HomingBuffer, AXIS
!*****************************************************************************
!*****************************************************************************
! Restore previous motion parameters
Restore:
VEL(AXIS)=Save(AXIS)(0)
ACC(AXIS)=Save(AXIS)(1)
DEC(AXIS)=Save(AXIS)(2)
KDEC(AXIS)=Save(AXIS)(3)
JERK(AXIS) = Save(AXIS)(4)
!*****************************************************************************
STOP

!*****************************************************************************
! Time out
Time_Out:
DISP "Buffer %.0f: %.0f axis home fault, Time_Out", HomingBuffer, AXIS
HALT (AXIS)
TILL MST(AXIS).#INPOS, TimeOut
DISABLE (AXIS)
GOTO Restore
STOP
!*****************************************************************************

!*****************************************************************************
! Set software limits and unmask left/right limit faults
ON ^PST(3).#RUN
	AXIS = 3
	FMASK(AXIS).#CPE = 1
	FDEF(AXIS).#CPE = 1
	FMASK(AXIS).#RL = 1
	FMASK(AXIS).#LL = 1
	FDEF(AXIS).#RL = 1
	FDEF(AXIS).#LL = 1
	FDEF(AXIS).#SRL = 0
	FDEF(AXIS).#SLL = 0
DISP "Buffer 3: 3 axis safety enable all"
RET
!*****************************************************************************

#4
! - Axis 4 Z1 Axis X Home program
! - User Unit : mm
! - Modifiers : ESY

GLOBAL INT HomeFlag(64) !nHomeDone(32)
GLOBAL REAL Save(64)(5)
INT TimeOut, HomingBuffer, AXIS, Direction, Repeatability_Patch
REAL Search_Vel, Commut_current, Home_Offset

!*******************************************************************	
! PLC user variable initialize START


! AXIS 	= 4				! axis number	
! PLC user variable initialize END

!*****************************************************************************
! User Define Variable
AXIS = 4
HomingBuffer = 4
Direction = -1	! Right = 1, Left = -1

nHomeDone(AXIS)	= 0

Search_Vel = 3
Home_Offset = -25
Repeatability_Patch = 0
!*****************************************************************************

!*****************************************************************************
! Define to default
TimeOut = 1000
Commut_current = XRMS(AXIS) * 0.6
HomeFlag(AXIS) = 0
!*****************************************************************************

!*****************************************************************************
! Set parameters for motor flags
DISP "Buffer %.0f: %.0f axis home start", HomingBuffer, AXIS
DISABLE (AXIS)
TILL ^MST(AXIS).#ENABLED
WAIT 100

SAFETYGROUP(AXIS)
Save(AXIS)(0) = VEL(AXIS)
Save(AXIS)(1) = ACC(AXIS)
Save(AXIS)(2) = DEC(AXIS)
Save(AXIS)(3) = KDEC(AXIS)
Save(AXIS)(4) = JERK(AXIS)

MFLAGS(AXIS).#DEFCON = 1
MFLAGS(AXIS).#OPEN = 0
FCLEAR; WAIT 100
!*****************************************************************************
CERRI(AXIS) = 1
CERRA(AXIS) = 1
CERRV(AXIS) = 1
!*****************************************************************************
!Set Dynamic brake Off
VELBRK(AXIS) = XVEL(AXIS)
MFLAGS(AXIS).#DBRAKE = 0
!*****************************************************************************

!*****************************************************************************
! Set Motion parameters for homing
VEL(AXIS) = Search_Vel
ACC(AXIS) = 200
DEC(AXIS) = ACC(AXIS)
JERK(AXIS) = ACC(AXIS)*15
KDEC(AXIS) = JERK(AXIS)
!*****************************************************************************

!*****************************************************************************
! Disable the default response of the hardware and software limits
FMASK(AXIS).#CPE = 1
FDEF(AXIS).#CPE = 1
FMASK(AXIS).#RL = 1
FDEF(AXIS).#RL = 1
FMASK(AXIS).#LL = 1
FDEF(AXIS).#LL = 0
FDEF(AXIS).#SRL = 0
FDEF(AXIS).#SLL = 0
WAIT 10
!*****************************************************************************

!*****************************************************************************
! Commutation for each motor

!*****************************************************************************

!*****************************************************************************
! Start homing - look for limit switch
DISP "Buffer %.0f: %.0f axis home start, move to search limit", HomingBuffer, AXIS
ENABLE (AXIS)
WAIT 1000
TILL MST(AXIS).#ENABLED

IF Direction = 1
	JOG (AXIS), +
	TILL FAULT(AXIS).#RL, (TimeOut * 120)
	IF ^FAULT(AXIS).#RL
		DISP "Buffer %.0f: %.0f axis search limit fault", HomingBuffer, AXIS
		GOTO Time_Out
	END
ELSEIF Direction = -1
	JOG (AXIS), -
	TILL FAULT(AXIS).#LL, (TimeOut * 120)
	IF ^FAULT(AXIS).#LL
		DISP "Buffer %.0f: %.0f axis search limit fault", HomingBuffer, AXIS
		GOTO Time_Out
	END
END
HALT (AXIS)
TILL MST(AXIS).#INPOS
WAIT 500

DISP "Buffer %.0f: %.0f axis search limit complete, move to search index", HomingBuffer, AXIS
IST(AXIS).#IND = 1
WAIT 10
IST(AXIS).#IND = 0
WAIT 10
JOG/V (AXIS),(-Direction*Search_Vel/2)
TILL IST(AXIS).#IND,(TimeOut * 40)
IF ^IST(AXIS).#IND
	DISP "Buffer %.0f: %.0f axis search index fault", HomingBuffer, AXIS
	GOTO Time_Out
END
HALT (AXIS)
TILL MST(AXIS).#INPOS
WAIT 500
IF Repeatability_Patch
	PTP/E (AXIS), IND(AXIS) + POW(2,(E_SCMUL(AXIS)-3))*EFAC(AXIS)
	TILL MST(AXIS).#INPOS
	WAIT 500
	SET FPOS(AXIS) = FPOS(AXIS) - IND(AXIS) - GETCONF(265, AXIS)
ELSE
	SET FPOS(AXIS) = FPOS(AXIS) - IND(AXIS)
END
DISP "Buffer %.0f: %.0f axis search index complete", HomingBuffer, AXIS
!*****************************************************************************

!*****************************************************************************
! Move to zero position
PTP/E AXIS, 0
TILL MST(AXIS).#INPOS
WAIT 500
!*****************************************************************************

!*****************************************************************************
! Move to offset
PTP/E AXIS, Home_Offset
TILL MST(AXIS).#INPOS
WAIT 1000
SET FPOS(AXIS) = FPOS(AXIS) - FPOS(AXIS)
!*****************************************************************************
! Move to zero position
PTP/E AXIS, 0
TILL MST(AXIS).#INPOS
WAIT 500
!*****************************************************************************
! Set software limits and unmask left/right limit faults
FMASK(AXIS).#CPE = 1
FDEF(AXIS).#CPE = 1
FMASK(AXIS).#RL = 1
FDEF(AXIS).#RL = 1
FMASK(AXIS).#LL = 1
FDEF(AXIS).#LL = 1
FDEF(AXIS).#SRL = 0
FDEF(AXIS).#SLL = 0
CERRI(AXIS)=1
!*****************************************************************************

!*****************************************************************************
! Set home done flags and encoder filter
HomeFlag(AXIS) = 1
DISP "Buffer %.0f: %.0f axis home complete", HomingBuffer, AXIS
!*****************************************************************************

!*****************************************************************************
! Set home done flags and encoder filter
!CALL INPUTSHAPING
!WAIT 1000
nHomeDone(AXIS) = 1
DISP "Buffer %.0f: %.0f axis home complete", HomingBuffer, AXIS
!*****************************************************************************
!*****************************************************************************
! Restore previous motion parameters
Restore:
VEL(AXIS)=Save(AXIS)(0)
ACC(AXIS)=Save(AXIS)(1)
DEC(AXIS)=Save(AXIS)(2)
KDEC(AXIS)=Save(AXIS)(3)
JERK(AXIS) = Save(AXIS)(4)
!*****************************************************************************
STOP

!*****************************************************************************
! Time out
Time_Out:
DISP "Buffer %.0f: %.0f axis home fault, Time_Out", HomingBuffer, AXIS
HALT (AXIS)
TILL MST(AXIS).#INPOS, TimeOut
DISABLE (AXIS)
GOTO Restore
STOP
!*****************************************************************************

!*****************************************************************************
! Set software limits and unmask left/right limit faults
ON ^PST(4).#RUN
	AXIS = 4
	FMASK(AXIS).#CPE = 1
	FDEF(AXIS).#CPE = 1
	FMASK(AXIS).#RL = 1
	FMASK(AXIS).#LL = 1
	FDEF(AXIS).#RL = 1
	FDEF(AXIS).#LL = 1
	FDEF(AXIS).#SRL = 0
	FDEF(AXIS).#SLL = 0
DISP "Buffer 4: 4 axis safety enable all"
RET
!*****************************************************************************

#5
! - Axis 5 Z2 Axis X Home program
! - User Unit : mm
! - Modifiers : ESY

GLOBAL INT HomeFlag(64) !nHomeDone(32)
GLOBAL REAL Save(64)(5)
INT TimeOut, HomingBuffer, AXIS, Direction, Repeatability_Patch
REAL Search_Vel, Commut_current, Home_Offset

!*******************************************************************	
! PLC user variable initialize START


! AXIS 	= 5				! axis number	
! PLC user variable initialize END

!*****************************************************************************
! User Define Variable
AXIS = 5
HomingBuffer = 5
Direction = -1	! Right = 1, Left = -1

nHomeDone(AXIS)	= 0

Search_Vel = 5
Home_Offset = -25
Repeatability_Patch = 0
!*****************************************************************************

!*****************************************************************************
! Define to default
TimeOut = 1000
Commut_current = XRMS(AXIS) * 0.6
HomeFlag(AXIS) = 0
!*****************************************************************************

!*****************************************************************************
! Set parameters for motor flags
DISP "Buffer %.0f: %.0f axis home start", HomingBuffer, AXIS
DISABLE (AXIS)
TILL ^MST(AXIS).#ENABLED
WAIT 100

SAFETYGROUP(AXIS)
Save(AXIS)(0) = VEL(AXIS)
Save(AXIS)(1) = ACC(AXIS)
Save(AXIS)(2) = DEC(AXIS)
Save(AXIS)(3) = KDEC(AXIS)
Save(AXIS)(4) = JERK(AXIS)

MFLAGS(AXIS).#DEFCON = 1
MFLAGS(AXIS).#OPEN = 0
FCLEAR; WAIT 100
!*****************************************************************************
CERRI(AXIS) = 1
CERRA(AXIS) = 1
CERRV(AXIS) = 1
!*****************************************************************************
!Set Dynamic brake Off
VELBRK(AXIS) = XVEL(AXIS)
MFLAGS(AXIS).#DBRAKE = 0
!*****************************************************************************

!*****************************************************************************
! Set Motion parameters for homing
VEL(AXIS) = Search_Vel
ACC(AXIS) = 200
DEC(AXIS) = ACC(AXIS)
JERK(AXIS) = ACC(AXIS)*15
KDEC(AXIS) = JERK(AXIS)
!*****************************************************************************

!*****************************************************************************
! Disable the default response of the hardware and software limits
FMASK(AXIS).#CPE = 1
FDEF(AXIS).#CPE = 1
FMASK(AXIS).#RL = 1
FDEF(AXIS).#RL = 1
FMASK(AXIS).#LL = 1
FDEF(AXIS).#LL = 0
FDEF(AXIS).#SRL = 0
FDEF(AXIS).#SLL = 0
WAIT 10
!*****************************************************************************

!*****************************************************************************
! Commutation for each motor

!*****************************************************************************

!*****************************************************************************
! Start homing - look for limit switch
DISP "Buffer %.0f: %.0f axis home start, move to search limit", HomingBuffer, AXIS
ENABLE (AXIS)
WAIT 1000
TILL MST(AXIS).#ENABLED

IF Direction = 1
	JOG (AXIS), +
	TILL FAULT(AXIS).#RL, (TimeOut * 120)
	IF ^FAULT(AXIS).#RL
		DISP "Buffer %.0f: %.0f axis search limit fault", HomingBuffer, AXIS
		GOTO Time_Out
	END
ELSEIF Direction = -1
	JOG (AXIS), -
	TILL FAULT(AXIS).#LL, (TimeOut * 120)
	IF ^FAULT(AXIS).#LL
		DISP "Buffer %.0f: %.0f axis search limit fault", HomingBuffer, AXIS
		GOTO Time_Out
	END
END
HALT (AXIS)
TILL MST(AXIS).#INPOS
WAIT 500

DISP "Buffer %.0f: %.0f axis search limit complete, move to search index", HomingBuffer, AXIS
IST(AXIS).#IND = 1
WAIT 10
IST(AXIS).#IND = 0
WAIT 10
JOG/V (AXIS),(-Direction*Search_Vel/2)
TILL IST(AXIS).#IND,(TimeOut * 40)
IF ^IST(AXIS).#IND
	DISP "Buffer %.0f: %.0f axis search index fault", HomingBuffer, AXIS
	GOTO Time_Out
END
HALT (AXIS)
TILL MST(AXIS).#INPOS
WAIT 500
IF Repeatability_Patch
	PTP/E (AXIS), IND(AXIS) + POW(2,(E_SCMUL(AXIS)-3))*EFAC(AXIS)
	TILL MST(AXIS).#INPOS
	WAIT 500
	SET FPOS(AXIS) = FPOS(AXIS) - IND(AXIS) - GETCONF(265, AXIS)
ELSE
	SET FPOS(AXIS) = FPOS(AXIS) - IND(AXIS)
END
DISP "Buffer %.0f: %.0f axis search index complete", HomingBuffer, AXIS
!*****************************************************************************

!*****************************************************************************
! Move to zero position
PTP/E AXIS, 0
TILL MST(AXIS).#INPOS
WAIT 500
!*****************************************************************************

!*****************************************************************************
! Move to offset
PTP/E AXIS, Home_Offset
TILL MST(AXIS).#INPOS
WAIT 1000
SET FPOS(AXIS) = FPOS(AXIS) - FPOS(AXIS)
!*****************************************************************************
! Move to zero position
PTP/E AXIS, 0
TILL MST(AXIS).#INPOS
WAIT 500
!*****************************************************************************
! Set software limits and unmask left/right limit faults
FMASK(AXIS).#CPE = 1
FDEF(AXIS).#CPE = 1
FMASK(AXIS).#RL = 1
FDEF(AXIS).#RL = 1
FMASK(AXIS).#LL = 1
FDEF(AXIS).#LL = 1
FDEF(AXIS).#SRL = 0
FDEF(AXIS).#SLL = 0
CERRI(AXIS)=1
!*****************************************************************************

!*****************************************************************************
! Set home done flags and encoder filter
HomeFlag(AXIS) = 1
DISP "Buffer %.0f: %.0f axis home complete", HomingBuffer, AXIS
!*****************************************************************************

!*****************************************************************************
! Set home done flags and encoder filter
!CALL INPUTSHAPING
!WAIT 1000
nHomeDone(AXIS) = 1
DISP "Buffer %.0f: %.0f axis home complete", HomingBuffer, AXIS
!*****************************************************************************
!*****************************************************************************
! Restore previous motion parameters
Restore:
VEL(AXIS)=Save(AXIS)(0)
ACC(AXIS)=Save(AXIS)(1)
DEC(AXIS)=Save(AXIS)(2)
KDEC(AXIS)=Save(AXIS)(3)
JERK(AXIS) = Save(AXIS)(4)
!*****************************************************************************
STOP

!*****************************************************************************
! Time out
Time_Out:
DISP "Buffer %.0f: %.0f axis home fault, Time_Out", HomingBuffer, AXIS
HALT (AXIS)
TILL MST(AXIS).#INPOS, TimeOut
DISABLE (AXIS)
GOTO Restore
STOP
!*****************************************************************************

!*****************************************************************************
! Set software limits and unmask left/right limit faults
ON ^PST(5).#RUN
	AXIS = 5
	FMASK(AXIS).#CPE = 1
	FDEF(AXIS).#CPE = 1
	FMASK(AXIS).#RL = 1
	FMASK(AXIS).#LL = 1
	FDEF(AXIS).#RL = 1
	FDEF(AXIS).#LL = 1
	FDEF(AXIS).#SRL = 0
	FDEF(AXIS).#SLL = 0
DISP "Buffer 5: 5 axis safety enable all"
RET
!*****************************************************************************

#7
!--------------------- variable define
INT X, Y, Z, MOVE_CNT
REAL START_X, START_Y, START_Z
GLOBAL REAL X_POS_ARRAY(5), Y_POS_ARRAY(5), RD(5)
GLOBAL REAL G_SIZE(2)

GLOBAL REAL G_START_POS(3), G_START_VEL(3)
GLOBAL REAL G_END_POS(3), G_END_VEL(3), G_END_OFFSET(2)

GLOBAL REAL G_CRACK_POS(3), G_CRACK_VEL(3)
GLOBAL REAL G_RD(4)
GLOBAL REAL G_COMP_X(4), G_COMP_Y(4)
GLOBAL REAL G_XSEG_VEL, GXSEG_ACC;
GLOBAL INT G_START_SIG(5)
GLOBAL INT G_STEP_NUM

REAL TMP_END_X, TMP_END_Y;
! AXIS Number Degine
X = 0;
Y = 1;
Z = 4; ! axis is 4


MOVE_CNT = 1



ENABLE (X,Y)

! Radius Range Error Check
!IF RADIUS > (X_MOVE_DISTANCE/2) |RADIUS > (Y_MOVE_DISTANCE/2)
!	DISP"Rounding Radius must be smaller than (X/Y Length)/2"
!	STOP
!ELSE
!END
G_STEP_NUM = 0
G_START_SIG(0) = 0
!----------------------------------- STEP-1 : start pos move (x,y)
START_X = G_START_POS(0)-30
START_Y = G_START_POS(1)


VEL(X) = 50!G_START_VEL(0)
ACC(X) = 400
DEC(X) = 400
JERK(X) = 4000*20

VEL(Y) = 50!G_START_VEL(1)
ACC(Y) = 400
DEC(Y) = 400
JERK(Y) = 400*20

PTP/E (X,Y), START_X, START_Y
WAIT 1000

!----------------------------------- STEP-2 : XSeg Start 
! Segment Velocity set
 
VEL(X) = G_XSEG_VEL
ACC(X) = GXSEG_ACC
DEC(X) = GXSEG_ACC
JERK(X) = GXSEG_ACC*100

VEL(Y) = G_XSEG_VEL 
ACC(Y) = GXSEG_ACC
DEC(Y) = GXSEG_ACC
JERK(Y) = GXSEG_ACC*30

G_START_SIG(0) = 1; !------------------- LASER START
G_STEP_NUM = 100
TMP_END_X = G_COMP_X(0)+G_END_OFFSET(0);
TMP_END_Y = G_COMP_Y(0)-G_END_OFFSET(1);
 ! Segment Start
LOOP MOVE_CNT 
	XSEG/v (X,Y), START_X, START_Y, G_XSEG_VEL	! step-1 ( start pos move (x,y), xseg-velocity
		LINE(X,Y), G_COMP_X(0), G_COMP_Y(0)					! step-2
		LINE(X,Y), G_COMP_X(1), G_COMP_Y(0)					! step-3----1
		ARC2(X,Y), G_COMP_X(1), G_COMP_Y(1), ACOS(-1)/2		! step-4
		LINE(X,Y), G_COMP_X(2), G_COMP_Y(2)					! step-5----2
		ARC2(X,Y), G_COMP_X(1), G_COMP_Y(2), ACOS(-1)/2		! step-6
		LINE(X,Y), G_COMP_X(0), G_COMP_Y(3)					! step-7----3
		ARC2(X,Y), G_COMP_X(0), G_COMP_Y(2), ACOS(-1)/2		! step-8
		LINE(X,Y), G_COMP_X(3), G_COMP_Y(1)					! step-9----4
		ARC2(X,Y), G_COMP_X(0), G_COMP_Y(1), ACOS(-1)/2		! step-10
		LINE(X,Y), TMP_END_X, TMP_END_Y				! step-11 ( end pos.. move
		LINE(X,Y), G_END_POS(0), G_END_POS(1)				! step-11 ( end pos.. move
	ENDS(X,Y)
 
	TILL GSEG(X) = -1
END !loop end
 
G_START_SIG(0) = 0;!------------------- LASER END
G_STEP_NUM = 0
Wait 1000
 

STOP

#8
INT X, Y, AixsZ, MOVE_CNT
REAL START_X, START_Y, START_Z
REAL X_ORIGIN_POSITION,Y_ORIGIN_POSITION, AXIT_Z_ORG_POS
REAL X_MOVE_DISTANCE, Y_MOVE_DISTANCE
REAL AXIS_RD_X, AXIS_RD_Y, AXIS_RD_Z
GLOBAL REAL X_POS_ARRAY(5), Y_POS_ARRAY(5)
REAL RADIUS, RADIUS2
REAL XSEG_VEL
REAL START_VEL
REAL END_X, END_Y
REAL L_START_X, L_START_Y
GLOBAL INT G_START_SIG_(2)
REAL AccX, AccY
! AXIS Number Degine
X = 0;
Y = 1;
AixsZ = 4; ! axis is 4


MOVE_CNT = 1

! X,Y,T Initial Position Setting
X_ORIGIN_POSITION  = 450
Y_ORIGIN_POSITION  = 350
AXIT_Z_ORG_POS = 20

START_X = 450
START_Y = 300
START_Z = 20
! axis ready pos set
AXIS_RD_X = 0
AXIS_RD_Y = 0
AXIS_RD_Z = 0

! Rectangle Length Setting
X_MOVE_DISTANCE = 48.31
Y_MOVE_DISTANCE = 27.28
! Radius, XSEG Velocity Setting
RADIUS = 3.8; 
RADIUS2 = 3.9
XSEG_VEL = 8
START_VEL = 100

ENABLE (X,Y)

! Radius Range Error Check
IF RADIUS > (X_MOVE_DISTANCE/2) |RADIUS > (Y_MOVE_DISTANCE/2)
	DISP"Rounding Radius must be smaller than (X/Y Length)/2"
	STOP
ELSE

END

 
 
WAIT 1000

! X,Y,T XSEG Coordinate Array Setting
X_POS_ARRAY(0)	= X_ORIGIN_POSITION + RADIUS
X_POS_ARRAY(1)	= X_ORIGIN_POSITION + X_MOVE_DISTANCE - RADIUS
X_POS_ARRAY(2)	= X_ORIGIN_POSITION + X_MOVE_DISTANCE
X_POS_ARRAY(3)	= X_ORIGIN_POSITION

Y_POS_ARRAY(0)	= Y_ORIGIN_POSITION
Y_POS_ARRAY(1)	= Y_ORIGIN_POSITION + RADIUS
Y_POS_ARRAY(2)	= Y_ORIGIN_POSITION + Y_MOVE_DISTANCE - RADIUS2
Y_POS_ARRAY(3)	= Y_ORIGIN_POSITION + Y_MOVE_DISTANCE



L_START_X = START_X - 10
L_START_Y = START_Y
END_X =  X_POS_ARRAY(0)+10
END_Y = Y_POS_ARRAY(1)-10

VEL(X) = START_VEL
VEL(Y) = START_VEL
ACC(X) = (POW(START_VEL,2)/RADIUS)
ACC(Y) = ACC(X)
JERK(X) = ACC(X)*10
JERK(Y) = ACC(X)*10
PTP/E (X,Y), L_START_X, Y_POS_ARRAY(0)
WAIT 1000
! Segment Motion Start
G_START_SIG_(1) = 1;
AccX = 100000
VEL(X) = XSEG_VEL
VEL(Y) = XSEG_VEL
ACC(X) = AccX !(POW(XSEG_VEL,2)/RADIUS)
ACC(Y) = ACC(X)
DEC(X) = ACC(X)
DEC(Y) = ACC(X)
JERK(X) = AccX*10
JERK(Y) = AccX*10
!TRACK G_START_SIG(0)
 
	LOOP MOVE_CNT 
		XSEG/v (X,Y), L_START_X, Y_POS_ARRAY(0), XSEG_VEL	
			LINE(X,Y), X_POS_ARRAY(0), Y_POS_ARRAY(0)
			LINE(X,Y), X_POS_ARRAY(1), Y_POS_ARRAY(0)
			ARC2(X,Y), X_POS_ARRAY(1), Y_POS_ARRAY(1), ACOS(-1)/2
			LINE(X,Y), X_POS_ARRAY(2), Y_POS_ARRAY(2)
			ARC2(X,Y), X_POS_ARRAY(1), Y_POS_ARRAY(2), ACOS(-1)/2
			LINE(X,Y), X_POS_ARRAY(0), Y_POS_ARRAY(3)
			ARC2(X,Y), X_POS_ARRAY(0), Y_POS_ARRAY(2), ACOS(-1)/2
			LINE(X,Y), X_POS_ARRAY(3), Y_POS_ARRAY(1)
			ARC2(X,Y), X_POS_ARRAY(0), Y_POS_ARRAY(1), ACOS(-1)/2
			LINE(X,Y), END_X, END_Y
		ENDS(X,Y)
	 
		TILL GSEG(X) = -1
	END !loop end
	!PTP/E (X,Y), END_X, END_Y
 G_START_SIG_(1) = 0;
Wait 1000
!G_START_SIG(0) = 0;
!G_START_SIG(1) = 0;
STOP

#9
!BECKHOFF CONFIG

AUTOEXEC:
ECUNMAP ! Reset all previous mapping defined

!E_TYPE(0)=4
!E_TYPE(1)=4

ECIN(370, EL1889(0))! DIGITAL INPUT (24v, 16ch)
ECIN(371, EL1889(1))


ECOUT(356, EL2889(0))!  DIGITAL OUTPUT (24v, 16ch)
ECOUT(357, EL2889(1))


EL2889(0).1 = 0


STOP


!ON ^PST(11).#RUN
!START 11,1;
!DISP" RESTART BUFFER 11"
!RET

#10
GLOBAL INT G_EL_OUT(2)
AUTOEXEC:
!ECUNMAP ! Reset all previous mapping defined
EL2889(0) = G_EL_OUT(0)
EL2889(1) = G_EL_OUT(1)

stop

#A
!axisdef X=0,Y=1,Z=2,T=3,A=4,B=5,C=6,D=7
!axisdef x=0,y=1,z=2,t=3,a=4,b=5,c=6,d=7
global int I(100),I0,I1,I2,I3,I4,I5,I6,I7,I8,I9,I90,I91,I92,I93,I94,I95,I96,I97,I98,I99
global real V(100),V0,V1,V2,V3,V4,V5,V6,V7,V8,V9,V90,V91,V92,V93,V94,V95,V96,V97,V98,V99


AXISDEF LOWER_X = 0
AXISDEF UPPER_Y1 = 1
AXISDEF UPPER_Y2 = 2
AXISDEF THET = 3
AXISDEF Z1 = 4
AXISDEF Z2 = 5


GLOBAL INT nHomeDone(64), EL1889(2),EL2889(2)



