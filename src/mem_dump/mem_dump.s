
            CPU     6811
            
            INCLUDE ../io_regs.s

; ~1200 Baud for 8 MHz crystal/2 MHz clock:
BAUD1200    EQU     $33

; Range of bytes to write
            IFNDEF WRTBYTEND
                IFDEF WRTBYTBASE
WRTBYTEND   EQU     WRTBYTBASE + $100
                ELSEIF
WRTBYTEND   EQU     $0000       ; End of 2 KiB ROM
                ENDIF
            ENDIF
            IFNDEF WRTBYTBASE
WRTBYTBASE  EQU     $F800       ; Start of 2 KiB ROM
            ENDIF

            ORG     $0000       ; Start of program (assume ROM/EPROM)
            
; ----------------------------------------------------------------
; Main Program Initialization
; ----------------------------------------------------------------
MAIN        LDS     #$00FF      ; Initialize stack pointer at top of RAM
            LDX     #IOREGS     ; Load X register with base address of I/O registers

            ; Configure Baud Rate (1200 Baud at 8MHz Crystal)
            LDAA    #BAUD1200   ; SCP1=1, SCP0=1 (E-clock /16*13)
                                ; SCR2=0 SCR1=1 SCR0=1 (Prescaler select /8)
            STAA    BAUD,X

            ; Configure SCI Control Registers
            CLR     SCCR1,X     ; 1 start bit, 8 data bits, 1 stop bit
            
            LDAA    #$08        ; Enable transmitter (TE=1, RE=0)
            STAA    SCCR2,X

; ----------------------------------------------------------------
; Send Sample Characters
; ----------------------------------------------------------------
AGAIN       LDY     #WRTBYTBASE
            
PRNT_ADDR   LDA     #'\n'
            BSR     SCI_OUT
            PSHY                ; Save Y (our address counter)
            XGDY                ; Swap D / Y
            BSR     PRNTBYTE    ; Print high byte of address
            TBA                 ; A <- B
            BSR     PRNTBYTE    ; Print low byte of address
            LDA     #':'
            BSR     SCI_OUT
            LDAB    #$10        ; Count down another 16 bytes
            PULY                ; Restore the address counter
            
READ_BYTE   LDAA    $00,Y       ; Load byte into Accumulator A
            BSR     PRNTBYTE    ; Call transmission subroutine
            INY                 ; Move Y to next byte
            CPY     #WRTBYTEND
            BEQ     DONE        ; Branch until we hit $0000
            DECB                ; One more byte printed
            BEQ     PRNT_ADDR   ; Start the next row of bytes
            LDA     #' '        ; Print whitespace…
            CMPB    #$08
            BNE     ONE_SPC     
            BSR     SCI_OUT     ; …two between groups of 8 bytes…
ONE_SPC:    BSR     SCI_OUT     ; …one otherwise.
            BRA     READ_BYTE   ; Move along
            
DONE        BRCLR   SCSR,X TDRE DONE    ; Wait for transmit to complete
            LDAA    #$00        ; Disable transmitter (TE=0, RE=0)
            STAA    SCCR2,X     ; (the BRA means we'll never get here)
            STOP

; ----------------------------------------------------------------
; Subroutine: PRNTBYTE
; Inputs: Accumulator A contains a byte to be transmitted as
;         text.
; ----------------------------------------------------------------
PRNTBYTE    PSHA                ; Save a copy for the lower nibble
            LSRA                
            LSRA
            LSRA
            LSRA                ; A >>= 4 (high nibble)
            BSR     PRNTHEX
            PULA
            ANDA    #$0F        ; A &= 0xF (lower nibble)
            ; Fall through to PRNTHEX…

PRNTHEX     CMPA    #10
            BLT     DECML
            ADDA    #'A'-'0'-10 ; Shift 10-15 where adding '0' gets
                                ; the character to A-F
DECML       ADDA    #'0'
            ; Fall through to SCI_OUT…

; ----------------------------------------------------------------
; Subroutine: OUTCHAR
; Inputs: Accumulator A contains the ASCII character to transmit
; ----------------------------------------------------------------
SCI_OUT     BRCLR   SCSR,X TDRE SCI_OUT  ; Poll SCSR until TDRE flag is 1
            STAA    SCDR,X          ; Write character to SCDR (clears TDRE)
            RTS                     ; Return from subroutine


            DB      $0100 - * DUP ($FF)