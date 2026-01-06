; ============================================
; Stellar Assault - Advanced NES Space Shooter
; A REAL game with score, lives, game over, powerups!
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
SQ2_VOL   = $4004
SQ2_SWEEP = $4005
SQ2_LO    = $4006
SQ2_HI    = $4007
TRI_CTRL  = $4008
TRI_LO    = $400A
TRI_HI    = $400B
NOISE_VOL = $400C
NOISE_LO  = $400E
NOISE_HI  = $400F
APU_STATUS = $4015

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
PLAYER_SPEED   = 3
SCROLL_SPEED = 1

; Game States
STATE_TITLE    = 0
STATE_PLAYING  = 1
STATE_GAMEOVER = 2
STATE_PAUSED   = 3

; Enemy Types
ENEMY_BASIC    = 1      ; Straight down with sine wave
ENEMY_FAST     = 2      ; Fast, straight down
ENEMY_SHOOTER  = 3      ; Shoots at player

; Sprite tile IDs
SPRITE_PLAYER       = $00
SPRITE_PLAYER_BULLET = $04
SPRITE_ENEMY_1      = $08
SPRITE_ENEMY_2      = $0C
SPRITE_ENEMY_BULLET = $10
SPRITE_POWERUP      = $14
SPRITE_EXPLOSION    = $18

; ============================================
; iNES Header
; ============================================
  BYTE "NES", $1A
  BYTE 1                ; 1 * 16KB PRG-ROM
  BYTE 1                ; 1 * 8KB CHR-ROM
  BYTE %00000000        ; Mapper 0, horizontal mirroring
  BYTE 0
  BYTE 0, 0, 0, 0, 0, 0, 0, 0

; ============================================
; PRG-ROM
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

  ; Enable APU channels
  LDA #%00001111
  STA APU_STATUS

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

  ; Check game state
  LDA game_state
  CMP #STATE_TITLE
  BEQ @title_state
  CMP #STATE_PLAYING
  BEQ @playing_state
  CMP #STATE_GAMEOVER
  BEQ @gameover_state
  JMP @end_update

@title_state:
  JSR update_title
  JMP @end_update

@playing_state:
  JSR update_player
  JSR update_bullets
  JSR update_enemies
  JSR update_enemy_bullets
  JSR update_powerups
  JSR update_explosions
  JSR check_collisions
  JSR spawn_enemies
  JSR check_game_over
  JMP @end_update

@gameover_state:
  JSR update_gameover
  JMP @end_update

@end_update:
  JSR update_sound
  JSR render_sprites
  JSR update_score_display

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

  ; Update score on screen (background tiles)
  JSR draw_hud

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
  LDA #STATE_TITLE
  STA game_state
  JSR reset_player
  RTS

reset_player:
  LDA #PLAYER_START_X
  STA player_x
  LDA #PLAYER_START_Y
  STA player_y
  LDA #3
  STA player_hp
  LDA #3
  STA player_lives
  LDA #0
  STA player_inv
  STA player_fire_delay
  STA frame_counter
  STA spawn_timer
  STA scroll_x
  STA scroll_y
  STA score_lo
  STA score_mid
  STA score_hi
  STA difficulty
  STA kill_count
  STA player_power

  LDX #0
  LDA #$FF
@clear_oam:
  STA $0200,X
  INX
  BNE @clear_oam

  LDX #0
  LDA #0
@clear_objects:
  STA bullet_active,X
  STA enemy_active,X
  STA enemy_bullet_active,X
  STA explosion_active,X
  STA powerup_active,X
  INX
  CPX #16
  BNE @clear_objects
  RTS

init_ppu:
  BIT PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$00
  STA PPUADDR

  ; Clear nametable
  LDX #4
  LDY #0
  LDA #$00
@clear_nt:
  STA PPUDATA
  INY
  BNE @clear_nt
  DEX
  BNE @clear_nt

  ; Load palettes
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

  ; Draw initial HUD text "SCORE" and "LIVES"
  JSR draw_hud_labels
  RTS

draw_hud_labels:
  ; Draw "SCORE:" at top left
  BIT PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$02
  STA PPUADDR
  LDA #'S'-$37
  STA PPUDATA
  LDA #'C'-$37
  STA PPUDATA
  LDA #'O'-$37
  STA PPUDATA
  LDA #'R'-$37
  STA PPUDATA
  LDA #'E'-$37
  STA PPUDATA

  ; Draw "HP:" at top right
  BIT PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$18
  STA PPUADDR
  LDA #'H'-$37
  STA PPUDATA
  LDA #'P'-$37
  STA PPUDATA
  RTS

; ============================================
; Title Screen
; ============================================

update_title:
  ; Check for START button
  LDA buttons
  AND #BUTTON_START
  BEQ @no_start
  LDA buttons_prev
  AND #BUTTON_START
  BNE @no_start

  ; Start game!
  LDA #STATE_PLAYING
  STA game_state
  JSR reset_player
  JSR play_start_sound

@no_start:
  RTS

; ============================================
; Game Over
; ============================================

update_gameover:
  ; Check for START to restart
  LDA buttons
  AND #BUTTON_START
  BEQ @no_restart
  LDA buttons_prev
  AND #BUTTON_START
  BNE @no_restart

  ; Restart game
  LDA #STATE_PLAYING
  STA game_state
  JSR reset_player
  JSR play_start_sound

@no_restart:
  RTS

check_game_over:
  LDA player_lives
  BNE @not_over
  LDA #STATE_GAMEOVER
  STA game_state
  JSR play_gameover_sound
@not_over:
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
  ; Decrease invincibility
  LDA player_inv
  BEQ @no_inv
  DEC player_inv
@no_inv:

  ; Decrease fire delay
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
  CMP #24
  BCC @not_up
  STA player_y
@not_up:

  ; Shooting with A button
  LDA buttons
  AND #BUTTON_A
  BEQ @not_shoot
  LDA player_fire_delay
  BNE @not_shoot

  JSR spawn_bullet
  JSR play_shoot_sound

  ; Fire rate based on power level
  LDA player_power
  BEQ @normal_rate
  LDA #4              ; Faster fire rate with powerup
  JMP @set_rate
@normal_rate:
  LDA #6
@set_rate:
  STA player_fire_delay
@not_shoot:

  ; Pause with START
  LDA buttons
  AND #BUTTON_START
  BEQ @no_pause
  LDA buttons_prev
  AND #BUTTON_START
  BNE @no_pause
  ; Toggle pause (simplified - just ignore for now)
@no_pause:
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
  SEC
  SBC #4
  STA bullet_y,X
  LDA #$FA            ; Faster bullets (-6)
  STA bullet_vy,X

  ; If powered up, spawn second bullet
  LDA player_power
  BEQ @no_double
  INX
  CPX #8
  BCS @no_double
  LDA bullet_active,X
  BNE @no_double
  LDA #1
  STA bullet_active,X
  LDA player_x
  STA bullet_x,X
  LDA player_y
  SEC
  SBC #4
  STA bullet_y,X
  LDA #$FA
  STA bullet_vy,X
@no_double:
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
  ; Check if off screen (wrapped to >240)
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

  ; Move enemy down
  LDA enemy_y,X
  CLC
  ADC enemy_speed,X
  STA enemy_y,X
  CMP #240
  BCC @on_screen
  ; Off screen - deactivate
  LDA #0
  STA enemy_active,X
  JMP @next

@on_screen:
  ; Wave movement based on enemy type
  LDA enemy_type,X
  CMP #ENEMY_FAST
  BEQ @no_wave        ; Fast enemies go straight

  ; Sine wave movement
  LDA frame_counter
  CLC
  ADC enemy_phase,X   ; Phase offset per enemy
  AND #$1F
  CMP #$10
  BCC @move_right
  LDA enemy_x,X
  SEC
  SBC #1
  STA enemy_x,X
  JMP @check_shoot
@move_right:
  LDA enemy_x,X
  CLC
  ADC #1
  STA enemy_x,X

@check_shoot:
  ; Shooter enemies fire
  LDA enemy_type,X
  CMP #ENEMY_SHOOTER
  BNE @next

  DEC enemy_timer,X
  BNE @next
  LDA #45             ; Reset shoot timer
  STA enemy_timer,X
  JSR spawn_enemy_bullet
  JMP @next

@no_wave:
@next:
  INX
  CPX #16
  BNE @loop
  RTS

spawn_enemies:
  DEC spawn_timer
  BEQ @do_spawn
  RTS
@do_spawn:

  ; Spawn rate based on difficulty
  LDA #40
  SEC
  SBC difficulty      ; Faster spawns at higher difficulty
  CMP #15
  BCS @set_timer
  LDA #15             ; Minimum spawn time
@set_timer:
  STA spawn_timer

  ; Find free enemy slot
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

  ; Random X position
  LDA frame_counter
  EOR spawn_timer
  AND #$E0
  CLC
  ADC #16
  STA enemy_x,X

  LDA #0
  STA enemy_y,X

  ; Enemy type based on difficulty and randomness
  LDA frame_counter
  AND #$07
  CMP #6
  BCC @basic_enemy
  LDA difficulty
  CMP #5
  BCC @basic_enemy

  ; Spawn shooter enemy at higher difficulty
  LDA #ENEMY_SHOOTER
  STA enemy_type,X
  LDA #1
  STA enemy_speed,X
  LDA #2
  STA enemy_hp,X
  LDA #30
  STA enemy_timer,X
  JMP @set_phase

@basic_enemy:
  LDA frame_counter
  AND #$03
  CMP #3
  BNE @normal_basic

  ; Fast enemy
  LDA #ENEMY_FAST
  STA enemy_type,X
  LDA #3
  STA enemy_speed,X
  LDA #1
  STA enemy_hp,X
  JMP @set_phase

@normal_basic:
  LDA #ENEMY_BASIC
  STA enemy_type,X
  LDA #1
  STA enemy_speed,X
  LDA #1
  STA enemy_hp,X

@set_phase:
  ; Random phase for wave movement
  LDA frame_counter
  STA enemy_phase,X

@done:
  RTS

; ============================================
; Enemy Bullets
; ============================================

spawn_enemy_bullet:
  ; X = enemy index (preserved)
  TXA
  PHA

  LDY #0
@find:
  LDA enemy_bullet_active,Y
  BEQ @found
  INY
  CPY #8
  BNE @find
  PLA
  TAX
  RTS

@found:
  LDA #1
  STA enemy_bullet_active,Y
  PLA
  TAX
  LDA enemy_x,X
  CLC
  ADC #4
  STA enemy_bullet_x,Y
  LDA enemy_y,X
  CLC
  ADC #8
  STA enemy_bullet_y,Y
  LDA #3              ; Bullet speed down
  STA enemy_bullet_vy,Y
  JSR play_enemy_shoot
  RTS

update_enemy_bullets:
  LDX #0
@loop:
  LDA enemy_bullet_active,X
  BEQ @next
  LDA enemy_bullet_y,X
  CLC
  ADC enemy_bullet_vy,X
  STA enemy_bullet_y,X
  CMP #240
  BCC @next
  LDA #0
  STA enemy_bullet_active,X
@next:
  INX
  CPX #8
  BNE @loop
  RTS

; ============================================
; Powerup System
; ============================================

spawn_powerup:
  ; X = position from dead enemy
  LDY #0
@find:
  LDA powerup_active,Y
  BEQ @found
  INY
  CPY #4
  BNE @find
  RTS
@found:
  LDA #1
  STA powerup_active,Y
  LDA temp
  STA powerup_x,Y
  LDA temp+1
  STA powerup_y,Y
  ; Random type: 0=power, 1=health
  LDA frame_counter
  AND #$01
  STA powerup_type,Y
  RTS

update_powerups:
  LDX #0
@loop:
  LDA powerup_active,X
  BEQ @next
  ; Move down slowly
  LDA powerup_y,X
  CLC
  ADC #1
  STA powerup_y,X
  CMP #240
  BCC @check_collect
  LDA #0
  STA powerup_active,X
  JMP @next

@check_collect:
  ; Check collision with player
  LDA powerup_x,X
  SEC
  SBC player_x
  CLC
  ADC #10
  CMP #20
  BCS @next

  LDA powerup_y,X
  SEC
  SBC player_y
  CLC
  ADC #10
  CMP #20
  BCS @next

  ; Collected!
  LDA #0
  STA powerup_active,X

  ; Apply powerup
  LDA powerup_type,X
  BNE @health_powerup

  ; Power upgrade
  LDA #1
  STA player_power
  JSR play_powerup_sound
  JMP @next

@health_powerup:
  LDA player_hp
  CMP #3
  BCS @next           ; Already full
  INC player_hp
  JSR play_powerup_sound

@next:
  INX
  CPX #4
  BNE @loop
  RTS

; ============================================
; Explosion System
; ============================================

spawn_explosion:
  ; temp = x, temp+1 = y
  LDX #0
@find:
  LDA explosion_active,X
  BEQ @found
  INX
  CPX #8
  BNE @find
  RTS
@found:
  LDA #8              ; 8 frames of animation
  STA explosion_active,X
  LDA temp
  STA explosion_x,X
  LDA temp+1
  STA explosion_y,X
  RTS

update_explosions:
  LDX #0
@loop:
  LDA explosion_active,X
  BEQ @next
  DEC explosion_active,X
@next:
  INX
  CPX #8
  BNE @loop
  RTS

; ============================================
; Collision Detection
; ============================================

check_collisions:
  ; Player bullets vs enemies
  LDX #0
@bullet_loop:
  LDA bullet_active,X
  BEQ @next_bullet

  LDY #0
@enemy_loop:
  LDA enemy_active,Y
  BEQ @next_enemy

  ; AABB collision check
  LDA bullet_x,X
  SEC
  SBC enemy_x,Y
  CLC
  ADC #6
  CMP #12
  BCS @next_enemy

  LDA bullet_y,X
  SEC
  SBC enemy_y,Y
  CLC
  ADC #6
  CMP #12
  BCS @next_enemy

  ; HIT! Damage enemy
  LDA enemy_hp,Y
  SEC
  SBC #1
  STA enemy_hp,Y
  BNE @enemy_alive

  ; Enemy destroyed!
  LDA #0
  STA enemy_active,Y

  ; Spawn explosion
  LDA enemy_x,Y
  STA temp
  LDA enemy_y,Y
  STA temp+1
  JSR spawn_explosion
  JSR play_explosion_sound

  ; Add score
  JSR add_score

  ; Maybe spawn powerup (1 in 8 chance)
  INC kill_count
  LDA kill_count
  AND #$07
  BNE @no_powerup
  JSR spawn_powerup
@no_powerup:

  ; Increase difficulty every 10 kills
  LDA kill_count
  AND #$0F
  BNE @enemy_alive
  LDA difficulty
  CMP #20
  BCS @enemy_alive
  INC difficulty

@enemy_alive:
  LDA #0
  STA bullet_active,X
  JSR play_hit_sound

@next_enemy:
  INY
  CPY #16
  BNE @enemy_loop

@next_bullet:
  INX
  CPX #8
  BNE @bullet_loop

  ; === PLAYER COLLISIONS ===
  LDA player_inv
  BNE @skip_player_collision

  ; Player vs Enemies
  LDY #0
@player_enemy_loop:
  LDA enemy_active,Y
  BEQ @next_pe

  ; Smaller hitbox (10 pixels)
  LDA player_x
  SEC
  SBC enemy_x,Y
  CLC
  ADC #10
  CMP #20
  BCS @next_pe

  LDA player_y
  SEC
  SBC enemy_y,Y
  CLC
  ADC #10
  CMP #20
  BCS @next_pe

  ; Player hit by enemy!
  JSR player_take_damage
  LDA #0
  STA enemy_active,Y
  JMP @skip_player_collision

@next_pe:
  INY
  CPY #16
  BNE @player_enemy_loop

  ; Player vs Enemy Bullets
  LDY #0
@player_bullet_loop:
  LDA enemy_bullet_active,Y
  BEQ @next_pb

  LDA player_x
  SEC
  SBC enemy_bullet_x,Y
  CLC
  ADC #8
  CMP #16
  BCS @next_pb

  LDA player_y
  SEC
  SBC enemy_bullet_y,Y
  CLC
  ADC #8
  CMP #16
  BCS @next_pb

  ; Player hit by bullet!
  JSR player_take_damage
  LDA #0
  STA enemy_bullet_active,Y
  JMP @skip_player_collision

@next_pb:
  INY
  CPY #8
  BNE @player_bullet_loop

@skip_player_collision:
  RTS

player_take_damage:
  DEC player_hp
  BNE @still_alive

  ; Lost a life
  DEC player_lives
  LDA #3
  STA player_hp
  LDA #0
  STA player_power    ; Lose powerup on death

@still_alive:
  LDA #90             ; 1.5 seconds invincibility
  STA player_inv
  JSR play_hurt_sound
  RTS

; ============================================
; Score System
; ============================================

add_score:
  ; Add 10 points per enemy
  LDA score_lo
  CLC
  ADC #10
  STA score_lo
  BCC @done
  INC score_mid
  BNE @done
  INC score_hi
@done:
  RTS

update_score_display:
  ; Score display updated in draw_hud during NMI
  RTS

draw_hud:
  ; Draw score digits at row 0
  BIT PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$08
  STA PPUADDR

  ; Convert score to digits and display
  LDA score_hi
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$30            ; '0' tile
  STA PPUDATA

  LDA score_hi
  AND #$0F
  CLC
  ADC #$30
  STA PPUDATA

  LDA score_mid
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$30
  STA PPUDATA

  LDA score_mid
  AND #$0F
  CLC
  ADC #$30
  STA PPUDATA

  LDA score_lo
  LSR A
  LSR A
  LSR A
  LSR A
  CLC
  ADC #$30
  STA PPUDATA

  LDA score_lo
  AND #$0F
  CLC
  ADC #$30
  STA PPUDATA

  ; Draw HP as hearts (just number for now)
  BIT PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$1B
  STA PPUADDR
  LDA player_hp
  CLC
  ADC #$30
  STA PPUDATA

  ; Draw lives
  BIT PPUSTATUS
  LDA #$20
  STA PPUADDR
  LDA #$1E
  STA PPUADDR
  LDA #'x'-$37
  STA PPUDATA
  LDA player_lives
  CLC
  ADC #$30
  STA PPUDATA

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

  LDX #0              ; OAM index

  ; === RENDER PLAYER ===
  LDA game_state
  CMP #STATE_PLAYING
  BNE @skip_player_render

  LDA player_inv
  BEQ @draw_player
  AND #$04
  BNE @skip_player_sprite

@draw_player:
  LDA player_y
  STA $0200,X
  LDA #SPRITE_PLAYER
  STA $0201,X
  LDA #0
  STA $0202,X
  LDA player_x
  STA $0203,X
  INX
  INX
  INX
  INX

@skip_player_sprite:
@skip_player_render:

  ; === RENDER PLAYER BULLETS ===
  LDY #0
@bullets:
  LDA bullet_active,Y
  BEQ @next_bullet
  LDA bullet_y,Y
  STA $0200,X
  LDA #SPRITE_PLAYER_BULLET
  STA $0201,X
  LDA #1              ; Palette 1
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

  ; === RENDER ENEMIES ===
  LDY #0
@enemies:
  LDA enemy_active,Y
  BEQ @next_enemy_render
  LDA enemy_y,Y
  STA $0200,X
  ; Different sprite for different types
  LDA enemy_type,Y
  CMP #ENEMY_SHOOTER
  BNE @basic_sprite
  LDA #SPRITE_ENEMY_2
  JMP @set_enemy_sprite
@basic_sprite:
  LDA #SPRITE_ENEMY_1
@set_enemy_sprite:
  STA $0201,X
  LDA #2              ; Palette 2
  STA $0202,X
  LDA enemy_x,Y
  STA $0203,X
  TXA
  CLC
  ADC #4
  TAX
  CPX #252
  BCC @next_enemy_render
  JMP @sprites_done
@next_enemy_render:
  INY
  CPY #16
  BNE @enemies

  ; === RENDER ENEMY BULLETS ===
  LDY #0
@enemy_bullets:
  LDA enemy_bullet_active,Y
  BEQ @next_eb
  LDA enemy_bullet_y,Y
  STA $0200,X
  LDA #SPRITE_ENEMY_BULLET
  STA $0201,X
  LDA #2
  STA $0202,X
  LDA enemy_bullet_x,Y
  STA $0203,X
  TXA
  CLC
  ADC #4
  TAX
  CPX #252
  BCC @next_eb
  JMP @sprites_done
@next_eb:
  INY
  CPY #8
  BNE @enemy_bullets

  ; === RENDER POWERUPS ===
  LDY #0
@powerups:
  LDA powerup_active,Y
  BEQ @next_powerup
  LDA powerup_y,Y
  STA $0200,X
  LDA #SPRITE_POWERUP
  STA $0201,X
  LDA #1
  STA $0202,X
  LDA powerup_x,Y
  STA $0203,X
  TXA
  CLC
  ADC #4
  TAX
  CPX #252
  BCC @next_powerup
  JMP @sprites_done
@next_powerup:
  INY
  CPY #4
  BNE @powerups

  ; === RENDER EXPLOSIONS ===
  LDY #0
@explosions:
  LDA explosion_active,Y
  BEQ @next_explosion
  LDA explosion_y,Y
  STA $0200,X
  LDA #SPRITE_EXPLOSION
  STA $0201,X
  LDA #3              ; Palette 3 (yellow/orange)
  STA $0202,X
  LDA explosion_x,Y
  STA $0203,X
  TXA
  CLC
  ADC #4
  TAX
  CPX #252
  BCC @next_explosion
  JMP @sprites_done
@next_explosion:
  INY
  CPY #8
  BNE @explosions

@sprites_done:
  RTS

; ============================================
; Sound System - PROPER SOUND EFFECTS!
; ============================================

update_sound:
  ; Decay shoot sound
  LDA sound_shoot_timer
  BEQ @no_shoot_decay
  DEC sound_shoot_timer
  BNE @shoot_still_on
  ; Turn off
  LDA #$00
  STA SQ1_VOL
@shoot_still_on:
@no_shoot_decay:

  ; Decay explosion sound
  LDA sound_explode_timer
  BEQ @no_explode_decay
  DEC sound_explode_timer
  LDA sound_explode_timer
  LSR A
  ORA #$80
  STA NOISE_VOL
  BNE @explode_still_on
  LDA #$00
  STA NOISE_VOL
@explode_still_on:
@no_explode_decay:

  ; Decay hurt sound
  LDA sound_hurt_timer
  BEQ @no_hurt_decay
  DEC sound_hurt_timer
  BNE @hurt_still_on
  LDA #$00
  STA SQ2_VOL
@hurt_still_on:
@no_hurt_decay:

  RTS

play_shoot_sound:
  LDA #$85            ; Duty 50%, no length, vol 5
  STA SQ1_VOL
  LDA #$00
  STA SQ1_SWEEP
  LDA #$80            ; Higher pitch
  STA SQ1_LO
  LDA #$00
  STA SQ1_HI
  LDA #4
  STA sound_shoot_timer
  RTS

play_explosion_sound:
  LDA #$8F            ; Max volume noise
  STA NOISE_VOL
  LDA #$06            ; Low rumble
  STA NOISE_LO
  LDA #$00
  STA NOISE_HI
  LDA #15
  STA sound_explode_timer
  RTS

play_hit_sound:
  LDA #$83
  STA SQ1_VOL
  LDA #$40
  STA SQ1_LO
  LDA #$01
  STA SQ1_HI
  LDA #3
  STA sound_shoot_timer
  RTS

play_hurt_sound:
  LDA #$8C            ; Duty 50%, vol 12
  STA SQ2_VOL
  LDA #$00
  STA SQ2_SWEEP
  LDA #$00
  STA SQ2_LO
  LDA #$02
  STA SQ2_HI
  LDA #20
  STA sound_hurt_timer
  RTS

play_powerup_sound:
  ; Rising tone
  LDA #$87
  STA SQ2_VOL
  LDA #$C0
  STA SQ2_LO
  LDA #$00
  STA SQ2_HI
  LDA #10
  STA sound_hurt_timer
  RTS

play_enemy_shoot:
  ; Quick noise blip
  LDA #$84
  STA NOISE_VOL
  LDA #$0A
  STA NOISE_LO
  LDA #$00
  STA NOISE_HI
  RTS

play_start_sound:
  ; Triumphant start tone
  LDA #$8A
  STA SQ1_VOL
  LDA #$50
  STA SQ1_LO
  LDA #$01
  STA SQ1_HI
  LDA #10
  STA sound_shoot_timer
  RTS

play_gameover_sound:
  ; Low sad tone
  LDA #$8F
  STA SQ2_VOL
  LDA #$00
  STA SQ2_LO
  LDA #$04
  STA SQ2_HI
  LDA #60
  STA sound_hurt_timer
  RTS

; ============================================
; Data
; ============================================

palette_bg:
  BYTE $0F,$00,$10,$30  ; Black, dark gray, gray, white
  BYTE $0F,$01,$11,$21  ; Blues
  BYTE $0F,$06,$16,$26  ; Reds
  BYTE $0F,$09,$19,$29  ; Greens

palette_sprite:
  BYTE $0F,$30,$10,$00  ; Player - white/gray
  BYTE $0F,$21,$11,$01  ; Bullets - blue
  BYTE $0F,$16,$26,$06  ; Enemies - red
  BYTE $0F,$28,$18,$08  ; Explosions - yellow/orange

; ============================================
; Variables (Zero Page)
; ============================================
  ENUM $0000

temp           DSB 2
buttons        DSB 1
buttons_prev   DSB 1
scroll_x       DSB 1
scroll_y       DSB 1

player_x       DSB 1
player_y       DSB 1
player_hp      DSB 1
player_lives   DSB 1
player_inv     DSB 1
player_fire_delay DSB 1
player_power   DSB 1

frame_counter  DSB 1
spawn_timer    DSB 1
game_state     DSB 1
difficulty     DSB 1
kill_count     DSB 1

score_lo       DSB 1
score_mid      DSB 1
score_hi       DSB 1

sound_shoot_timer  DSB 1
sound_explode_timer DSB 1
sound_hurt_timer   DSB 1

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
enemy_type     DSB 16
enemy_speed    DSB 16
enemy_phase    DSB 16
enemy_timer    DSB 16

enemy_bullet_active DSB 8
enemy_bullet_x      DSB 8
enemy_bullet_y      DSB 8
enemy_bullet_vy     DSB 8

powerup_active DSB 4
powerup_x      DSB 4
powerup_y      DSB 4
powerup_type   DSB 4

explosion_active DSB 8
explosion_x      DSB 8
explosion_y      DSB 8

  ENDE

; ============================================
; Interrupt Vectors
; ============================================
  PAD $BFFA
  WORD NMI
  WORD Reset
  WORD IRQ

; ============================================
; CHR-ROM
; ============================================
  INCBIN "assets/chr/chr_data.chr"
