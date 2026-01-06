; Minimal NES ROM to test basic execution
  BYTE "NES", $1A
  BYTE 1    ; 1 PRG bank
  BYTE 1    ; 1 CHR bank
  BYTE 0    ; Mapper 0, horizontal mirroring  
  BYTE 0, 0, 0, 0, 0, 0, 0, 0, 0

  ORG $8000

Reset:
  SEI
  CLD
  
  ; Write test value to zero page
  LDA #$42
  STA $00    ; Store $42 at address $00
  
  LDA #$99
  STA $01    ; Store $99 at address $01

Loop:
  INC $00    ; Increment byte at $00 every frame
  JMP Loop

NMI:
  RTI

IRQ:
  RTI

  PAD $BFFA
  WORD NMI
  WORD Reset
  WORD IRQ

  INCBIN "assets/chr/chr_data.chr"
