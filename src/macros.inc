; ============================================
; Stellar Assault - Macros
; ============================================

; SetPPUAddress - Set PPU address for read/write
; Usage: SetPPUAddress $2000
MACRO SetPPUAddress
  BIT PPUSTATUS    ; Reset latch
  LDA #>(\1)       ; High byte
  STA PPUADDR
  LDA #<(\1)       ; Low byte
  STA PPUADDR
ENDM

; SetScroll - Set scroll position
; Usage: SetScroll scroll_x, scroll_y
MACRO SetScroll
  BIT PPUSTATUS    ; Reset latch
  LDA \1
  STA PPUSCROLL    ; X scroll
  LDA \2
  STA PPUSCROLL    ; Y scroll
ENDM

; WaitForVBlank - Wait for VBlank to occur
MACRO WaitForVBlank
@wait:
  BIT PPUSTATUS
  BPL @wait
ENDM

; EnableNMI - Enable NMI interrupts
MACRO EnableNMI
  LDA #%10010000   ; Enable NMI, sprites from pattern table 0
  STA PPUCTRL
ENDM

; DisableNMI - Disable NMI interrupts
MACRO DisableNMI
  LDA #%00000000
  STA PPUCTRL
ENDM

; EnableRendering - Enable sprite and background rendering
MACRO EnableRendering
  LDA #%00011110   ; Enable sprites, background, show leftmost 8 pixels
  STA PPUMASK
ENDM

; DisableRendering - Disable rendering
MACRO DisableRendering
  LDA #%00000000
  STA PPUMASK
ENDM

; ClearOAM - Clear OAM buffer (set all Y positions to $FF)
MACRO ClearOAM
  LDX #0
  LDA #$FF
@loop:
  STA oam_buffer,X
  INX
  INX
  INX
  INX
  BNE @loop
ENDM

; UpdateOAM - Trigger OAM DMA
MACRO UpdateOAM
  LDA #$00
  STA OAMADDR
  LDA #>oam_buffer
  STA OAMDMA
ENDM

; Add16 - Add 16-bit value
; Usage: Add16 var_lo, var_hi, value_lo, value_hi
MACRO Add16
  CLC
  LDA \1
  ADC \3
  STA \1
  LDA \2
  ADC \4
  STA \2
ENDM

; Sub16 - Subtract 16-bit value
; Usage: Sub16 var_lo, var_hi, value_lo, value_hi
MACRO Sub16
  SEC
  LDA \1
  SBC \3
  STA \1
  LDA \2
  SBC \4
  STA \2
ENDM

; Cmp16 - Compare 16-bit value (sets flags)
; Usage: Cmp16 var_lo, var_hi, value_lo, value_hi
; Correctly compares high byte first, then low byte if high bytes are equal
; Sets N/Z/C flags as if comparing a 16-bit value
MACRO Cmp16
  LDA \2        ; Compare high bytes first
  CMP \4
  BNE @done     ; If not equal, flags are already correct
  LDA \1        ; High bytes equal, compare low bytes
  CMP \3
@done:
ENDM

; MemCopy - Copy N bytes from source to destination
; Usage: MemCopy source, dest, count
MACRO MemCopy
  LDX #0
@loop:
  LDA \1,X
  STA \2,X
  INX
  CPX #\3
  BNE @loop
ENDM

; MemSet - Set N bytes to value
; Usage: MemSet dest, value, count
MACRO MemSet
  LDA #\2
  LDX #0
@loop:
  STA \1,X
  INX
  CPX #\3
  BNE @loop
ENDM
