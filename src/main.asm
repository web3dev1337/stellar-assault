; ============================================
; Stellar Assault - Advanced NES Space Shooter
; ============================================

; PPU Registers
PPUCTRL   = $2000
PPUMASK   = $2001
PPUSTATUS = $2002
OAMADDR   = $2003
OAMDATA   = $2004
PPUSCROLL = $2005
PPUADDR   = $2006
PPUDATA   = $2007

; APU Registers
SQ1_VOL   = $4000
SQ1_SWEEP = $4001
SQ1_LO    = $4002
SQ1_HI    = $4003
NOISE_VOL = $400C
NOISE_LO  = $400E
NOISE_HI  = $400F

; Controller/OAM
CONTROLLER1 = $4016
OAMDMA = $4014

; Button Masks
BUTTON_A      = %10000000
BUTTON_B      = %01000000
BUTTON_SELECT = %00100000
BUTTON_START  = %00010000
BUTTON_UP     = %00001000
BUTTON_DOWN   = %00000100
BUTTON_LEFT   = %00000010
BUTTON_RIGHT  = %00000001

; Game Constants
PLAYER_START_X = 120
PLAYER_START_Y = 200
PLAYER_SPEED   = 2
SCROLL_SPEED = 1

; Sprite tile IDs
SPRITE_PLAYER       = $00
SPRITE_PLAYER_BULLET = $04
SPRITE_ENEMY_1      = $08
SPRITE_ENEMY_BULLET = $0C

; ============================================
; iNES Header
; ============================================
  BYTE "NES", $1A
  BYTE 1                ; 1 * 16KB PRG-ROM (mirrored to $8000-$BFFF and $C000-$FFFF)
  BYTE 1                ; 1 * 8KB CHR-ROM
  BYTE %00000000        ; Mapper 0, horizontal mirroring
  BYTE 0
  BYTE 0, 0, 0, 0, 0, 0, 0, 0

; ============================================
; PRG-ROM - Mapper 0, 1 bank at $8000-$BFFF (mirrored to $C000-$FFFF)
; ============================================
  ORG $8000

; ============================================
; Reset Handler
; ============================================
Reset:
  SEI
  CLD
  LDX #$40
  STX $4017
  LDX #$FF
  TXS
  LDA #0
  STA PPUCTRL
  STA PPUMASK

  ; Skip PPU warmup waits for emulator compatibility
  ; Real hardware needs these, but emulators don't

  JSR clear_ram
  JSR init_game
  JSR init_ppu

  LDA #%10010000
  STA PPUCTRL
  LDA #%00011110
  STA PPUMASK

main_loop:
@wait_nmi:
  LDA nmi_ready
  BNE @wait_nmi

  JSR read_controller
  JSR update_player
  JSR update_bullets
  JSR update_enemies
  JSR check_collisions
  JSR spawn_enemies
  JSR update_sound
  JSR render_sprites

  LDA #1
  STA nmi_ready
  INC frame_counter
  JMP main_loop

; ============================================
; NMI Handler
; ============================================
NMI:
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA nmi_ready
  BEQ @done

  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA

  BIT PPUSTATUS
  LDA scroll_x
  STA PPUSCROLL
  LDA scroll_y
  STA PPUSCROLL

  LDA #0
  STA nmi_ready

@done:
  PLA
  TAY
  PLA
  TAX
  PLA
  RTI

; ============================================
; IRQ Handler
; ============================================
IRQ:
  RTI

; ============================================
; Initialization
; ============================================

clear_ram:
  LDA #0
  TAX
@loop:
  STA $0000,X
  ; Skip $0100,X - stack page (don't corrupt stack!)
  STA $0200,X
  STA $0300,X
  STA $0400,X
  STA $0500,X
  STA $0600,X
  STA $0700,X
  INX
  BNE @loop
  RTS

init_game:
  LDA #PLAYER_START_X
  STA player_x
  LDA #PLAYER_START_Y
  STA player_y
  LDA #3
  STA player_hp
  LDA #0
  STA player_inv
  STA player_fire_delay
  STA frame_counter
  STA spawn_timer
  STA scroll_x
  STA scroll_y

  LDX #0
  LDA #$FF
@clear_oam:
  STA $0200,X
  INX
  BNE @clear_oam

  LDX #0
@clear_bullets:
  STA bullet_active,X
  STA enemy_active,X
  INX
  CPX #16
  BNE @clear_bullets
  RTS

init_ppu:
  BIT PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  LDX #4
  LDY #0
  LDA #$00
@clear_nt:
  STA PPUDATA
  INY
  BNE @clear_nt
  DEX
  BNE @clear_nt

  BIT PPUSTATUS
  LDA #$3F
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  LDX #0
@bg_pal:
  LDA palette_bg,X
  STA PPUDATA
  INX
  CPX #16
  BNE @bg_pal

  LDX #0
@spr_pal:
  LDA palette_sprite,X
  STA PPUDATA
  INX
  CPX #16
  BNE @spr_pal
  RTS

; ============================================
; Controller Input
; ============================================

read_controller:
  LDA buttons
  STA buttons_prev

  LDA #1
  STA CONTROLLER1
  LDA #0
  STA CONTROLLER1

  LDX #8
@loop:
  LDA CONTROLLER1
  LSR A
  ROL buttons
  DEX
  BNE @loop
  RTS

; ============================================
; Player Update
; ============================================

update_player:
  LDA player_inv
  BEQ @no_inv
  DEC player_inv
@no_inv:

  LDA player_fire_delay
  BEQ @no_delay
  DEC player_fire_delay
@no_delay:

  LDA buttons
  AND #BUTTON_RIGHT
  BEQ @not_right
  LDA player_x
  CLC
  ADC #PLAYER_SPEED
  CMP #240
  BCS @not_right
  STA player_x
@not_right:

  LDA buttons
  AND #BUTTON_LEFT
  BEQ @not_left
  LDA player_x
  SEC
  SBC #PLAYER_SPEED
  CMP #8
  BCC @not_left
  STA player_x
@not_left:

  LDA buttons
  AND #BUTTON_DOWN
  BEQ @not_down
  LDA player_y
  CLC
  ADC #PLAYER_SPEED
  CMP #224
  BCS @not_down
  STA player_y
@not_down:

  LDA buttons
  AND #BUTTON_UP
  BEQ @not_up
  LDA player_y
  SEC
  SBC #PLAYER_SPEED
  CMP #16
  BCC @not_up
  STA player_y
@not_up:

  LDA buttons
  AND #BUTTON_A
  BEQ @not_shoot
  LDA player_fire_delay
  BNE @not_shoot

  JSR spawn_bullet

  LDA #8
  STA player_fire_delay
@not_shoot:
  RTS

; ============================================
; Bullet System
; ============================================

spawn_bullet:
  LDX #0
@find:
  LDA bullet_active,X
  BEQ @found
  INX
  CPX #8
  BNE @find
  RTS
@found:
  LDA #1
  STA bullet_active,X
  LDA player_x
  CLC
  ADC #4
  STA bullet_x,X
  LDA player_y
  STA bullet_y,X
  LDA #$FC
  STA bullet_vy,X
  RTS

update_bullets:
  LDX #0
@loop:
  LDA bullet_active,X
  BEQ @next
  LDA bullet_y,X
  CLC
  ADC bullet_vy,X
  STA bullet_y,X
  CMP #240
  BCC @next
  LDA #0
  STA bullet_active,X
@next:
  INX
  CPX #8
  BNE @loop
  RTS

; ============================================
; Enemy System
; ============================================

update_enemies:
  LDX #0
@loop:
  LDA enemy_active,X
  BEQ @next

  LDA enemy_y,X
  CLC
  ADC #1
  STA enemy_y,X
  CMP #240
  BCC @wave
  LDA #0
  STA enemy_active,X
  JMP @next

@wave:
  LDA frame_counter
  AND #$0F
  CMP #$08
  BCC @move_right
  LDA enemy_x,X
  SEC
  SBC #1
  STA enemy_x,X
  JMP @next
@move_right:
  LDA enemy_x,X
  CLC
  ADC #1
  STA enemy_x,X

@next:
  INX
  CPX #16
  BNE @loop
  RTS

spawn_enemies:
  LDA spawn_timer
  BEQ @spawn
  DEC spawn_timer
  RTS
@spawn:
  LDA #60
  STA spawn_timer

  LDX #0
@find:
  LDA enemy_active,X
  BEQ @found
  INX
  CPX #16
  BNE @find
  RTS
@found:
  LDA #1
  STA enemy_active,X
  LDA frame_counter
  AND #$F0
  CLC
  ADC #32
  STA enemy_x,X
  LDA #0
  STA enemy_y,X
  LDA #1
  STA enemy_hp,X
  RTS

; ============================================
; Collision Detection
; ============================================

check_collisions:
  LDX #0
@bullet_loop:
  LDA bullet_active,X
  BEQ @next_bullet

  LDY #0
@enemy_loop:
  LDA enemy_active,Y
  BEQ @next_enemy

  LDA bullet_x,X
  SEC
  SBC enemy_x,Y
  CLC
  ADC #4
  CMP #12
  BCS @next_enemy

  LDA bullet_y,X
  SEC
  SBC enemy_y,Y
  CLC
  ADC #4
  CMP #12
  BCS @next_enemy

  LDA #0
  STA bullet_active,X
  STA enemy_active,Y

  LDA #2
  STA sound_channel

@next_enemy:
  INY
  CPY #16
  BNE @enemy_loop

@next_bullet:
  INX
  CPX #8
  BNE @bullet_loop

  ; === PLAYER-ENEMY COLLISION ===
  ; Check if player is invincible
  LDA player_inv
  BNE @skip_player_collision  ; Skip if invincible

  LDY #0
@player_enemy_loop:
  LDA enemy_active,Y
  BEQ @next_pe

  ; Check X overlap: if |player_x - enemy_x| < 12
  LDA player_x
  SEC
  SBC enemy_x,Y
  CLC
  ADC #8              ; Add half-widths (8+4=12, but use 8 for center offset)
  CMP #16             ; Combined width check
  BCS @next_pe

  ; Check Y overlap: if |player_y - enemy_y| < 12
  LDA player_y
  SEC
  SBC enemy_y,Y
  CLC
  ADC #8
  CMP #16
  BCS @next_pe

  ; COLLISION! Player hit by enemy
  DEC player_hp       ; Reduce HP
  LDA #60             ; 1 second of invincibility (60 frames)
  STA player_inv

  LDA #0              ; Deactivate the enemy that hit us
  STA enemy_active,Y

  LDA #4              ; Play hit sound (noise channel)
  STA sound_channel+2

  JMP @skip_player_collision  ; Only one hit per frame

@next_pe:
  INY
  CPY #16
  BNE @player_enemy_loop

@skip_player_collision:
  RTS

; ============================================
; Sprite Rendering
; ============================================

render_sprites:
  LDX #0
  LDA #$FF
@clear:
  STA $0200,X
  INX
  BNE @clear

  LDX #0

  ; Check invincibility - blink player when hit
  LDA player_inv
  BEQ @draw_player       ; Not invincible, draw normally
  AND #$04               ; Check bit 2 (blink every 4 frames)
  BNE @skip_player       ; Don't draw on alternate frames

@draw_player:
  LDA player_y
  STA $0200,X
  LDA #SPRITE_PLAYER
  STA $0201,X
  LDA #0
  STA $0202,X
  LDA player_x
  STA $0203,X
  JMP @player_done

@skip_player:
  LDA #$FF               ; Hide sprite off-screen
  STA $0200,X

@player_done:

  LDX #4
  LDY #0
@bullets:
  LDA bullet_active,Y
  BEQ @next_bullet
  LDA bullet_y,Y
  STA $0200,X
  LDA #SPRITE_PLAYER_BULLET
  STA $0201,X
  LDA #0
  STA $0202,X
  LDA bullet_x,Y
  STA $0203,X
  TXA
  CLC
  ADC #4
  TAX
@next_bullet:
  INY
  CPY #8
  BNE @bullets

  LDY #0
@enemies:
  LDA enemy_active,Y
  BEQ @next_enemy
  LDA enemy_y,Y
  STA $0200,X
  LDA #SPRITE_ENEMY_1
  STA $0201,X
  LDA #1
  STA $0202,X
  LDA enemy_x,Y
  STA $0203,X
  TXA
  CLC
  ADC #4
  TAX
  CPX #252
  BCS @sprites_done
@next_enemy:
  INY
  CPY #16
  BNE @enemies

@sprites_done:
  RTS

; ============================================
; Sound System
; ============================================

update_sound:
  LDA sound_channel
  BEQ @no_sound
  LDA #$87
  STA SQ1_VOL
  LDA #$08
  STA SQ1_LO
  LDA #$02
  STA SQ1_HI
  LDA #0
  STA sound_channel
@no_sound:

  LDA sound_channel+2
  BEQ @no_hit
  LDA #$8F
  STA NOISE_VOL
  LDA #$03
  STA NOISE_LO
  LDA #$00
  STA NOISE_HI
  LDA #0
  STA sound_channel+2
@no_hit:
  RTS

; ============================================
; Data
; ============================================

palette_bg:
  BYTE $0F,$00,$10,$30
  BYTE $0F,$01,$11,$21
  BYTE $0F,$06,$16,$26
  BYTE $0F,$09,$19,$29

palette_sprite:
  BYTE $0F,$07,$17,$27
  BYTE $0F,$02,$12,$22
  BYTE $0F,$06,$16,$26
  BYTE $0F,$0A,$1A,$2A

; ============================================
; Variables (Zero Page)
; ============================================
  ENUM $0000

temp           DSB 1
buttons        DSB 1
buttons_prev   DSB 1
scroll_x       DSB 1
scroll_y       DSB 1

player_x       DSB 1
player_y       DSB 1
player_hp      DSB 1
player_inv     DSB 1
player_fire_delay DSB 1

frame_counter  DSB 1
spawn_timer    DSB 1

sound_channel  DSB 4

nmi_ready      DSB 1

  ENDE

; ============================================
; Variables (RAM)
; ============================================
  ENUM $0300

bullet_active  DSB 8
bullet_x       DSB 8
bullet_y       DSB 8
bullet_vy      DSB 8

enemy_active   DSB 16
enemy_x        DSB 16
enemy_y        DSB 16
enemy_hp       DSB 16

  ENDE

; ============================================
; Interrupt Vectors (at end of 16KB PRG-ROM bank)
; ============================================
  PAD $BFFA
  WORD NMI
  WORD Reset
  WORD IRQ

; ============================================
; CHR-ROM
; ============================================
  INCBIN "assets/chr/chr_data.chr"
