
            CPU     6811
            
            INCLUDE ../io_regs.s


            ORG     $0000       ; Start of program (assume ROM/EPROM)
            
; ----------------------------------------------------------------
; Main Program Initialization
; ----------------------------------------------------------------
MAIN        LDS     #$00FF      ; Initialize stack pointer at top of RAM
            LDX     #IOREGS     ; Load X register with base address of I/O registers

; ----------------------------------------------------------------
; Runloop
; ----------------------------------------------------------------
NEXTCMD     JSR     PROMPT
            CLRA
            CLRB
            STD     OPCHAR
            STD     OPCHAR + 2
            STD     OPCHAR + 4
            
NEXTCHAR    BSR     SCI_IN
            JSR     SCI_OUT
            CMPA    #'\n'                       ; Return?
            BEQ     DO_CMD
            TAB                                 ; Stash a copy in B
            
            ANDA    #$F0
            CMPA    #$30                        ; High nibble is 0x30 for [0-9:=]
            BEQ     CHARSET1
            CMPA    #$40                        ; High nibble is 0x40 for A-F
            BEQ     CHARSET2
NOMATCHCHAR STAB    OPCHAR                      ; Store the operation character
            BRA     NEXTCHAR

CHARSET1    CMPB    #'9'
            BLE     CHARSET09
CHARSET2    CMPB    #'F'
            BGT     NOMATCHCHAR
            CMPB    #'A'
            BLT     NOMATCHCHAR
CHARSETAF   ADDB    #9
CHARSET09   ANDB    #$0F                        ; '0'…'9' => [0,9]; 'A'…'F' => [10, 15]
            ;
            ; At this point B contains the new hex digit to
            ; insert; do a 5-byte multiply by 16 to make room
            ; then OR it into the trailing byte:
            ;
            LDAA    #4
            LDY     #ADDR43
SHIFT       LSL     $04, Y
            ROL     $03, Y
            ROL     $02, Y
            ROL     $01, Y
            ROL     $00, Y
            DECA
            BNE     SHIFT
            ORAB    ADDR0
            STAB    ADDR0
            BRA     NEXTCHAR

DO_CMD      LDAA    OPCHAR
            BEQ     DO_DUMP_1
            CMPA    #'.'
            BEQ     DO_DUMP_N
            CMPA    #'='
            BEQ     DO_SET
            CMPA    #'R'
            BNE     NEXTCMD
DO_RUN      LDY     ADDR21
            PSHY
            RTS
DO_SET      LDY     ADDR21
            LDAA    ADDR0
            STAA    $00, Y
NEXTCMD_JMP BRA     NEXTCMD
DO_DUMP_1   LDD     #1
            LDY     ADDR21+1
            BSR     MEMDUMPLEN
            BRA     NEXTCMD
DO_DUMP_N   LDY     ADDR43+1
            LDD     ADDR21+1
            BSR     MEMDUMPRANGE
            BRA     NEXTCMD_JMP

OPCHAR          DB          $00
ADDR43          DW          $0000
ADDR21          DW          $0000
ADDR0           DB          $00
WORD0           DW          $0000

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
; Subroutine: MEMDUMPLEN/MEMDUMPRANGE
; Starting from the address in Y, convert as many bytes of memory
; as indicated in D (for MEMDUMPLEN) or up to the byte before D
; (for MEMDUMPRANGE).
; Inputs:
;     X:    IOREGS base
;     Y:    base address of memory dump
;     D:    number of bytes to dump/end address
;
; Uses variable WORD0 for the end address.
;
; On exit the address in Y points just past the last byte output.
; Accumulators A and B are clobbered by the routine.
; ----------------------------------------------------------------
MEMDUMPLEN      STY         WORD0               ; WORD0 <- Y
                ADDD        WORD0               ; D <- D + Y
MEMDUMPRANGE    STD         WORD0               ; WORD0 <- D (= D + Y from MEMDUMPLEN)
MEMDUMP_ADDR    PSHY                            ; Stash a copy of the current address
                XGDY                            ; D <-> Y
                BSR         WRTWORD             ; WRTWORD prints the address in D
                LDA         #':'
                BSR         SCI_OUT             ; Colon between address and bytes on this line
                PULY                            ; Get back our current address
                LDAB        #16                 ; B <- 16 byte counter
MEMDUMP_BYTE    LDAA        $00, Y              ; A <- next byte from memory
                BSR         WRTBYTE             ; WRTBYTE writes the byte in A
                INY                             ; Y++
                CPY         WORD0               ; Has Y reached the ending address in WORD0?
                BEQ         MEMDUMP_DONE        ; Yes, we are done!
                DECB                            ; B-- (byte counter)
                BNE         MEMDUMP_SAMELN      ; Did we print all 16 bytes yet?
                LDAA        #'\n'               ; Yes, newline then go print the next address
                BSR         SCI_OUT
                BRA         MEMDUMP_ADDR
MEMDUMP_SAMELN  LDAA        #' '                ; A <- ' ' (space)
                CMPB        #8                  ; If the byte counter has reached 8 print 2 spaces
                BNE         MEMDUMP_ONESPC
                BSR         SCI_OUT
MEMDUMP_ONESPC  BSR         SCI_OUT
                BRA         MEMDUMP_BYTE        ; Go handle the next bye
MEMDUMP_DONE    RTS

; ----------------------------------------------------------------
; Subroutine: WRTWORD
; Convert the word in D to text and write the four characters to
; the SCI.  The high byte of D comes from A, the low byte from B.
; Inputs:
;     X:    IOREGS base
;     D:    Word value to output
;
; On exit the original value of D is clobbered.
; ----------------------------------------------------------------
WRTWORD         BSR     WRTBYTE                 ; A is the high byte of D, so
                                                ; we want to output it first
                                                ; anyway
                TBA                             ; Move B (low byte) to A
                ; Fall through to WRTBYTE…

; ----------------------------------------------------------------
; Subroutine: WRTBYTE
; Convert the byte in A to text and write the two characters to
; the SCI.
; Inputs:
;     X:    IOREGS base
;     A:    Byte value to output
;
; On exit the original value of A is clobbered.
; ----------------------------------------------------------------
WRTBYTE         PSHA                            ; Save a copy for the lower nibble
                LSRA                
                LSRA
                LSRA
                LSRA                            ; A >>= 4 (high nibble)
                BSR     WRTHEX
                PULA
                ANDA    #$0F                    ; A &= 0xF (lower nibble)
                ; Fall through to WRTHEX…
            
; ----------------------------------------------------------------
; Subroutine: WRTHEX
; Convert a single hex digit in the low nibble of A (high nibble
; must be cleared!) to text and write the character to the SCI.
; Inputs:
;     X:    IOREGS base
;     A:    Hex digit as 0x0_
;
; On exit the original value of A is clobbered.
; ----------------------------------------------------------------
WRTHEX          CMPA    #10
                BLT     WRTHEX_DECML
                ADDA    #'A'-'0'-10             ; Shift 10-15 where adding '0' gets
                                                ; the character to A-F
WRTHEX_DECML    ADDA    #'0'                    ; Shift 0 to '0', taking A-F where they
                                                ; belong as well
                ; Fall through to SCI_OUT
            
; ----------------------------------------------------------------
; Subroutine: SCI_OUT
; Inputs:
;     X:    IOREGS base
;     A:    ASCII character to transmit
; No side effects.
; ----------------------------------------------------------------
SCI_OUT         BRCLR   SCSR,X TDRE SCI_OUT     ; Poll SCSR until TDRE flag is 1
                STAA    SCDR,X                  ; Write character to SCDR (clears TDRE)
                RTS
PROMPT          LDAA    #'\n'
                BSR     SCI_OUT
                LDAA    #'>'
                BRA     SCI_OUT

                DB $0100-* DUP $FF