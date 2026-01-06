; Minimal NES ROM test
  BYTE "NES", $1A
  BYTE 1    ; 1 PRG
  BYTE 1    ; 1 CHR  
  BYTE 1    ; Mapper 0, vertical
  BYTE 0, 0, 0, 0, 0, 0, 0, 0, 0

  ORG $C000
Reset:
  SEI
  CLD
  LDX #$FF
  TXS
  
  ; Set PPU to show background
  LDA #%10000000
  STA $2000
  LDA #%00011110  
  STA $2001

InfiniteLoop:
  JMP InfiniteLoop

NMI:
  RTI

IRQ:
  RTI

  PAD $FFFA
  WORD NMI
  WORD Reset
  WORD IRQ

  INCBIN "assets/chr/chr_data.chr"
