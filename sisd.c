//*******************************************************************************
// tinyRTX Filename: sisd.c (System Interrupt Service Director)
//
// Copyright 2014 Sycamore Software, Inc.  ** www.tinyRTX.com **
// Distributed under the terms of the GNU Lesser General Purpose License v3
//
// This file is part of tinyRTX. tinyRTX is free software: you can redistribute
// it and/or modify it under the terms of the GNU Lesser General Public License
// version 3 as published by the Free Software Foundation.
//
// tinyRTX is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
// details.
//
// You should have received a copy of the GNU Lesser General Public License
// (filename copying.lesser.txt) and the GNU General Public License (filename
// copying.txt) along with tinyRTX.  If not, see <http://www.gnu.org/licenses/>.
//
// Revision history:
//   17Oct03 SHiggins@tinyRTX.com 	Created from scratch.
//   23Jul14 SHiggins@tinyRTX.com 	Move save/restore FSR from SISD_Director to 
//									to SISD_Interrupt
//   14Aug14 SHiggins@tinyRTX.com    Converted from PIC16877 to PIC18F452.
//   25Aug14 SHiggins@tinyRTX.com   Convert from PIC18 Assembler to C18 C sections.
//									Remove SISD_ResetEntry as using c018i.c.
//   03Sep14 SHiggins@tinyRTX.com	Save/restore BSR.
//
//*******************************************************************************

#include 	<p18f452.h>
#include    "srtx.h"
#include    "susr.h"

void SISD_Interrupt( void );

//*******************************************************************************
//
// SISD service variables.
//
// Interrupt Service Routine context save/restore variables.
//
// LINKNOTE: SISD_UdataShrSec must be placed in data space shared across all banks.
//			This is because to save/restore STATUS register properly, we can't control
//			RP1 and RP0 bits.  So any values in RP1 and RP0 must be valid.  In order to
//			allow this we need memory which accesses the same across all banks.

#pragma udata access SISD_UdataAcsSec
near unsigned char SISD_TempW;		// Access Bank: temp copy of W.
near unsigned char SISD_TempSTATUS;	// Access Bank: temp copy of STATUS.
near unsigned char SISD_TempBSR;	// Access Bank: temp copy of BSR.
near unsigned char SISD_TempPCLATH;	// Access Bank: temp copy of PCLATH.
near unsigned char SISD_TempPCLATU;	// Access Bank: temp copy of PCLATU.
near unsigned char SISD_TempFSR0H;	// Access Bank: temp copy of FSR0H.
near unsigned char SISD_TempFSR0L;	// Access Bank: temp copy of FSR0L.

//*******************************************************************************

#pragma code SISD_IntVectorSec 	// Interrupt vector address, placed at 0x08 by linker script.
void SISD_InterruptEntry( void )
{
	_asm
	goto	SISD_Interrupt			// Handle interrupt.
									// This is small because if we ever decide to
									// use prioritized interrupts, that handler
									// is placed immediately after this one.
	_endasm
}

#pragma	code SISD_IntCodeSec		// Interrupt handler, too big to fit at vector address.
//
// "#pragma interrupt SISD_Interrupt" not used because default interrupt handler prologue
//	destroys FSR0, which is used in this application's assembly code for a variety of purposes.
//	So the "_asm ... _endasm" sections at the beginning and end of this interrupt handler 
//	are used instead to protect interrupted routine's variables.
//
void SISD_Interrupt( void )
{
	_asm
    movwf   SISD_TempW, 0       	// Access RAM: preserve W without changing STATUS.
	movff	STATUS, SISD_TempSTATUS	// Access RAM: preserve STATUS.
	movff	BSR, SISD_TempBSR		// Access RAM: preserve BSR.
	movff	PCLATH, SISD_TempPCLATH	// Access RAM: preserve PCLATH.
	movff	PCLATU, SISD_TempPCLATU	// Access RAM: preserve PCLATU.
	movff	FSR0L, SISD_TempFSR0L	// Access RAM: preserve FSR0L.
	movff	FSR0H, SISD_TempFSR0H	// Access RAM: preserve FSR0H.
	_endasm
//
// Now we can use the internal registers (W, STATUS, PCLATH and FSR).
//
//*******************************************************************************
//
// SISD: System Interrupt Service Director.
//
// 3 possible sources of interrupts:
//   a) Timer1 expires. (Schedule user tasks, schedule new timer int in 100ms.)
//   b) A/D conversion completed. (Schedule the ADC task.)
//   c) I2C event completed. (Handle any of multiple I2C events to transmit ASCII.)
//
//*******************************************************************************
//
// Test for Timer1 rollover.
//
	if (PIR1bits.TMR1IF)				// If Timer1 interrupt flag set..
    {
		PIR1bits.TMR1IF = 0;       		// ..then clear Timer1 interrupt flag.
		SUSR_Timebase();				// User re-init of timebase interrupt.
        SRTX_Scheduler();				// Schedule user tasks when timebase interrupts.
    }
	else
	{
	//
	// Test for completion of A/D conversion.
	//
		if (PIR1bits.ADIF)						// If A/D interrupt flag set..
	    {
			PIR1bits.ADIF = 0;         			// ..then clear A/D interrupt flag.
			PIE1bits.ADIE = 0;         			// Disable A/D interrupts.
			if( ++SRTX_Sched_Cnt_TaskADC == 0)	// Schedule ADC task, and..
				--SRTX_Sched_Cnt_TaskADC;		// ..max it at 0xFF if it rolls over.
	    }
		else
		{
		//
		// Test for completion of I2C event.
		//
			if (PIR1bits.SSPIF)				// If A/D interrupt flag set..
		    {
				PIR1bits.SSPIF = 0;    		// ..then clear A/D interrupt flag.
				SUSR_ISR_I2C();         	// Handle the I2C task right now.
		    } // if (PIR1bits.SSPIF).
		} // if (PIR1bits.TMR1IF).
	} // if (PIR1bits.TMR1IF).
//
// Now we restore the internal registers (W, STATUS, PCLATH and FSR), taking special care not to disturb
// any of them.
//
	_asm
	movff	SISD_TempFSR0H, FSR0H 	// Access RAM: restore FSR0H.
	movff	SISD_TempFSR0L, FSR0L 	// Access RAM: restore FSR0L.
	movff	SISD_TempPCLATU, PCLATU	// Access RAM: restore PCLATU.
	movff	SISD_TempPCLATH, PCLATH	// Access RAM: restore PCLATH.
	movff	SISD_TempBSR, BSR		// Access RAM: restore BSR.
	movff	SISD_TempSTATUS, STATUS	// Access RAM: restore STATUS.
    swapf   SISD_TempW, 1, 0       	// Access RAM: restore W without changing STATUS.
    swapf   SISD_TempW, 0, 0
    retfie  1                    	// Return from interrupt.
	_endasm
}
