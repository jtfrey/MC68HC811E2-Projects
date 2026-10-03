;
; bseepp - BootStrap EE Prom Programmer
;
; When the MC68HC811E2 is reset in bootstrap mode, a program can be loaded
; into the zero page of memory — it's only RAM.  In normal mode, the MCU
; instead reads the jump vector at $FFFE and begins executing code at that
; address.  Getting that RESET vector programmed — not to mention the code
; corresponding with it — requires that a program be loaded in the bootstrap
; mode that can receive data and program it into the EEPROM.
;
; That is exactly what this program does.  The bootstrap ROM handles the
; initialization of the MCU serial communications interface and negotiation
; of the remote ends baud rate.  It then receives this program's bytes and
; writes them (all 256 of them) into the zero page.  When done, it jumps to
; $0000 to begin executing the received program.
;
; At that point the code in this file takes control of the MCU.  It resets
; the stack to the top of the zero page, then awaits a _payload header_
; that provides parameters for the procedure.  The header looks like:
;
;       0x52 0x4F 0x4C      // The ASCII characters 'ROL'
;       0xLL 0xHH           // The base address to be programmed, LSB then MSB
;       0x3A                // The ASCII character ':'
;       0xLL 0xHH           // The size of the region to be programmed, LSB
;                           // then MSB
;
; The starting address and ending address (start + size) are valiated against
; the assembled-in ROM address range:

ROM_START       EQU     $F800
ROM_SIZE        EQU     $0800
ROM_END         EQU     $0000

; If all is good to go, then the program enters the programming loop.
;
; The programming loop leads off by clearing bits in the BPROT i/o register
; to unprotect specific segments of the EEPROM.  This program does NOT modify
; the CONFIG register, so the PTCON bit should never be modified.  The other
; four bits correspond to 512-byte segments:
;
;       BPRT3       $xE00–$xFFF
;       BPRT2       $xC00–$xDFF
;       BPRT1       $xA00–$xBFF
;       BPRT0       $x800–$x9FF
;
; When preparing for ROM programming, it is up to the user to determine which
; segments will be modified and alter the EEUNPRTCTMSK symbol value
; accordingly:

EEUNPRTCTMSK    EQU     $08                     ; 0b000[PTCON][BPRT3][BPRT2][BPRT1][BPRT0]
                                                ; Bit set = unprotect that segment of EEPROM

; The program then loops over the provided range of addresses, reading bytes
; from the serial connection in sequence and programming them into the EEPROM
; in the same sequence.
;
; Once all addresses have been programmed the segment protections are restored
; and a message is sent back across the serial connection indicating the MCU
; is ready for a RESET.  At that point, the MCU is halted.
;
; NOTES:
;
; The interrupt and RESET vectors occupy addresses $FFC0 through $FFFF in the
; ROM, with RESET at $FFFE — the 512-byte segment protected by BPRT3.  A very
; simple ROM image is present in the simple-rom.s file.  Its EEPROM programming
; stream with a 105-byte payload would look like:
;
; 8E 00 FF CE 10 00 1C 28 20 86 B3 A7 2B 86 0C A7
; 2D 1C 2D 01 1E 08 01 FC 1D 2D 01 86 30 1F 2E 80
; FC A7 2F 8B 01 84 37 20 F4 FF FF FF FF FF FF FF
; FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
; FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
; FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF FF
; FF FF FF FF FF FF FF FF 97
;
                CPU     6811
            
                INCLUDE ../io_regs.s

EEERASE         EQU     $04                     ; EEERASE = 0b00000100 (erase)
EELAT           EQU     $02                     ; EELAT = 0b00000010 (latch)
EEPGM           EQU     $01                     ; EEPGM = 0b00000001 (program)


                ORG     $0000                   ; Start of program (page zero)
            
; ----------------------------------------------------------------
; Main Program Initialization
; ----------------------------------------------------------------
MAIN            LDS     #$00FF                  ; Initialize stack pointer at top of RAM
                LDX     #IOREGS                 ; Load X register with base address of I/O registers

                ; The bootstrap ROM will have already negotiated
                ; a baud rate of 7813 or 1200 and enabled the
                ; transmit and receive channels.

; ----------------------------------------------------------------
; Payload header.  The sender must transmit in ASCII the sequence
; 'ROL' — for Read Only Load.  This is followed by two bytes, LSB
; first, with the load address; an ASCII colon character; then
; two bytes, LSB first, with the load size.
;
; The format and addresses are validated.  The 'ROL' section will
; continually retry until that sequence is read, but problems with
; the other components will produce an error message and halt the
; MCU.
; ----------------------------------------------------------------
HEADER_START    LDAB    #'R'                    ; B holds our anticipated
                                                ; character for comparison
HEADER_NEXTCHAR JSR     SCI_IN                  ; A <- serial Rx
                CBA                             ; B == A ?
                BNE     HEADER_START            ; Nope, start over
                SUBB    #3                      ; Move to the next character
                                                ; in the sequence
                CMPB    #'I'                    ; If we've gotten to I, we're done
                BNE     HEADER_NEXTCHAR         ; This loop exits 
                
HEADER_ADDR     BSR     SCI_IN
                STAA    LOAD_ADDR + 1           ; Load address, LSB
                BSR     SCI_IN
                STAA    LOAD_ADDR               ; Load address, MSB
                LDY     LOAD_ADDR               ; Move the load address to Y
                CPY     #ROM_START
                BGE     HEADER_SIZESEP          ; Load address below ROM?
                LDAB    #'1'
                JMP     ERROR_OUT               ; ERROR 1:  invalid start address
                
                ; Note that coming out of the section above, the starting
                ; address remains in the Y register AND has been stored to
                ; LOAD_ADDR.
                
HEADER_SIZESEP  BSR     SCI_IN
                CMPA    #':'
                BEQ     HEADER_SIZE             ; Not a colon character?
                LDAB    #'2'
                JMP     ERROR_OUT               ; ERROR 2:  missing colon separator

HEADER_SIZE     BSR     SCI_IN
                TAB                             ; B <- LSB of size
                BSR     SCI_IN                  ; A <- MSB of size
                                                ; D now has the 16-bit size
                ADDD    LOAD_ADDR               ; D <- D + LOAD_ADDR
                STD     LOAD_ADDR               ; LOAD_ADDR now has the ending
                                                ; address of the write range
                CPD     #ROM_END
                BLE     EEPROM_ERASE            ; The end address is valid!
                LDAB    #'3'
                JMP     ERROR_OUT               ; ERROR 3:  invalid ending address

                ; Note that coming out of the section above, the starting
                ; address is in the Y register and the ending address is
                ; in LOAD_ADDR.
                
; ----------------------------------------------------------------
; The header was validated and we know where we're writing data.
; Proceed with receiving the ROM payload and writing it to the
; EEPROM.  Start by modifying EEPROM protections.  Then we loop
; over the provided address range, reading a byte from serial Rx
; and programming it into the EEPROM (latch, set byte, voltage on,
; wait 10 ms, latch + voltage off).
; ----------------------------------------------------------------
EEPROM_ERASE:   BCLR    BPROT, X EEUNPRTCTMSK   ; Clear bits on the segments of
                                                ; EEPROM we want to write
                LDAB    #EEERASE | EELAT        ; Erase all enabled segments
                STAB    PPROG, X
                STAB    $00, Y                  ; Write a single byte to trigger erase
                ORAB    #EEPGM
                STAB    PPROG, X                ; Programming voltage on
                BSR     DELAY_10MS
                CLR     PPROG, X
                
RECEIVE_PAYLD:  LDAB    #EELAT
                STAB    PPROG, X                ; Enable EEPROM latch on next byte written
                BSR     SCI_IN                  ; Get byte
                STAA    $00, Y                  ; Write the byte to EEPROM
                ORAB    #EEPGM
                STAB    PPROG, X                ; Hold latch, enable EEPROM program voltage
                BSR     DELAY_10MS              ; The EEPROM requires at least 10 ms
                CLR     PPROG, X                ; Drop latch, disable EEPROM program voltage
                BSR     DOT_OUT                 ; Show that we processed the byte (dot on
                                                ; serial Tx)
                INY                             ; Next address to program
                CPY     LOAD_ADDR               ; Compare with end address
                BLT     RECEIVE_PAYLD           ; Go get the next byte
                
; ----------------------------------------------------------------
; To complete the procedure, we will reset the EEPROM segment
; protection bits that were cleared.  Then send an indication
; that the procedure is complete back across the serial line and
; halt the MCU in anticipation of a RESET.
; ----------------------------------------------------------------
                BSET    BPROT, X EEUNPRTCTMSK   ; Set bits on the segments of
                                                ; EEPROM we unprotected
                LDY     #COMPLETE_STR           ; Y <- procedure completed string
FINAL_MSG:      LDAA    $00, Y                  ; that will be written to serial Tx
                BEQ     COMPLETE                ; NUL terminator?
                BSR     SCI_OUT                 ; Send character on serial Tx
                INY
                BRA     FINAL_MSG               ; Move on to the next one

COMPLETE:       BRA     COMPLETE

; ----------------------------------------------------------------
; Subroutine: SCI_IN
; Inputs:
;     X:    IOREGS base
; On exit the byte read from the SCI.
; ----------------------------------------------------------------
SCI_IN          BRCLR   SCSR,X RDRF SCI_IN      ; Poll SCSR until RDRF flag is 1
                LDAA    SCDR,X                  ; Read character from SCDR (clears TDRE)
                RTS
                
; ----------------------------------------------------------------
; Subroutine: SCI_OUT
; Inputs:
;     X:    IOREGS base
;     A:    ASCII character to transmit
; No side effects.
; ----------------------------------------------------------------
DOT_OUT         LDAA    #'.'                    ; For printing progress…
SCI_OUT         BRCLR   SCSR,X TDRE SCI_OUT     ; Poll SCSR until TDRE flag is 1
                STAA    SCDR,X                  ; Write character to SCDR (clears TDRE)
                RTS

; ----------------------------------------------------------------
; Subroutine: ERROR_OUT
; Writes a standard error message out the SCI and halts the MCU.
; Inputs:
;     X:    IOREGS base
;     B:    the error code as an ASCII character
; ----------------------------------------------------------------
ERROR_OUT       LDY     ERROR_STR
ERROR_OUT_PRFX  LDAA    $00, Y
                BEQ     ERROR_OUT_CODE
                BSR     SCI_OUT
                INY
                BRA     ERROR_OUT_PRFX
ERROR_OUT_CODE  TBA
                BSR     SCI_OUT
                STOP

; ----------------------------------------------------------------
; Subroutine: DELAY_10MS
; The loop in this subroutine takes exactly 20035 cycles.  With
; interrupts disabled and a 2 MHz Eclock, that's 10.0175 ms —
; just enough time for the EEPROM to program a byte.
; Inputs:
;     None
; Clobbers the A and B registers.
; ----------------------------------------------------------------
DELAY_10MS:     LDD     #$E100                  ; 3 (A = $E1[225], B = $00)
                SEC                             ; 2
                                                ; ==================
DELAY_10MS_OUTR:RORB                            ; 2
                                                ; ------------------
DELAY_10MS_RS:  LSRB                            ; 2
                BNE     DELAY_10MS_RS           ; 3
                                                ;   = 5 * 8 = 40
                                                ; ------------------
                ROLB                            ; 2
                                                ; ------------------
DELAY_10MS_LS:  LSLB                            ; 2
                BNE     DELAY_10MS_LS           ; 3
                                                ;   = 5 * 8 = 40
                                                ; ------------------
                DECA                            ; 2
                BNE     DELAY_10MS_OUTR         ; 3
                                                ;   = 89 * 225 = 20025
                                                ; ==================
                RTS                             ; 5
                                                ;   = 5 + 20025 + 5
                                                ;   = 20035 cycles





LOAD_ADDR       DW      $0000                   ; Initially receives the starting address
                                                ; of the EEPROM load, then has the size
                                                ; added to it to get the terminal address
ERROR_STR       DB      '\nERR=', $00
COMPLETE_STR    DB      '\nDONE - RESET THE MCU NOW', $00

                ; On the last revision, the code assembled to 203 bytes
                ; leaving 53 bytes for the stack at the top of the zero
                ; page.
                DB $0100-* DUP $FF