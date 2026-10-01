
            CPU     6811
            
            INCLUDE ../io_regs.s

; ~1200 Baud for 8 MHz crystal/2 MHz clock:
BAUD1200    EQU     $33

; Status Register Bit Mask
TDRE        EQU   	$80       	; Transmit Data Register Empty flag mask

            ORG     $0000       ; Start of program (assume ROM/EPROM)

            DB      $FF         ; Baud determinator prefix byte
            
; ----------------------------------------------------------------
; Main Program Initialization
; ----------------------------------------------------------------
MAIN        LDS     #$00FF      ; Initialize stack pointer
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
AGAIN       LDY     #HELLOSTR
            LDAB    #HELLOSTREND - HELLOSTR
            
SEND_STR    LDAA    $00,Y       ; Load character 'H' into Accumulator A
            BSR     SCI_OUT     ; Call transmission subroutine
            INY                 ; Move Y to next character
            DECB                ; Decrement character count
            BNE     SEND_STR

            BRA     AGAIN       ; Infinite loop when finished
            
            LDAA    #$00        ; Disable transmitter (TE=0, RE=0)
            STAA    SCCR2,X     ; (the BRA means we'll never get here)
            STOP

; ----------------------------------------------------------------
; Subroutine: OUTCHAR
; Inputs: Accumulator A contains the ASCII character to transmit
; ----------------------------------------------------------------
SCI_OUT     BRCLR   SCSR,X TDRE SCI_OUT  ; Poll SCSR until TDRE flag is 1
            STAA    SCDR,X          ; Write character to SCDR (clears TDRE)
            RTS                     ; Return from subroutine

HELLOSTR:   DB      'Hello, world.\n\n'
HELLOSTREND:DB      $0101 - * DUP ($FF)
