; ----------------------------------------------------------------
; M68HC11E SCI Character Transmitter
; ----------------------------------------------------------------
;
; I/O Register Offsets (Standard M68HC11 Mapping)
;
IOREGS      EQU     $1000       ; Register block base address
PORTA       EQU     $00       	; Port A Data Register
PIOC        EQU     $02       	; Parallel I/O Control Register
PORTC       EQU     $03       	; Port C Data Register
PORTB       EQU     $04       	; Port B Data Register
PORTCL      EQU   	$05       	; Port C Latched Register
DDRC        EQU   	$07       	; Port C Data Direction Register
PORTD       EQU   	$08       	; Port D Data Register
DDRD        EQU   	$09       	; Port D Data Direction Register
PORTE       EQU   	$0A       	; Port E Data Register
CFORC       EQU   	$0B       	; Timer Compare Force Register
OC1M        EQU   	$0C       	; Output Compare 1 Mask Register
OC1D        EQU   	$0D       	; Output Compare 1 Data Register
TCNTH       EQU   	$0E       	; Timer Counter Register High
TCNTL       EQU   	$0F       	; Timer Counter Register Low
TIC1H       EQU   	$10         ; Timer Input Capture 1 Register High
TIC1L       EQU     $11         ; Timer Input Capture 1 Register Low
TIC2H       EQU   	$12         ; Timer Input Capture 2 Register High
TIC2L       EQU     $13         ; Timer Input Capture 2 Register Low
TIC3H       EQU   	$14         ; Timer Input Capture 3 Register High
TIC3L       EQU     $15         ; Timer Input Capture 3 Register Low
TOC1H       EQU   	$16         ; Timer Output Compare 1 Register High
TOC1L       EQU     $17         ; Timer Output Compare 1 Register Low
TOC2H       EQU   	$18         ; Timer Output Compare 2 Register High
TOC2L       EQU     $19         ; Timer Output Compare 2 Register Low
TOC3H       EQU   	$1A         ; Timer Output Compare 3 Register High
TOC3L       EQU     $1B         ; Timer Output Compare 3 Register Low
TOC4H       EQU   	$1C         ; Timer Output Compare 4 Register High
TOC4L       EQU     $1D         ; Timer Output Compare 4 Register Low
TI4_O5H     EQU     $1E         ; Timer Input Capture 5/Output Compare 5 Register High
TI4_O5L     EQU     $1F         ; Timer Input Capture 5/Output Compare 5 Register Low
TCTL1       EQU     $20         ; Timer Control Register 1
TCTL2       EQU     $21         ; Timer Control Register 2
TMSK1       EQU     $22         ; Timer Interrupt Mask 1 Register
TFLG1       EQU     $23         ; Timer Interrupt Flag 1
TMSK2       EQU     $24         ; Timer Interrupt Mask 2 Register
TFLG2       EQU     $25         ; Timer Interrupt Flag 2
PACTL       EQU     $26         ; Pulse Accumulator Control Register
PACNT       EQU     $27         ; Pulse Accumulator Count Register
SPCR        EQU     $28         ; Serial Peripheral Control Register
SPSR        EQU     $29         ; Serial Peripheral Status Register
SPDR        EQU     $2A         ; Serial Peripheral Data I/O Register
BAUD        EQU   	$2B       	; Baud Rate Register
SCCR1       EQU   	$2C       	; Serial Communications Control Register 1
SCCR2       EQU   	$2D       	; Serial Communications Control Register 2
SCSR        EQU   	$2E       	; Serial Communications Status Register
SCDR        EQU   	$2F       	; Serial Communications Data Register
ADCTL       EQU     $30         ; Analog-to-Digital Control Status Register
ADR1        EQU     $31         ; Analog-to-Digital Results Register 1
ADR2        EQU     $32         ; Analog-to-Digital Results Register 2
ADR3        EQU     $33         ; Analog-to-Digital Results Register 3
ADR4        EQU     $34         ; Analog-to-Digital Results Register 4
BPROT       EQU     $35         ; Block Protect Register
EPROG       EQU     $36         ; EPROM Programming Control Register
OPTION      EQU     $39         ; System Configuration Options Register
COPRST      EQU     $3A         ; Arm/Reset COP Timer Circuitry Register
PPROG       EQU     $3B         ; EPROM and EEPROM Programming and Control Register
HPRIO       EQU     $3C         ; Highest Priority I Bit Interrupt and Misc. Register
INIT        EQU     $3D         ; RAM and I/O Mapping Register
CONFIG      EQU     $3F         ; System Configuration Register
