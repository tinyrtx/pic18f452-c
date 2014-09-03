        LIST
;*******************************************************************************
; tinyRTX Filename: srtx.asm (System Real Time eXecutive)
;
; Copyright 2014 Sycamore Software, Inc.  ** www.tinyRTX.com **
; Distributed under the terms of the GNU Lesser General Purpose License v3
;
; This file is part of tinyRTX. tinyRTX is free software: you can redistribute
; it and/or modify it under the terms of the GNU Lesser General Public License
; version 3 as published by the Free Software Foundation.
;
; tinyRTX is distributed in the hope that it will be useful, but WITHOUT ANY
; WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
; A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
; details.
;
; You should have received a copy of the GNU Lesser General Public License
; (filename copying.lesser.txt) and the GNU General Public License (filename
; copying.txt) along with tinyRTX.  If not, see <http://www.gnu.org/licenses/>.
;
; Revision history:
;   16Oct03 SHiggins@tinyRTX.com	Created from scratch.
;   30Jul14 SHiggins@tinyRTX.com    Reduce from 4 tasks to 3 to reduce stack needs.
;   12Aug14 SHiggins@tinyRTX.com    Converted from PIC16877 to PIC18F452.
;   15Aug14 SHiggins@tinyRTX.com    Added SRTX_ComputedBraRCall and SRTX_ComputedGotoCall.
;   02Sep14  SHiggins@tinyRTX.com  	Remove AD_COMPLETE_TASK and I2C_COMPLETE_TASK options.
;									Both now have some interrupt handling and a task.
;
;*******************************************************************************
;
        errorlevel -302	
	    #include    <p18f452.inc>
	    #include    <srtxuser.inc>
	    #include    <strc.inc>
	    #include    <susr.inc>
;
;*******************************************************************************
;
; SRTX service variables.
;
SRTX_UdataSec UDATA
;
; Task timer counters track remaining SRTX-timer events before each task is scheduled.
;
SRTX_Timer_Cnt_Task1    res     1
SRTX_Timer_Cnt_Task2    res     1
SRTX_Timer_Cnt_Task3    res     1
;
; Task schedule counters track pending task schedule counts.
;   When any count > 0 then task has been scheduled but not completed.
;   When any count > 1 then task has been scheduled at least twice before compleleting,
;     therefor technically this is a task overflow.  However, this may be an acceptable
;     occasional condition in high-throughput sheduling, and SRTX will recover gracefully.
;
SRTX_Sched_Cnt_Task1    res     1
SRTX_Sched_Cnt_Task2    res     1
SRTX_Sched_Cnt_Task3    res     1
	GLOBAL  SRTX_Sched_Cnt_TaskADC
SRTX_Sched_Cnt_TaskADC  res     1	; Needs to be GLOBAL because other routines can schedule.
    GLOBAL  SRTX_Sched_Cnt_TaskI2C
SRTX_Sched_Cnt_TaskI2C  res     1	; Needs to be GLOBAL because other routines can schedule.
;
; Temp variable for SRTX_ComputedBraRCall and SRTX_ComputedGotoCall, because rotates
;  can only be done through a memory location.
;
SRTX_TempRotate			res		1
;
;*******************************************************************************
;
; SRTX Services.
;
SRTX_CodeSec  CODE	
;
;*******************************************************************************
;
; tinyRTX System Real Time eXecutive  Initialization
;
; First, perform any application time-critical initialization which simply must be
; done as soon as power is applied or reset occurs.  Application should not initialize
; any hardware to generate interrupts during Phase A.  
;   Call USER_POR_InitPhaseA.
;
; Second, perform SRTX non-time critical initialization:
;   Initialize SRTX counters.
;   Call SRTX_Scheduler to initially schedule all timebase tasks.
;
; Third, perform any application non-time critical initialization which may
; generate interrupts.  Application should do anything necessary before initial
; execution of timebased tasks.
;   Call USER_POR_InitPhaseB.
;
; Fourth, start timebase timer and begin SRTX background loop.  This will immediately
; dispatch all timebase tasks which have been scheduled with an initial load value of 1.
;   Call USER_Timebase.
;   Goto SRTX_Dispatcher.
;
;*******************************************************************************
;
        GLOBAL  SRTX_Init
SRTX_Init
;
        call    SUSR_POR_PhaseA         ; Application time-critical init, no interrupts.
        call    STRC_Init               ; Trace buffer init.
;
        banksel	SRTX_Timer_Cnt_Task1    ; Init all the task timebase counters.
        movlw   SRTX_CNT_INIT_TASK1
        movwf   SRTX_Timer_Cnt_Task1
        movlw   SRTX_CNT_INIT_TASK2
        movwf   SRTX_Timer_Cnt_Task2
        movlw   SRTX_CNT_INIT_TASK3
        movwf   SRTX_Timer_Cnt_Task3
;   
        clrf    SRTX_Sched_Cnt_Task1    ; Clear all the task schedule counters.
        clrf    SRTX_Sched_Cnt_Task2
        clrf    SRTX_Sched_Cnt_Task3
        clrf    SRTX_Sched_Cnt_TaskADC
        clrf    SRTX_Sched_Cnt_TaskI2C
;
        rcall   SRTX_Scheduler          ; Schedule all timebase tasks.
        call    SUSR_POR_PhaseB         ; Application non-time critical init.
        call    SUSR_Timebase           ; Set up initial timebase interrupt.
        bra     SRTX_Dispatcher         ; SRTX background loops dispatches tasks.
;
;*******************************************************************************
;
; SRTX Scheduler:
;   Arrives here with each timebase event.
;   Decrements each task timer.
;   If task timer has expired, reloads timer and schedules task by incrementing
;		task schedule count (no rolloever, max count at 0xFF).
;
;*******************************************************************************
;
        GLOBAL  SRTX_Scheduler
SRTX_Scheduler
;
		banksel	SRTX_Timer_Cnt_Task1
        decfsz  SRTX_Timer_Cnt_Task1, F     ; Decrement task timer count.
        bra     SRTX_Scheduler_Check2       ; Task timer count not expired.
        movlw   SRTX_CNT_RELOAD_TASK1       ; Task timer expired, reload count.
        movwf   SRTX_Timer_Cnt_Task1
        incfsz  SRTX_Sched_Cnt_Task1, F     ; Increment task schedule count.
        bra     SRTX_Scheduler_Check2       ; Task schedule count did not rollover.
        decf    SRTX_Sched_Cnt_Task1, F     ; Max task schedule count.
;
SRTX_Scheduler_Check2
;
        decfsz  SRTX_Timer_Cnt_Task2, F     ; Decrement task timer count.
        bra     SRTX_Scheduler_Check3       ; Task timer count not expired.
        movlw   SRTX_CNT_RELOAD_TASK2       ; Task timer expired, reload count.
        movwf   SRTX_Timer_Cnt_Task2
        incfsz  SRTX_Sched_Cnt_Task2, F     ; Increment task schedule count.
        bra     SRTX_Scheduler_Check3       ; Task schedule count did not rollover.
        decf    SRTX_Sched_Cnt_Task2, F     ; Max task schedule count.
;
SRTX_Scheduler_Check3
;
        decfsz  SRTX_Timer_Cnt_Task3, F     ; Decrement task timer count.
        bra     SRTX_Scheduler_Exit         ; Task timer count not expired.
        movlw   SRTX_CNT_RELOAD_TASK3       ; Task timer expired, reload count.
        movwf   SRTX_Timer_Cnt_Task3
        incfsz  SRTX_Sched_Cnt_Task3, F     ; Increment task schedule count.
        bra     SRTX_Scheduler_Exit         ; Task schedule count did not rollover.
        decf    SRTX_Sched_Cnt_Task3, F     ; Max task schedule count.
;
SRTX_Scheduler_Exit
        return                              ; MANDATORY return when invoked by SISD_Interrupt.
;
;*******************************************************************************
;
; SRTX Dispatcher:
;   Background task starts after all initialization complete.
;   Checks all tasks in priority order to see which are scheduled.
;   If multiple tasks are scheduled, then highest priority task executes.
;   No return from this routine.
;
; Priority (1 = highest):
;	1: I2C
;	2: ADC
;	3: Task1
;	4: Task2
;	5: Task3
;
;*******************************************************************************
;
SRTX_Dispatcher
;
		movlw	0							; Clear W.
		banksel	SRTX_Sched_Cnt_TaskI2C
        addwf   SRTX_Sched_Cnt_TaskI2C, W   ; Check if non-zero schedule count.
        btfsc   STATUS, Z                   ; Skip if task scheduled.
        bra     SRTX_Dispatcher_CheckADC    ; Task not scheduled, check next task.
        call    SUSR_TaskI2C                ; Invoke task.
		banksel	SRTX_Sched_Cnt_TaskI2C
        decfsz  SRTX_Sched_Cnt_TaskI2C, F   ; Dec schedule count, this invocation done.
        nop                                 ; Trap, task was scheduled again before done.
        bra     SRTX_Dispatcher             ; Test scheduled tasks starting w/highest priority task.
;
SRTX_Dispatcher_CheckADC
;
		movlw	0							; Clear W.
		banksel	SRTX_Sched_Cnt_TaskADC
        addwf   SRTX_Sched_Cnt_TaskADC, W   ; Check if non-zero schedule count.
        btfsc   STATUS, Z                   ; Skip if task scheduled.
        bra     SRTX_Dispatcher_Check1      ; Task not scheduled, check next task.
        call    SUSR_TaskADC                ; Invoke task.
		banksel	SRTX_Sched_Cnt_TaskADC
        decfsz  SRTX_Sched_Cnt_TaskADC, F   ; Dec schedule count, this invocation done.
        nop                                 ; Trap, task was scheduled again before done.
        bra     SRTX_Dispatcher             ; Test scheduled tasks starting w/highest priority task.
;
SRTX_Dispatcher_Check1
;
		movlw	0							; Clear W.
		banksel	SRTX_Sched_Cnt_Task1
        addwf   SRTX_Sched_Cnt_Task1, W     ; Check if non-zero schedule count.
        btfsc   STATUS, Z                   ; Skip if task scheduled.
        bra     SRTX_Dispatcher_Check2      ; Task not scheduled, check next task.
        call    SUSR_Task1                  ; Invoke task.
		banksel	SRTX_Sched_Cnt_Task1
        decfsz  SRTX_Sched_Cnt_Task1, F     ; Dec schedule count, this invocation done.
        nop                                 ; Trap, task was scheduled again before done.
        bra     SRTX_Dispatcher             ; Test scheduled tasks starting w/highest priority task.
;
SRTX_Dispatcher_Check2
;
		movlw	0							; Clear W.
		banksel	SRTX_Sched_Cnt_Task2
        addwf   SRTX_Sched_Cnt_Task2, W     ; Check if non-zero schedule count.
        btfsc   STATUS, Z                   ; Skip if task scheduled.
        bra     SRTX_Dispatcher_Check3      ; Task not scheduled, check next task.
        call    SUSR_Task2                  ; Invoke task.
		banksel	SRTX_Sched_Cnt_Task2
        decfsz  SRTX_Sched_Cnt_Task2, F     ; Dec schedule count, this invocation done.
        nop                                 ; Trap, task was scheduled again before done.
        bra     SRTX_Dispatcher             ; Test scheduled tasks starting w/highest priority task.
;
SRTX_Dispatcher_Check3
;
		movlw	0							; Clear W.
		banksel	SRTX_Sched_Cnt_Task3
        addwf   SRTX_Sched_Cnt_Task3, W     ; Check if non-zero schedule count.
        btfsc   STATUS, Z                   ; Skip if task scheduled.
        bra     SRTX_Dispatcher_CheckX      ; Task not scheduled, check next task.
        call    SUSR_Task3                  ; Invoke task.
		banksel	SRTX_Sched_Cnt_Task3
        decfsz  SRTX_Sched_Cnt_Task3, F     ; Dec schedule count, this invocation done.
        nop                                 ; Trap, task was scheduled again before done.
        bra     SRTX_Dispatcher             ; Test scheduled tasks starting w/highest priority task.
;
SRTX_Dispatcher_CheckX
        bra     SRTX_Dispatcher             ; Test scheduled tasks starting w/highest priority task.
;
;*******************************************************************************
;
; SRTX Computed Branch / Relative Call:
;   Use the value in W as an offset to the program counter saved in the TOS
;   (Top Of Stack) registers.  This allows a computed branch or relative call
;   into a table of program addresses, useful for implementing state tables.
;
;	Either BRA or RCALL instructions will work because those instructions use
;   2 bytes each.  There is a separate routine for using GOTO or CALL instructions.
;
;		return						; Jump to computed addr.
;
; To use this feature in a calling program, set it up as follows:
;		...
;       banksel State_Variable
;       movf    State_Variable, W   	; Get state variable into W.
;       call	SRTX_ComputedBraRcall	; W = offset, index into state machine jump table.
;
; (Note that this table must IMMEDIATELY follow the code above.)
;
;       bra     State0_Routine  	; Program label for State 0 routine (W = 0)
;       bra     State1_Routine  	; Program label for State 1 routine (W = 1)
;       bra     State2_Routine  	; Program label for State 2 routine (W = 2)
;   	...
;
; (Alteratively, the RCALL instruction could be used instead of BRA.)
;
;       rcall   State0_Routine  	; Program label for State 0 routine (W = 0)
;       rcall   State1_Routine  	; Program label for State 1 routine (W = 1)
;       rcall   State2_Routine  	; Program label for State 2 routine (W = 2)
;   	...
;
;*******************************************************************************
;
        GLOBAL  SRTX_ComputedBraRCall
SRTX_ComputedBraRCall
;
        banksel SRTX_TempRotate
		movwf	SRTX_TempRotate		; Move input arg W to where we can rotate it.
		rlncf	SRTX_TempRotate		; Index * 2 = offset in words (2 bytes).
		movf	SRTX_TempRotate,W	; Move Index * 2 back to W.
		addwf	TOSL, F				; Add jump offset in W to return address.
		btfsc	STATUS, C			; If there was an overflow..
		incf    TOSH, F				; ..then adjust the high byte ret addr too.
;
;   Notice we don't bother with TOSU because program memory is under 64K bytes
;   But if we were to bother, it would look like...
;
;		btfsc	STATUS, C			; If there was an overflow..
;		incf    TOSU, F				; ..then adjust the upper byte ret addr too.
;
		return						; Jump to computed addr.
;
;*******************************************************************************
;
; SRTX Computed Goto / Call:
;   Use the value in W as an offset to the program counter saved in the TOS
;   (Top Of Stack) registers.  This allows a computed goto or call
;   into a table of program addresses, useful for implementing state tables.
;
;	Either GOTO or CALL instructions will work because those instructions use
;   4 bytes each.  There is a separate routine for using BRA or RCALL instructions.
;
;		return						; Jump to computed addr.
;
; To use this feature in a calling program, set it up as follows:
;		...
;       banksel State_Variable
;       movf    State_Variable, W   	; Get state variable into W.
;       call	SRTX_ComputedGotoCall	; W = offset, index into state machine jump table.
;
; (Note that this table must IMMEDIATELY follow the code above.)
;
;       goto    State0_Routine  	; Program label for State 0 routine (W = 0)
;       goto    State1_Routine  	; Program label for State 1 routine (W = 1)
;       goto    State2_Routine  	; Program label for State 2 routine (W = 2)
;   	...
;
; (Alteratively, the CALL instruction could be used instead of GOTO.)
;
;       call    State0_Routine  	; Program label for State 0 routine (W = 0)
;       call    State1_Routine  	; Program label for State 1 routine (W = 1)
;       call    State2_Routine  	; Program label for State 2 routine (W = 2)
;   	...
;
;*******************************************************************************
;
        GLOBAL  SRTX_ComputedGotoCall
SRTX_ComputedGotoCall
        banksel SRTX_TempRotate
		movwf	SRTX_TempRotate		; Move input arg W to where we can rotate it.
		rlncf	SRTX_TempRotate		; Index * 4 = offset in double words (4 bytes).
		rlncf	SRTX_TempRotate
		movf	SRTX_TempRotate,W	; Move Index * 2 back to W.
		addwf	TOSL, F				; Add jump offset in W to return address.
		btfsc	STATUS, C			; If there was an overflow..
		incf    TOSH, F				; ..then adjust the high byte ret addr too.
;
;   Notice we don't bother with TOSU because program memory is under 64K bytes
;   But if we were to bother, it would look like...
;
;		btfsc	STATUS, C			; If there was an overflow..
;		incf    TOSU, F				; ..then adjust the upper byte ret addr too.
;
		return						; Jump to computed addr.
        end