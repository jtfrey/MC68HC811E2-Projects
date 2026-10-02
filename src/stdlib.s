;
; stdlib.s
; Library of standard subroutines
;


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
                BSR         WRTADDR             ; WRTADDR prints a leading $ and the address in D
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
; Subroutine: WRTNLCSTR/WRTCSTR
; Write a NUL-terminated string to the SCI.  The WRTNLCSTR entry
; point writes a newline character preceeding the string.
; Inputs:
;     X:    IOREGS base
;     Y:    address of string
;
; On exit the address in Y points to the NUL character.
; Accumulator A is clobbered by the routine.
; ----------------------------------------------------------------
WRTNLCSTR       LDAA        #'\n'
                BSR         SCI_OUT             ; Write a newline first
WRTCSTR         LDAA        $00, Y              ; A <- next character
                BEQ         WRTCSTR_DONE
                BSR         SCI_OUT             ; Write to SCI
                INY                             ; Increment address
                BRA         WRTCSTR             ; Handle the next character
WRTCSTR_DONE    RTS

; ----------------------------------------------------------------
; Subroutine: WRTNLSTRN/WRTSTRN
; Write a string of length N to the SCI.   WRTNLSTRN entry
; point writes a newline character preceeding the string.
; Inputs:
;     X:    IOREGS base
;     Y:    address of string
;     A:    number of characters (must be > 0)
;
; On exit the address in Y points just past the last character.
; Accumulators A and B are clobbered by the routine.
; ----------------------------------------------------------------
WRTNLSTRN       LDAA        #'\n'
                BSR         SCI_OUT             ; Write a newline first
WRTSTRN         LDAB        $00, Y              ; B <- next character
                BSR         SCI_OUT             ; Write to SCI
                INY                             ; Increment address
                DECA                            ; Decrement count
                BNE         WRTSTRN             ; Next character if count != 0
                RTS

; ----------------------------------------------------------------
; Subroutine: WRTADDR
; Convert the address in D to text and write the four characters to
; the SCI, prefixed by a dollar sign ($).  The high byte of the
; address in D comes from A, the low byte from B.
; Inputs:
;     X:    IOREGS base
;     D:    Word value to output
;
; On exit the original value of D is clobbered.
; ----------------------------------------------------------------
WRTADDR         PSHA                            ; Stash high-byte of address word
                LDAA        #'$'                ; A <- '$'
                BSR         SCI_OUT             ; Write to SCI
                PULA                            ; Restore original A
                ; Fall through to WRTWORD

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

; ----------------------------------------------------------------
; Subroutine: SCI_IN
; Inputs:
;     X:    IOREGS base
; On exit the byte read from the SCI.
; ----------------------------------------------------------------
SCI_IN          BRCLR   SCSR,X RDRF SCI_IN      ; Poll SCSR until RDRF flag is 1
                LDAA    SCDR,X                  ; Read character from SCDR (clears TDRE)
                RTS