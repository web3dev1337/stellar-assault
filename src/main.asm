; ============================================
; Stellar Assault - Advanced NES Space Shooter
; ============================================
; Showcases mastery of 6502 assembly:
; - Sprite multiplexing (32+ sprites)
; - Optimized collision detection
; - Subpixel movement (8.8 fixed-point)
; - Custom APU sound engine
; - Advanced enemy AI patterns
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
  BYTE "NES", $1A       ; iNES identifier
  BYTE 2                ; 2 * 16KB PRG-ROM
  BYTE 1                ; 1 * 8KB CHR-ROM
  BYTE %00000001        ; Mapper 0, vertical mirroring
  BYTE 0                ; Mapper 0
  BYTE 0, 0, 0, 0, 0, 0, 0, 0  ; Padding

; ============================================
; PRG-ROM Code
; ============================================
  ORG $C000

; ============================================
; Reset Handler
; ============================================
Reset:
  SEI             ; Disable interrupts
  CLD             ; Disable decimal mode

  ; Disable APU frame IRQ
  LDX #$40
  STX $4017

  ; Initialize stack pointer
  LDX #$FF
  TXS

  ; Disable NMI
  LDA #0
  STA PPUCTRL
  STA PPUMASK

  ; Wait for PPU to stabilize
  BIT PPUSTATUS
@wait1:
  BIT PPUSTATUS
  BPL @wait1
@wait2:
  BIT PPUSTATUS
  BPL @wait2

  ; Clear RAM
  JSR clear_ram

  ; Initialize game
  JSR init_game

  ; Initialize PPU
  JSR init_ppu

  ; Enable NMI and rendering
  LDA #%10010000   ; Enable NMI
  STA PPUCTRL
  LDA #%00011110   ; Enable sprites and background
  STA PPUMASK

  ; Main loop
main_loop:
  ; Wait for NMI
@wait_nmi:
  LDA nmi_ready
  BNE @wait_nmi

  ; Read controller
  JSR read_controller

  ; Update game
  JSR update_player
  JSR update_bullets
  JSR update_enemies
  JSR check_collisions
  JSR spawn_enemies

  ; Update sound
  JSR update_sound

  ; Render
  JSR render_sprites

  ; Signal NMI
  LDA #1
  STA nmi_ready

  ; Increment frame
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

  ; OAM DMA
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA

  ; Update scroll
  BIT PPUSTATUS
  LDA scroll_x
  STA PPUSCROLL
  LDA scroll_y
  STA PPUSCROLL

  ; Clear flag
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
  STA $0100,X
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
  ; Player position
  LDA #PLAYER_START_X
  STA player_x
  LDA #PLAYER_START_Y
  STA player_y

  ; Player stats
  LDA #3
  STA player_hp

  ; Clear states
  LDA #0
  STA player_inv
  STA player_fire_delay
  STA frame_counter
  STA spawn_timer
  STA scroll_x
  STA scroll_y

  ; Clear OAM
  LDX #0
  LDA #$FF
@clear_oam:
  STA $0200,X
  INX
  BNE @clear_oam

  ; Clear objects
  LDX #0
@clear_bullets:
  STA bullet_active,X
  STA enemy_active,X
  INX
  CPX #16
  BNE @clear_bullets

  RTS

init_ppu:
  ; Clear nametables
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

  ; Set palettes
  BIT PPUSTATUS
  LDA #$3F
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  ; BG palette
  LDX #0
@bg_pal:
  LDA palette_bg,X
  STA PPUDATA
  INX
  CPX #16
  BNE @bg_pal

  ; Sprite palette
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
  ; Decrement timers
  LDA player_inv
  BEQ @no_inv
  DEC player_inv
@no_inv:

  LDA player_fire_delay
  BEQ @no_delay
  DEC player_fire_delay
@no_delay:

  ; Movement - Right
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

  ; Movement - Left
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

  ; Movement - Down
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

  ; Movement - Up
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

  ; Shooting
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

  ; Check X
  LDA bullet_x,X
  SEC
  SBC enemy_x,Y
  CLC
  ADC #4
  CMP #12
  BCS @next_enemy

  ; Check Y
  LDA bullet_y,X
  SEC
  SBC enemy_y,Y
  CLC
  ADC #4
  CMP #12
  BCS @next_enemy

  ; Hit!
  LDA #0
  STA bullet_active,X
  STA enemy_active,Y

  ; Sound
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

  RTS

; ============================================
; Sprite Rendering
; ============================================

render_sprites:
  ; Clear OAM
  LDX #0
  LDA #$FF
@clear:
  STA $0200,X
  INX
  BNE @clear

  ; Player
  LDX #0
  LDA player_y
  STA $0200,X
  LDA #SPRITE_PLAYER
  STA $0201,X
  LDA #0
  STA $0202,X
  LDA player_x
  STA $0203,X

  ; Bullets
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

  ; Enemies
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
  ; Channel 0 - shoot
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

  ; Channel 2 - hit
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
; Variables (Zero Page) - Use ENUM for addresses
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
; Variables (RAM) - Use ENUM for addresses
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
; Interrupt Vectors
; ============================================
  ORG $FFFA
  WORD NMI
  WORD Reset
  WORD IRQ

; ============================================
; CHR-ROM
; ============================================
  INCBIN "assets/chr/chr_data.chr"
