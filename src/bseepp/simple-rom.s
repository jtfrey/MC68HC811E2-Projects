            CPU     6811
            
            INCLUDE ../io_regs.s

; ~1200 Baud for 8 MHz crystal/2 MHz clock:
BAUD1200    EQU     $33

            ORG     $FF97
RESET:
            LDS     #$00FF                      ; Stack at top of 256B RAM
            LDX     #$1000                      ; X <- base address i/o registers
            BSET    $28, X, #$20                ; Set Port D Wired-OR Mode
            LDAA    #$A2 | $33                  ; Default Baud = 7813 @ 2 MHz Eclock
            STAA    $2B, X                      ; Set serial baud rate
            LDAA    #$0C                        ; TE | RE
            STAA    $2D, X                      ; Enable transmit and receive
            BSET    $2D, X, #$01                ; Send a break
L0          BRSET   $08, X, #$01, L0            ; Loop until Tx pin is ready
            BCLR    $2D, X, #$01                ; Stop sending breaks

GO          LDAA    #'0'
WAIT        BRCLR   SCSR,X #$80 WAIT
            STAA    SCDR,X
            ADDA    #1
            ANDA    #$37 
            BRA     WAIT

            ORG     $FFC0
            
            DB      ($FFFE-$FFC0) DUP $FF
            DW      RESET
