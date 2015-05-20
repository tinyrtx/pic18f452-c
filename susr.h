//**********************************************************************************************
// tinyRTX Filename: susr.h (System to USeR interface)
//
// Copyright 2014 Sycamore Software, Inc.  ** www.tinyRTX.com **
// Distributed under the terms of the GNU Lesser General Purpose License v3
//
// This file is part of tinyRTX. tinyRTX is free software: you can redistribute
// it and/or modify it under the terms of the GNU Lesser General Public License
// version 3 as published by the Free Software Foundation.
//
// tinyRTX is distributed in the hope that it will be useful, but WITHOUT ANY
// WARRANTY// without even the implied warranty of MERCHANTABILITY or FITNESS FOR
// A PARTICULAR PURPOSE.  See the GNU Lesser General Public License for more
// details.
//
// You should have received a copy of the GNU Lesser General Public License
// (filename copying.lesser.txt) and the GNU General Public License (filename
// copying.txt) along with tinyRTX.  If not, see <http://www.gnu.org/licenses/>.
//
// Revision history:
//  31Oct03 SHiggins@tinyRTX.com  Created from scratch.
//  30Jul14 SHiggins@tinyRTX.com  Reduce from 4 tasks to 3 to reduce stack needs.
//  25Aug14 SHiggins@tinyRTX.com  Create susr.h from susr.inc to use in srtx.c.
//	03Sep14 SHiggins@tinyRTX.com  Add SUSR_ISR_I2C().
//	14May15 Stephen_Higgins@KairosAutonomi.com  
//              Add SRTX_Sched_Cnt_TaskSIO.
//
//*******************************************************************************
extern	void	SUSR_POR_PhaseA(void);
extern	void 	SUSR_POR_PhaseB(void);
extern	void 	SUSR_Timebase(void);
extern	void	SUSR_Task1(void);
extern	void	SUSR_Task2(void);
extern	void	SUSR_Task3(void);
extern	void	SUSR_TaskADC(void);
extern	void	SUSR_TaskI2C(void);
extern	void	SUSR_TaskSIO(void);
extern	void	SUSR_ISR_I2C(void);
extern	void	SUSR_TaskI2C_MsgDone(void);
