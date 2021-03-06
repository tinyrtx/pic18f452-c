        LIST
;*******************************************************************************
; tinyRTX Filename: si2c.asm (System Inter-IC (I2C) communication services)
;             Assumes MSSP module is available on chip.
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
;   13Jan04  SHiggins@tinyRTX.com Created from scratch.
;   12Aug14  SHiggins@tinyRTX.com Converted from PIC16877 to PIC18F452.
;   15Aug14  SHiggins@tinyRTX.com Converted PIC16 jump table to SUTL_ComputedBraRCall.
;   18Aug14  SHiggins@tinyRTX.com Corrections due to testing.
;   16Apr15  Stephen_Higgins@KairosAutonomi.com Removed #include <strc.inc>.
;   14May15  Stephen_Higgins@KairosAutonomi.com  
;               Substitute #include <ucfg.inc> for <p18f452.inc>.
;               Removed unnecessary banksel's for SFR's in access RAM.
;
;*******************************************************************************
;
        errorlevel -302 
;
        #include    <ucfg.inc>  ; Configure board and proc, #include <proc.inc>
        #include    <sutl.inc>
        #include    <si2cuser.inc>
        #include    <susr.inc>
;
        LIST
;*******************************************************************************
;
; SI2C service variables.
;
        GLOBAL  SI2C_Flags
        GLOBAL  SI2C_AddrSlave
        GLOBAL  SI2C_DataCntXmt
        GLOBAL  SI2C_DataByteXmt00
        GLOBAL  SI2C_DataByteXmt01
        GLOBAL  SI2C_DataByteXmt02
        GLOBAL  SI2C_DataByteXmt03
        GLOBAL  SI2C_DataCntRcv
        GLOBAL  SI2C_DataByteRcv00
        GLOBAL  SI2C_DataByteRcv01
        GLOBAL  SI2C_DataByteRcv02
        GLOBAL  SI2C_DataByteRcv03
;
SI2C_UdataSec   UDATA
;
SI2C_HwState        res     1               ; I2C hardware state machine variable.
SI2C_HwStateError   res     1               ; SI2C_HwState to use when error encountered.
SI2C_Flags          res     1               ; I2C status and error flags.
SI2C_AddrSlave      res     1               ; I2C slave address, 7-bit left-justified, bit0 = dont care.
SI2C_DataCntXmt     res     1               ; I2C data byte count for writes.
SI2C_DataPtrXmtH    res     1               ; I2C data pointer for writes.
SI2C_DataPtrXmtL    res     1               ; I2C data pointer for writes.
SI2C_DataByteXmt00  res     1               ; I2C data byte 00 for writes.
SI2C_DataByteXmt01  res     1               ; I2C data byte 01 for writes.
SI2C_DataByteXmt02  res     1               ; I2C data byte 02 for writes.
SI2C_DataByteXmt03  res     1               ; I2C data byte 03 for writes.
SI2C_DataCntRcv     res     1               ; I2C data byte count for reads.
SI2C_DataPtrRcvH    res     1               ; I2C data pointer for reads.
SI2C_DataPtrRcvL    res     1               ; I2C data pointer for reads.
SI2C_DataByteRcv00  res     1               ; I2C data byte 00 for reads.
SI2C_DataByteRcv01  res     1               ; I2C data byte 01 for reads.
SI2C_DataByteRcv02  res     1               ; I2C data byte 02 for reads.
SI2C_DataByteRcv03  res     1               ; I2C data byte 03 for reads.
;
;*******************************************************************************
;
SI2C_TableSec   CODE
;
; NOTE: THESE #define's ARE LINKED TO SI2C_Tbl_HwState TABLE DEFINITION BELOW.
;
#define SI2C_HWSTATE_SLAVEACKERROR  0x00
#define SI2C_HWSTATE_WRITE          0x01
#define SI2C_HWSTATE_WRITEERROR     0x05
#define SI2C_HWSTATE_WRITEREAD      0x06
#define SI2C_HWSTATE_WRITEREADERROR 0x0F
;
        GLOBAL  SI2C_Tbl_HwState
SI2C_Tbl_HwState
;
; Execute I2C hardware handling due to I2C interrupt based on I2_HwState.
;
        banksel SI2C_HwState
        movf    SI2C_HwState, W         ; Get SI2C hardware state.
        call    SUTL_ComputedBraRCall   ; W = offset, index into state machine jump table.
;
; State processing: Various error conditions.                       SI2C_HwState
;
        bra     SI2C_SlaveAckError  ; Slave ACK/NACK error              = 0
;
; State processing: multibyte data write.                           SI2C_HwState
;
        bra     SI2C_StartEnable    ; Start enable (read or write)      = 1
        bra     SI2C_SendWriteAddr  ; Address for data write            = 2
        bra     SI2C_WriteData      ; Write data                        = 3
        bra     SI2C_StopEnable     ; Stop enable (read or write)       = 4
        bra     SI2C_MsgDone        ; Msg completed, return to user     = 5
;
; State processing: multibyte data write/multibyte data read.       SI2C_HwState
;
        bra     SI2C_StartEnable    ; Start enable (read or write)      = 6
        bra     SI2C_SendWriteAddr  ; Address for data write            = 7
        bra     SI2C_WriteData      ; Write data                        = 8
        bra     SI2C_RestartEnable  ; Restart enable (read or write)    = 9
        bra     SI2C_SendReadAddr   ; Address for data read             = A
        bra     SI2C_ReceiveEnable  ; Receive enable (read)             = B
        bra     SI2C_ReadData       ; Read data                         = C
        bra     SI2C_AckNackDone    ; ACK or NACK complete              = D
        bra     SI2C_StopEnable     ; Stop enable (read or write)       = E
        bra     SI2C_MsgDone        ; Msg completed, return to user     = F
;
; NOTE: THESE table definitions ARE LINKED TO SI2C_Tbl_HwState #define's ABOVE.
;
;*******************************************************************************
;
; SI2C Services.
;
SI2C_CodeSec    CODE    
;
;*******************************************************************************
;
; I2C error condition: No slave write acknowledge on previous addr or data transfer.
;   This is a pseudo-state which any state may GOTO when slave ack failure detected.
;   NOTE: Checking slave ACK is never necessary upon entry here, as it was known to fail.
;   After exit, MSSP interrupts when bus stop condition achieved and MSSP is idle.
;
SI2C_SlaveAckError
;
        banksel SI2C_Flags
        bsf     SI2C_Flags, SI2C_Flag_SlvAckError   ; No slave ACK, flag error.
        bcf     SI2C_Flags, SI2C_Flag_ChkAck        ; Don't check slave ACK after this action.
;
        movf    SI2C_HwStateError, W                ; Get error state.
        movwf   SI2C_HwState                        ; Reset SI2C_HwState with error state.
;
        banksel SSPCON2
        bsf     SSPCON2, PEN                        ; Initiate I2C bus stop.
        return
;
;*******************************************************************************
;
; Generate I2C bus start condition.
;   NOTE: Checking slave ACK is never necessary upon entry here.
;   After exit, MSSP interrupts when bus start condition achieved and MSSP is idle.
;
SI2C_StartEnable
;
        banksel SI2C_Flags
        bsf     SI2C_Flags, SI2C_Flag_InUse         ; Set "in-use" flag.
        bcf     SI2C_Flags, SI2C_Flag_SlvAckError   ; Clear slave ACK error flag.
        bcf     SI2C_Flags, SI2C_Flag_ChkAck        ; Don't check slave ACK after this action.
;
        incf    SI2C_HwState, F                     ; Update SI2C_HwState state var to next state.
;
        bsf     PIE1, SSPIE                         ; Enable I2C interrupts.
        bsf     SSPCON2, SEN                        ; Initiate I2C bus start.
        return
;
;*******************************************************************************
;
; Generate I2C bus repeated start condition.
;   This routine can detect bad slave ACK, and abort transfer.
;   After exit, MSSP interrupts when bus repeated start condition achieved and MSSP is idle.
;
SI2C_RestartEnable
;
        banksel SI2C_Flags
        btfss   SI2C_Flags, SI2C_Flag_ChkAck        ; Check slave ACK?
        bra     SI2C_RestartEnable_AckOK            ; No, skip check.
        btfss   SSPCON2, ACKSTAT                    ; Test for slave ACK.
        bra     SI2C_RestartEnable_AckOK            ; Slave ACK OK.
;
; Bad Slave ACK, force transition to error state.
;
        movlw   SI2C_HWSTATE_SLAVEACKERROR          ; State for slave ack error.
        movwf   SI2C_HwState                        ; Reset SI2C_HwState with error state.
        bra     SI2C_Tbl_HwState                    ; Execute state based on SI2C_HwState.
;
SI2C_RestartEnable_AckOK
;
        bcf     SI2C_Flags, SI2C_Flag_ChkAck        ; Don't check slave ACK after this action.
        incf    SI2C_HwState, F                     ; Update SI2C_HwState state var to next state.
        bsf     SSPCON2, RSEN                       ; Initiate I2C bus restart.
        return
;
;*******************************************************************************
;
; Generate I2C bus receive enable condition.
;   This routine can detect bad slave ACK, and abort transfer.
;   NOTE: This routine will probably always check for valid slave ACK, as preceeding
;       action is probably ADDR READ which generates slave ACK.
;   After exit, MSSP interrupts when data byte received and MSSP is idle.
;
SI2C_ReceiveEnable
;
        banksel SI2C_Flags
        btfss   SI2C_Flags, SI2C_Flag_ChkAck        ; Check slave ACK?
        bra     SI2C_ReceiveEnable_AckOK            ; No, skip check.
        btfss   SSPCON2, ACKSTAT                    ; Test for slave ACK.
        bra     SI2C_ReceiveEnable_AckOK            ; Slave ACK OK.
;
; Bad Slave ACK, force transition to error state.
;
        movlw   SI2C_HWSTATE_SLAVEACKERROR          ; State for slave ack error.
        movwf   SI2C_HwState                        ; Reset SI2C_HwState with error state.
        bra     SI2C_Tbl_HwState                    ; Execute state based on SI2C_HwState.
;
SI2C_ReceiveEnable_AckOK
;
        bcf     SI2C_Flags, SI2C_Flag_ChkAck        ; Don't check slave ACK after this action.
        incf    SI2C_HwState, F                     ; Update SI2C_HwState state var to next state.
        bsf     SSPCON2, RCEN                       ; Initiate I2C receive.
        return
;
;*******************************************************************************
;
; Generate I2C bus stop condition.
;   This routine can detect bad slave ACK.
;   After exit, MSSP interrupts when bus stop condition achieved and MSSP is idle.
;
SI2C_StopEnable
;
        banksel SI2C_Flags
        btfss   SI2C_Flags, SI2C_Flag_ChkAck        ; Check slave ACK?
        bra     SI2C_StopEnable_AckOK               ; No, skip check.
        btfss   SSPCON2, ACKSTAT                    ; Test for slave ACK.
        bra     SI2C_StopEnable_AckOK               ; Slave ACK OK.
;
; Bad Slave ACK, force transition to error state.
;
        movlw   SI2C_HWSTATE_SLAVEACKERROR          ; State for slave ack error.
        movwf   SI2C_HwState                        ; Reset SI2C_HwState with error state.
        bra     SI2C_Tbl_HwState                    ; Execute state based on SI2C_HwState.
;
SI2C_StopEnable_AckOK
;
        bcf     SI2C_Flags, SI2C_Flag_ChkAck        ; Don't check slave ACK after this action.
        incf    SI2C_HwState, F                     ; Update SI2C_HwState state var to next state.
        bsf     SSPCON2, PEN                        ; Initiate I2C bus stop.
        return
;
;*******************************************************************************
;
; I2C message is done and bus is inactive.
;   SI2C_MsgDone is a special ending state of SI2C_HwState.
;   It is the only SI2C hardware state to trigger a new User task.
;   NOTE: Checking slave ACK is never necessary upon entry here, because
;       bus stop has always been done normally or because error detected.
;
SI2C_MsgDone
;
        bcf     PIE1, SSPIE                     ; Disable I2C interrupts.
        banksel SI2C_Flags
        bcf     SI2C_Flags, SI2C_Flag_InUse     ; Clear "in-use" flag.
        goto    SUSR_TaskI2C_MsgDone            ; Finish current, and/or start next User msg.
;
;*******************************************************************************
;
; Generate I2C slave address for data write (R/W=0).
;   NOTE: Checking slave ACK is never necessary upon entry here, because bus start
;       or bus restart must have just been done.
;   After exit, MSSP interrupts when slave address sent, slave ACK/NACK received and MSSP is idle.
;
SI2C_SendWriteAddr
;
        banksel SI2C_HwState
        incf    SI2C_HwState, F                 ; Update SI2C_HwState state var to next state.
        bsf     SI2C_Flags, SI2C_Flag_ChkAck    ; Check slave ACK after this action.
;
        movlw   high SI2C_DataByteXmt00         ; Init DataPtrXmt with addr of first xmt byte.
        movwf   SI2C_DataPtrXmtH
        movlw   low SI2C_DataByteXmt00
        movwf   SI2C_DataPtrXmtL
;
        bcf     SI2C_AddrSlave, 0               ; Slave addr bit 0 cleared = write data operation.          
        movf    SI2C_AddrSlave, W               ; Get 7-bit slave address with bit 0 clear.
        movwf   SSPBUF                          ; Write slave address on I2C bus.
        return
;
;*******************************************************************************
;
; Generate I2C slave address for data read (R/W=1).
;   NOTE: Checking slave ACK is never necessary upon entry here, because bus start
;       or bus restart must have just been done.
;   After exit, MSSP interrupts when slave address sent, slave ACK/NACK received and MSSP is idle.
;
SI2C_SendReadAddr
;
        banksel SI2C_HwState
        incf    SI2C_HwState, F                 ; Update SI2C_HwState state var to next state.
        bsf     SI2C_Flags, SI2C_Flag_ChkAck    ; Check slave ACK after this action.
;
        movlw   high SI2C_DataByteRcv00         ; Init DataPtrRcv with addr of first rcv byte.
        movwf   SI2C_DataPtrRcvH
        movlw   low SI2C_DataByteRcv00
        movwf   SI2C_DataPtrRcvL
;
        bsf     SI2C_AddrSlave, 0               ; Slave addr bit 1 set = read data operation.          
        movf    SI2C_AddrSlave, W               ; Get 7-bit slave address with bit 0 clear.
        movwf   SSPBUF                          ; Write slave address on I2C bus.
        return
;
;*******************************************************************************
;
; Generate I2C data write.
;   This routine can write multiple bytes using SI2C_DataPtrXmt and SI2C_DataCntXmt.
;   This routine can detect a bad slave ACK, and abort transfer.
;   NOTE: This routine will probably always check for valid slave ACK, as preceeding
;       action is either ADDR WRITE or DATA WRITE, both of which generate slave ACKs.
;   After exit, MSSP interrupts when slave data written, slave ACK/NACK received and MSSP is idle.
;
SI2C_WriteData
;
        banksel SI2C_Flags
        btfss   SI2C_Flags, SI2C_Flag_ChkAck        ; Check slave ACK?
        bra     SI2C_WriteData_AckOK                ; No, skip check.
        btfss   SSPCON2, ACKSTAT                    ; Test for slave ACK.
        bra     SI2C_WriteData_AckOK                ; Slave ACK OK.
;
; Bad Slave ACK, force transition to error state.
;
        movlw   SI2C_HWSTATE_SLAVEACKERROR          ; State for slave ack error.
        movwf   SI2C_HwState                        ; Reset SI2C_HwState with error state.
        bra     SI2C_Tbl_HwState                    ; Execute state based on SI2C_HwState.
;
SI2C_WriteData_AckOK
;
        bsf     SI2C_Flags, SI2C_Flag_ChkAck    ; Check slave ACK after this action.
;
        movff   SI2C_DataPtrXmtH, FSR0H         ; Get write data pointer.
        movff   SI2C_DataPtrXmtL, FSR0L
        movf    POSTINC0, W                     ; Copy write data byte into W, and inc ptr.
        movff   FSR0H, SI2C_DataPtrXmtH         ; Save incremented pointer.
        movff   FSR0L, SI2C_DataPtrXmtL
;
        decfsz  SI2C_DataCntXmt, F              ; Decr count of remaining write data bytes.
        bra     SI2C_WriteData_SendByte         ; More write data bytes remain, SI2C_HwState untouched.
        incf    SI2C_HwState, F                 ; This is last datum, update SI2C_HwState to next state.
;
SI2C_WriteData_SendByte
;
        movwf   SSPBUF                          ; Write data to I2C bus.
        return
;
;*******************************************************************************
;
; Read received I2C data.
;   This routine can read multiple bytes using SI2C_DataPtrRcv and SI2C_DataCntRcv.
;   NOTE: Checking slave ACK is never necessary upon entry here, because receive enable
;       must have just been done.
;   This routine sends an ACK if there is more data to receive, or NACK if last data received.
;   After exit, MSSP interrupts when ACK or NACK is transmitted and MSSP is idle.
;
SI2C_ReadData
;
        banksel SI2C_Flags
        bcf     SI2C_Flags, SI2C_Flag_ChkAck    ; Don't check slave ACK after this action.
        incf    SI2C_HwState, F                 ; Update SI2C_HwState to next state.
;
        movff   SI2C_DataPtrRcvH, FSR0H         ; Get read data pointer.
        movff   SI2C_DataPtrRcvL, FSR0L
        movff   SSPBUF, POSTINC0                ; Copy data byte from SSP to buffer, and inc ptr.
        movff   FSR0H, SI2C_DataPtrRcvH         ; Save incremented pointer.
        movff   FSR0L, SI2C_DataPtrRcvL
;
        decfsz  SI2C_DataCntRcv, F              ; Decr count of remaining read data bytes.
        bra     SI2C_ReadData_SendAck           ; More read data bytes remain, send ACK.
;
SI2C_ReadData_SendNack
;
        bsf     SSPCON2, ACKDT                  ; Set ACKDT to send NACK.
        bra     SI2C_ReadData_Exit
;
SI2C_ReadData_SendAck
;
        bcf     SSPCON2, ACKDT                  ; Clear ACKDT to send ACK.
;
SI2C_ReadData_Exit
;
        bsf     SSPCON2, ACKEN                  ; Start ACK/NACK transmit to slave.
        return
;
;*******************************************************************************
;
; ACK or NACK has been transmitted to slave in response to received I2C data.
;   This routine can trigger another data read if SI2C_DataCntRcv is not zero.  This is
;       done by initiating an MSSP receive enable, and decrementing SI2C_HwState so that
;       SI2C_ReadData is executed when the data byte is received.  In this case, after exit, 
;       MSSP interrupts when data byte received and MSSP is idle. 
;   This routine will simply increment SI2C_HwState if SI2C_DataCntRcv is zero.  In this case
;       we will transition probably either to SI2C_StopEnable or SI2C_RestartEnable.  However,
;       since there is no MSSP event to trigger that next state, we do a GOTO SI2C_Tbl_HwState,
;       which will FORCE the next state to execute.
;   NOTE: Checking slave ACK is never necessary upon entry here, because ACK or NACK
;       must have just been sent to slave.
;
SI2C_AckNackDone
;
        banksel SI2C_Flags
        bcf     SI2C_Flags, SI2C_Flag_ChkAck    ; Don't check slave ACK after this action.
        movf    SI2C_DataCntRcv, W              ; Get count of remaining read data bytes.
        btfss   STATUS, Z                       ; Skip if zero remaining count to read.
        bra     SI2C_AckNackDone_ReceiveEnable  ; Jump if non-zero remaining count to read.
;
;   Force state transition and execute next state, as there is no MSSP response to trigger it.
;
        incf    SI2C_HwState, F                 ; Update SI2C_HwState to next state.
        bra     SI2C_Tbl_HwState                ; Execute state based on SI2C_HwState.
;
SI2C_AckNackDone_ReceiveEnable
;
        decf    SI2C_HwState, F                 ; Update SI2C_HwState to prev state (SI2C_ReadData).
        bsf     SSPCON2, RCEN                   ; Initiate I2C receive.
        return
;
;*******************************************************************************
;
; WRAPPERS allow easy user access to predefined messages.
;
;*******************************************************************************
;
; Write one or more bytes.
;   SI2C wrapper that allows user to start a write message without knowing about SI2C_HwState.
;   Data to write must be already stored beginning at SI2C_DataByteXmt00.
;   Count of data to write must be already stored at SI2C_DataCntXmt.
;
        GLOBAL  SI2C_Msg_Write
SI2C_Msg_Write
;
        banksel SI2C_HwState
        movlw   SI2C_HWSTATE_WRITE          ; First state for multibyte data write.
        movwf   SI2C_HwState                ; Init SI2C_HwState with first state.
        movlw   SI2C_HWSTATE_WRITEERROR     ; Error state for multibyte data write.
        movwf   SI2C_HwStateError           ; Set SI2C_HwStateError with error state.
        bra     SI2C_Tbl_HwState            ; Execute state based on SI2C_HwState.
;
;*******************************************************************************
;
; Write one or more bytes and then Bus Restart and read one or more bytes.
;   SI2C wrapper that allows user to start a write/read message without knowing about SI2C_HwState.
;   Data to write must be already stored beginning at SI2C_DataByteXmt00.
;   Count of data to write must be already stored at SI2C_DataCntXmt.
;   Count of data to read must be already stored at SI2C_DataCntRcv.
;   Data read will be stored beginning at SI2C_DataByteRcv00.
;
        GLOBAL  SI2C_Msg_Wrt_Rd
SI2C_Msg_Wrt_Rd
;
        banksel SI2C_HwState
        movlw   SI2C_HWSTATE_WRITEREAD          ; First state for multibyte data write.
        movwf   SI2C_HwState                    ; Init SI2C_HwState with first state.
        movlw   SI2C_HWSTATE_WRITEREADERROR     ; Error state for multibyte data write.
        movwf   SI2C_HwStateError               ; Set SI2C_HwStateError with error state.
        bra     SI2C_Tbl_HwState                ; Execute state based on SI2C_HwState.
;
        end