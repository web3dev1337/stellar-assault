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
ENEMY_BOSS     = 4      ; Boss enemy (large, high HP)

; Wave Formation Types
WAVE_NONE      = 0      ; No active wave (regular spawning)
WAVE_V         = 1      ; V-formation (5 enemies)
WAVE_LINE      = 2      ; Horizontal line (6 enemies)
WAVE_DIAGONAL  = 3      ; Diagonal sweep (5 enemies)
WAVE_PINCER    = 4      ; Two groups from sides (6 enemies)

; Wave sizes (number of enemies per formation)
WAVE_V_SIZE       = 5
WAVE_LINE_SIZE    = 6
WAVE_DIAGONAL_SIZE = 5
WAVE_PINCER_SIZE  = 6

; Sprite tile IDs
SPRITE_PLAYER       = $00
SPRITE_PLAYER_BULLET = $04
SPRITE_ENEMY_1      = $08
SPRITE_ENEMY_2      = $09
SPRITE_ENEMY_3      = $0A
SPRITE_ENEMY_BULLET = $0C
SPRITE_POWERUP      = $10
SPRITE_EXPLOSION    = $14
SPRITE_STAR         = $19
SPRITE_BOSS_TL      = $1A  ; Boss top-left (2x2 sprite)
SPRITE_BOSS_TR      = $1B  ; Boss top-right
SPRITE_BOSS_BL      = $1C  ; Boss bottom-left
SPRITE_BOSS_BR      = $1D  ; Boss bottom-right
SPRITE_SHIELD       = $1E  ; Shield indicator sprite

; Boss configuration
BOSS_MAX_HP         = 50   ; Boss takes 50 hits
BOSS_WAVES_INTERVAL = 5    ; Boss appears every 5 waves
BOSS_WIDTH          = 16   ; Boss is 16 pixels wide (2 sprites)
BOSS_SHOOT_RATE     = 30   ; Boss shoots every 30 frames

; Number of stars for parallax background
NUM_STARS = 20

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
  JSR update_stars
  JSR update_player
  JSR update_bomb
  JSR update_bullets
  JSR update_enemies
  JSR update_boss
  JSR update_enemy_bullets
  JSR update_powerups
  JSR update_explosions
  JSR check_collisions
  JSR check_boss_collision
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
  STA player_shield     ; Start with no shield
  STA bomb_active
  STA bomb_timer
  LDA #3                ; Start with 3 bombs
  STA bomb_count

  ; Initialize wave system
  LDA #0
  STA wave_type         ; No active wave
  STA wave_index
  STA wave_timer
  STA wave_kills
  LDA #1
  STA wave_number       ; Start at wave 1

  ; Initialize boss system
  LDA #0
  STA boss_active
  STA boss_hp
  STA boss_timer
  STA boss_phase
  STA boss_dir

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
  JSR init_stars
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

  ; Bomb with B button
  LDA buttons
  AND #BUTTON_B
  BEQ @not_bomb
  LDA buttons_prev
  AND #BUTTON_B
  BNE @not_bomb        ; Require new press
  LDA bomb_count
  BEQ @not_bomb        ; No bombs left
  LDA bomb_active
  BNE @not_bomb        ; Bomb already active
  JSR activate_bomb
@not_bomb:

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
; Bomb System
; ============================================

activate_bomb:
  ; Use a bomb
  DEC bomb_count

  ; Set bomb active with timer
  LDA #1
  STA bomb_active
  LDA #30           ; Effect lasts 30 frames (0.5 seconds)
  STA bomb_timer

  ; Kill all enemies
  LDX #0
@kill_loop:
  LDA enemy_active,X
  BEQ @skip_enemy
  ; Store position in temp vars
  LDA enemy_x,X
  STA temp
  LDA enemy_y,X
  STA temp+1
  ; Save X and spawn explosion
  TXA
  PHA
  JSR spawn_explosion
  PLA
  TAX
  ; Deactivate enemy
  LDA #0
  STA enemy_active,X
  ; Add score for each kill
  LDA #5            ; 50 points per enemy
  JSR add_score
@skip_enemy:
  INX
  CPX #16
  BNE @kill_loop

  ; Play bomb sound
  JSR play_explosion_sound
  RTS

update_bomb:
  ; Check if bomb effect is active
  LDA bomb_active
  BEQ @bomb_done

  ; Decrement timer
  DEC bomb_timer
  BNE @do_flash

  ; Timer expired - deactivate
  LDA #0
  STA bomb_active
  ; Reset screen colors
  LDA #%00011110    ; Normal PPU settings
  STA $2001
  JMP @bomb_done

@do_flash:
  ; Flash screen white/red based on timer
  LDA bomb_timer
  AND #%00000100    ; Toggle every 4 frames
  BEQ @flash_red
  ; Flash white - enable all color emphasis
  LDA #%11111110
  STA $2001
  JMP @bomb_done
@flash_red:
  ; Flash red - red emphasis only
  LDA #%00111110
  STA $2001

@bomb_done:
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
  ; Center bullet (always)
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
  LDA #0              ; No horizontal movement
  STA bullet_vx,X
  LDA #$FA            ; Fast upward (-6)
  STA bullet_vy,X

  ; If powered up, spawn spread shot (left and right)
  LDA player_power
  BEQ @done

  ; Left diagonal bullet
  INX
  CPX #8
  BCS @done
  LDA bullet_active,X
  BNE @try_right
  LDA #1
  STA bullet_active,X
  LDA player_x
  STA bullet_x,X      ; Left side
  LDA player_y
  SEC
  SBC #4
  STA bullet_y,X
  LDA #$FE            ; Slight left (-2)
  STA bullet_vx,X
  LDA #$FA            ; Fast upward
  STA bullet_vy,X

@try_right:
  ; Right diagonal bullet
  INX
  CPX #8
  BCS @done
  LDA bullet_active,X
  BNE @done
  LDA #1
  STA bullet_active,X
  LDA player_x
  CLC
  ADC #8
  STA bullet_x,X      ; Right side
  LDA player_y
  SEC
  SBC #4
  STA bullet_y,X
  LDA #2              ; Slight right (+2)
  STA bullet_vx,X
  LDA #$FA            ; Fast upward
  STA bullet_vy,X
@done:
  RTS

update_bullets:
  LDX #0
@loop:
  LDA bullet_active,X
  BEQ @next
  ; Update Y position
  LDA bullet_y,X
  CLC
  ADC bullet_vy,X
  STA bullet_y,X
  ; Check if off top (wrapped to >240)
  CMP #240
  BCS @deactivate
  ; Update X position (for spread shot)
  LDA bullet_x,X
  CLC
  ADC bullet_vx,X
  STA bullet_x,X
  ; Check if off left/right (0-255 wraps)
  CMP #248               ; Off right side
  BCS @deactivate
  JMP @next
@deactivate:
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
  ; Check if wave is active - handle wave spawning
  LDA wave_type
  BEQ @normal_spawn
  JMP update_wave_spawn

@normal_spawn:
  DEC spawn_timer
  BEQ @do_spawn
  RTS
@do_spawn:

  ; Check if we should start a wave (every 8 kills)
  LDA wave_kills
  CMP #8
  BCC @no_wave_trigger

  ; Start a new wave!
  JSR start_wave
  RTS

@no_wave_trigger:
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
; Wave Formation System
; ============================================

; Start a new wave formation
start_wave:
  ; Reset wave kills counter
  LDA #0
  STA wave_kills
  STA wave_index
  LDA #6              ; Small delay before first enemy
  STA wave_timer

  ; Check if boss wave (every 5 waves)
  LDA wave_number
  ; Check if divisible by 5: subtract 5 repeatedly
  SEC
@check_boss:
  SBC #BOSS_WAVES_INTERVAL
  BCC @not_boss_wave    ; Went negative, not divisible
  BEQ @spawn_boss       ; Exactly zero = divisible by 5
  JMP @check_boss

@spawn_boss:
  JSR spawn_boss
  ; Skip regular wave - boss takes over
  LDA #0
  STA wave_type
  INC wave_number
  RTS

@not_boss_wave:
  ; Pick wave type based on wave number
  LDA wave_number
  AND #$03            ; Cycle through 4 types (1-4)
  CLC
  ADC #1              ; Types 1-4
  STA wave_type

  ; Increment wave number
  INC wave_number
  RTS

; Spawn the boss
spawn_boss:
  LDA #1
  STA boss_active
  LDA #BOSS_MAX_HP
  STA boss_hp
  LDA #116            ; Center X (256/2 - 16/2)
  STA boss_x
  LDA #0              ; Start at top of screen
  STA boss_y
  LDA #BOSS_SHOOT_RATE
  STA boss_timer
  LDA #0
  STA boss_phase
  STA boss_dir
  RTS

; Update boss movement and shooting
update_boss:
  LDA boss_active
  BEQ @boss_done

  ; Phase 0: Enter screen (move down)
  LDA boss_y
  CMP #40
  BCS @do_movement

  ; Still entering - move down
  LDA boss_y
  CLC
  ADC #1
  STA boss_y
  JMP @boss_done

@do_movement:
  ; Move left/right based on boss_dir
  LDA boss_dir
  BNE @move_right

  ; Moving left
  LDA boss_x
  SEC
  SBC #1
  STA boss_x
  CMP #16
  BCS @check_shoot
  ; Hit left edge - reverse
  LDA #1
  STA boss_dir
  JMP @check_shoot

@move_right:
  LDA boss_x
  CLC
  ADC #1
  STA boss_x
  CMP #224
  BCC @check_shoot
  ; Hit right edge - reverse
  LDA #0
  STA boss_dir

@check_shoot:
  ; Shooting timer
  DEC boss_timer
  BNE @boss_done

  ; Reset timer and shoot
  LDA #BOSS_SHOOT_RATE
  STA boss_timer

  ; Spawn bullet from boss center
  JSR spawn_boss_bullet

@boss_done:
  RTS

; Spawn a bullet from the boss
spawn_boss_bullet:
  LDY #0
@find:
  LDA enemy_bullet_active,Y
  BEQ @found
  INY
  CPY #8
  BNE @find
  RTS                   ; No free slot
@found:
  LDA #1
  STA enemy_bullet_active,Y
  LDA boss_x
  CLC
  ADC #6              ; Center of boss
  STA enemy_bullet_x,Y
  LDA boss_y
  CLC
  ADC #16             ; Bottom of boss
  STA enemy_bullet_y,Y
  LDA #3              ; Bullet speed down
  STA enemy_bullet_vy,Y
  JSR play_enemy_shoot
  RTS

; Check player bullets vs boss
check_boss_collision:
  LDA boss_active
  BEQ @boss_col_done

  LDX #0
@bullet_loop:
  LDA bullet_active,X
  BEQ @next_bullet

  ; AABB collision - boss is 16x16
  LDA bullet_x,X
  SEC
  SBC boss_x
  CLC
  ADC #8              ; Half boss width + bullet
  CMP #24
  BCS @next_bullet

  LDA bullet_y,X
  SEC
  SBC boss_y
  CLC
  ADC #8
  CMP #24
  BCS @next_bullet

  ; HIT! Deactivate bullet
  LDA #0
  STA bullet_active,X

  ; Damage boss
  DEC boss_hp
  BNE @boss_alive

  ; Boss destroyed!
  LDA #0
  STA boss_active

  ; Big explosion at boss position
  LDA boss_x
  STA temp
  LDA boss_y
  STA temp+1
  JSR spawn_explosion

  ; Offset explosion for bigger effect
  LDA boss_x
  CLC
  ADC #8
  STA temp
  JSR spawn_explosion

  ; Big score bonus (500 points = 50 * 10)
  LDA #50
  JSR add_score
  LDA #50
  JSR add_score
  LDA #50
  JSR add_score
  LDA #50
  JSR add_score
  LDA #50
  JSR add_score

  ; Spawn powerup
  LDA boss_x
  STA temp
  LDA boss_y
  STA temp+1
  JSR spawn_powerup

  JSR play_explosion_sound
  JMP @boss_col_done

@boss_alive:
  JSR play_hit_sound

@next_bullet:
  INX
  CPX #8
  BNE @bullet_loop

@boss_col_done:
  RTS

; Update wave spawning - called when wave is active
update_wave_spawn:
  ; Delay between spawning each enemy
  DEC wave_timer
  BNE @wait

  ; Reset timer for next enemy
  LDA #8              ; Frames between enemies
  STA wave_timer

  ; Check if wave is complete
  LDA wave_type
  CMP #WAVE_V
  BEQ @check_v_done
  CMP #WAVE_LINE
  BEQ @check_line_done
  CMP #WAVE_DIAGONAL
  BEQ @check_diag_done
  CMP #WAVE_PINCER
  BEQ @check_pincer_done
  JMP @end_wave

@check_v_done:
  LDA wave_index
  CMP #WAVE_V_SIZE
  BCS @end_wave
  JMP @spawn_wave_enemy
@check_line_done:
  LDA wave_index
  CMP #WAVE_LINE_SIZE
  BCS @end_wave
  JMP @spawn_wave_enemy
@check_diag_done:
  LDA wave_index
  CMP #WAVE_DIAGONAL_SIZE
  BCS @end_wave
  JMP @spawn_wave_enemy
@check_pincer_done:
  LDA wave_index
  CMP #WAVE_PINCER_SIZE
  BCS @end_wave
  JMP @spawn_wave_enemy

@end_wave:
  LDA #WAVE_NONE
  STA wave_type
@wait:
  RTS

@spawn_wave_enemy:
  ; Find free enemy slot
  LDX #0
@find_slot:
  LDA enemy_active,X
  BEQ @found_slot
  INX
  CPX #16
  BNE @find_slot
  RTS               ; No free slot

@found_slot:
  LDA #1
  STA enemy_active,X

  ; Get X position based on formation type
  LDA wave_type
  CMP #WAVE_V
  BEQ @v_formation
  CMP #WAVE_LINE
  BEQ @line_formation
  CMP #WAVE_DIAGONAL
  BEQ @diagonal_formation
  CMP #WAVE_PINCER
  BEQ @pincer_formation
  JMP @default_pos

@v_formation:
  ; V-shape: center, then spread outward
  ; Positions: 120, 96, 144, 72, 168
  LDY wave_index
  LDA wave_v_x,Y
  JMP @set_pos

@line_formation:
  ; Horizontal line across screen
  ; Positions: 32, 64, 96, 128, 160, 192
  LDY wave_index
  LDA wave_line_x,Y
  JMP @set_pos

@diagonal_formation:
  ; Diagonal from left to right
  ; Positions: 40, 72, 104, 136, 168
  LDY wave_index
  LDA wave_diag_x,Y
  JMP @set_pos

@pincer_formation:
  ; Two groups from sides
  ; Positions: 32, 48, 64, 192, 176, 160
  LDY wave_index
  LDA wave_pincer_x,Y
  JMP @set_pos

@default_pos:
  LDA #120

@set_pos:
  STA enemy_x,X

  ; Y position - staggered for formations
  LDA wave_index
  ASL A               ; index * 2
  ASL A               ; index * 4
  ASL A               ; index * 8 (8 pixels stagger)
  EOR #$FF            ; Negate
  CLC
  ADC #1
  STA enemy_y,X       ; Start above screen (negative Y wraps)

  ; All wave enemies are BASIC type but faster
  LDA #ENEMY_BASIC
  STA enemy_type,X
  LDA #2              ; Speed 2 (faster than normal)
  STA enemy_speed,X
  LDA #1
  STA enemy_hp,X
  LDA frame_counter
  STA enemy_phase,X

  ; Increment wave index
  INC wave_index
  RTS

; Wave formation X position data tables
wave_v_x:
  BYTE 120, 96, 144, 72, 168      ; V-shape pattern

wave_line_x:
  BYTE 32, 64, 96, 128, 160, 192  ; Horizontal line

wave_diag_x:
  BYTE 40, 72, 104, 136, 168      ; Diagonal sweep

wave_pincer_x:
  BYTE 32, 48, 64, 192, 176, 160  ; Pincer from sides

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
  ; Random type: 0=power, 1=health, 2=shield
  LDA frame_counter
  AND #$03              ; 0-3
  CMP #3
  BCC @type_ok
  LDA #0                ; Map 3 back to power
@type_ok:
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
  LDA powerup_type,X
  CMP #2
  BEQ @shield_powerup
  ; Health powerup (type 1)
  LDA player_hp
  CMP #3
  BCS @next           ; Already full
  INC player_hp
  JSR play_powerup_sound
  JMP @next

@shield_powerup:
  ; Shield powerup (type 2) - gives 3 hits
  LDA #3
  STA player_shield
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
; Star Field (Parallax Background)
; ============================================

init_stars:
  ; Initialize 20 stars with random positions and speeds
  LDX #0
@init_loop:
  ; Use frame counter and X as seed for pseudo-random
  TXA
  ASL A
  ASL A
  ASL A
  ADC frame_counter
  EOR #$5A           ; XOR with magic number for variety
  STA star_x,X

  ; Y position - spread across screen
  TXA
  ASL A
  ASL A
  ASL A
  ASL A              ; Multiply X by 16
  ADC #10            ; Add offset
  CMP #224           ; Clamp to screen height
  BCC @y_ok
  LDA #200
@y_ok:
  STA star_y,X

  ; Speed - 3 layers: slow (1), medium (2), fast (3)
  TXA
  AND #$03           ; Get X mod 4
  CLC
  ADC #1             ; Speed 1-4
  STA star_speed,X

  INX
  CPX #NUM_STARS
  BNE @init_loop
  RTS

update_stars:
  LDX #0
@update_loop:
  ; Move star down by its speed
  LDA star_y,X
  CLC
  ADC star_speed,X
  CMP #240           ; Check if off screen
  BCC @no_wrap
  ; Wrap to top and randomize X
  LDA #0
  STA star_y,X
  ; New random X position
  LDA frame_counter
  EOR star_x,X
  ASL A
  EOR frame_counter
  STA star_x,X
  JMP @next_star
@no_wrap:
  STA star_y,X
@next_star:
  INX
  CPX #NUM_STARS
  BNE @update_loop
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
  INC wave_kills        ; Track kills for wave triggering
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
  ; Check if shield is active
  LDA player_shield
  BEQ @no_shield
  ; Shield absorbs hit
  DEC player_shield
  LDA #30             ; Brief invincibility (0.5 sec)
  STA player_inv
  JSR play_hurt_sound
  RTS

@no_shield:
  DEC player_hp
  BNE @still_alive

  ; Lost a life
  DEC player_lives
  LDA #3
  STA player_hp
  LDA #0
  STA player_power    ; Lose powerup on death
  STA player_shield   ; Lose shield on death

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

  ; === RENDER STARS (Background - dim, clearly behind gameplay) ===
  LDY #0
@render_stars:
  LDA star_y,Y
  STA $0200,X         ; Y position
  LDA #SPRITE_STAR
  STA $0201,X         ; Tile
  ; All stars use dim palette 1 with behind-background priority
  ; Faster stars (closer) are slightly brighter via no flip
  ; Slower stars (distant) flip for variety
  LDA star_speed,Y
  CMP #2
  BCC @slow_star
  LDA #$21            ; Palette 1, behind bg, no flip (closer = slightly brighter)
  JMP @set_star_attr
@slow_star:
  LDA #$61            ; Palette 1, behind bg, flip H (distant = dimmer feel)
@set_star_attr:
  STA $0202,X         ; Attributes
  LDA star_x,Y
  STA $0203,X         ; X position
  TXA
  CLC
  ADC #4
  TAX
  INY
  CPY #NUM_STARS
  BNE @render_stars

  ; === RENDER PLAYER ===
  LDA game_state
  CMP #STATE_PLAYING
  BEQ @player_state_ok
  JMP @skip_player_render
@player_state_ok:

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

  ; === ENGINE FLAME (animated exhaust behind ship) ===
  ; Position: slightly left of and centered on player ship
  LDA player_y
  CLC
  ADC #3              ; Center vertically on ship
  STA $0200,X
  LDA #SPRITE_PLAYER_BULLET  ; Reuse bullet sprite as flame
  STA $0201,X
  ; Animated flame color - cycle through palettes for flicker
  LDA frame_counter
  LSR A               ; Shift for slower animation
  AND #$03            ; 4 palette cycle (0,1,2,3,0,1...)
  ; Add flip based on frame for extra animation
  PHA
  LDA frame_counter
  AND #$02
  BEQ @engine_no_flip
  PLA
  ORA #%01000000      ; Add horizontal flip
  JMP @set_engine_attr
@engine_no_flip:
  PLA
@set_engine_attr:
  STA $0202,X
  LDA player_x
  SEC
  SBC #6              ; Position behind ship (to the left)
  STA $0203,X
  INX
  INX
  INX
  INX

@skip_player_sprite:

  ; === RENDER SHIELD (if active) ===
  LDA player_shield
  BEQ @skip_shield
  ; Flash effect - only draw on even frames
  LDA frame_counter
  AND #$02
  BNE @skip_shield

  ; Top shield sprite
  LDA player_y
  SEC
  SBC #6
  STA $0200,X
  LDA #SPRITE_SHIELD
  STA $0201,X
  LDA #0              ; Palette 0 (cyan - matches player)
  STA $0202,X
  LDA player_x
  CLC
  ADC #2
  STA $0203,X
  INX
  INX
  INX
  INX

  ; Bottom shield sprite
  LDA player_y
  CLC
  ADC #8
  STA $0200,X
  LDA #SPRITE_SHIELD
  STA $0201,X
  LDA #1
  STA $0202,X
  LDA player_x
  CLC
  ADC #2
  STA $0203,X
  INX
  INX
  INX
  INX

  ; Left shield sprite
  LDA player_y
  CLC
  ADC #2
  STA $0200,X
  LDA #SPRITE_SHIELD
  STA $0201,X
  LDA #1
  STA $0202,X
  LDA player_x
  SEC
  SBC #4
  STA $0203,X
  INX
  INX
  INX
  INX

  ; Right shield sprite
  LDA player_y
  CLC
  ADC #2
  STA $0200,X
  LDA #SPRITE_SHIELD
  STA $0201,X
  LDA #1
  STA $0202,X
  LDA player_x
  CLC
  ADC #10
  STA $0203,X
  INX
  INX
  INX
  INX

@skip_shield:
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
  LDA #0              ; Palette 0 (bright cyan, matches player)
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

  ; Different sprite for different enemy types with animation
  LDA enemy_type,Y
  CMP #ENEMY_SHOOTER
  BEQ @shooter_sprite
  CMP #ENEMY_FAST
  BEQ @fast_sprite
  ; Basic enemy - use SPRITE_ENEMY_1 with flip animation
  LDA frame_counter
  AND #$08            ; Toggle every 8 frames
  BEQ @basic_no_flip
  LDA #SPRITE_ENEMY_1
  STA $0201,X
  LDA #%01000010      ; Palette 2, flip horizontal
  JMP @set_enemy_attr
@basic_no_flip:
  LDA #SPRITE_ENEMY_1
  STA $0201,X
  LDA #2              ; Palette 2, no flip
  JMP @set_enemy_attr

@fast_sprite:
  ; Fast enemy - use SPRITE_ENEMY_3 with palette 3 (yellow/white - bright and fast!)
  LDA frame_counter
  AND #$04            ; Faster animation (every 4 frames)
  BEQ @fast_no_flip
  LDA #SPRITE_ENEMY_3
  STA $0201,X
  LDA #%01000011      ; Palette 3, flip horizontal
  JMP @set_enemy_attr
@fast_no_flip:
  LDA #SPRITE_ENEMY_3
  STA $0201,X
  LDA #3              ; Palette 3, no flip
  JMP @set_enemy_attr

@shooter_sprite:
  ; Shooter enemy - use SPRITE_ENEMY_2 with palette 2 (red/orange - menacing)
  LDA frame_counter
  AND #$10            ; Slower animation for menacing look
  BEQ @shooter_no_flip
  LDA #SPRITE_ENEMY_2
  STA $0201,X
  LDA #%11000010      ; Palette 2, flip both
  JMP @set_enemy_attr
@shooter_no_flip:
  LDA #SPRITE_ENEMY_2
  STA $0201,X
  LDA #2              ; Palette 2, no flip

@set_enemy_attr:
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
  ; Powerups pulse/flash based on type for identification
  LDY #0
@powerups:
  LDA powerup_active,Y
  BEQ @next_powerup
  LDA powerup_y,Y
  STA $0200,X
  LDA #SPRITE_POWERUP
  STA $0201,X

  ; Different palette based on powerup type with flash
  ; Palette 0 = cyan (player), Palette 3 = yellow/white (effects)
  LDA powerup_type,Y
  CMP #2
  BEQ @shield_powerup_render
  CMP #1
  BEQ @health_powerup_render
  ; Power powerup (type 0) - yellow flash (palette 3)
  LDA frame_counter
  AND #$04
  BEQ @power_flash_off
  LDA #3              ; Palette 3 (yellow/white - bright!)
  JMP @set_powerup_attr
@power_flash_off:
  LDA #%01000011      ; Palette 3, flip H (visible but animated)
  JMP @set_powerup_attr

@health_powerup_render:
  ; Health powerup (type 1) - cyan pulse (friendly, matches player)
  LDA frame_counter
  AND #$08
  BEQ @health_flash_off
  LDA #0              ; Palette 0 (cyan - player color)
  JMP @set_powerup_attr
@health_flash_off:
  LDA #%01000000      ; Palette 0, flip H (rotating effect)
  JMP @set_powerup_attr

@shield_powerup_render:
  ; Shield powerup (type 2) - yellow/white rapid flash
  LDA frame_counter
  AND #$02
  BEQ @shield_flash_off
  LDA #3              ; Palette 3 (yellow/white)
  JMP @set_powerup_attr
@shield_flash_off:
  LDA #%01000011      ; Palette 3 with flip (still visible)

@set_powerup_attr:
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

  ; === RENDER BOSS (2x2 sprites) ===
  LDA boss_active
  BEQ @sprites_done

  ; Top-left sprite
  LDA boss_y
  STA $0200,X
  LDA #SPRITE_BOSS_TL
  STA $0201,X
  LDA #2              ; Palette 2 (enemy colors)
  STA $0202,X
  LDA boss_x
  STA $0203,X
  TXA
  CLC
  ADC #4
  TAX
  CPX #252
  BCS @sprites_done

  ; Top-right sprite
  LDA boss_y
  STA $0200,X
  LDA #SPRITE_BOSS_TR
  STA $0201,X
  LDA #2
  STA $0202,X
  LDA boss_x
  CLC
  ADC #8
  STA $0203,X
  TXA
  CLC
  ADC #4
  TAX
  CPX #252
  BCS @sprites_done

  ; Bottom-left sprite
  LDA boss_y
  CLC
  ADC #8
  STA $0200,X
  LDA #SPRITE_BOSS_BL
  STA $0201,X
  LDA #2
  STA $0202,X
  LDA boss_x
  STA $0203,X
  TXA
  CLC
  ADC #4
  TAX
  CPX #252
  BCS @sprites_done

  ; Bottom-right sprite
  LDA boss_y
  CLC
  ADC #8
  STA $0200,X
  LDA #SPRITE_BOSS_BR
  STA $0201,X
  LDA #2
  STA $0202,X
  LDA boss_x
  CLC
  ADC #8
  STA $0203,X
  TXA
  CLC
  ADC #4
  TAX

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
  BYTE $0F,$2C,$1C,$0C  ; Palette 0: Player - bright cyan (stands out!)
  BYTE $0F,$00,$10,$2D  ; Palette 1: Stars - very dim gray/dark (background)
  BYTE $0F,$16,$27,$37  ; Palette 2: Enemies - red/orange (warm, threatening)
  BYTE $0F,$28,$38,$30  ; Palette 3: Explosions/effects - yellow/white (bright)

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
player_shield  DSB 1           ; Shield hits remaining (0=off, 1+=active)
bomb_count     DSB 1           ; Number of bombs player has
bomb_active    DSB 1           ; Is bomb effect active?
bomb_timer     DSB 1           ; Visual effect countdown

frame_counter  DSB 1
spawn_timer    DSB 1
game_state     DSB 1
difficulty     DSB 1
kill_count     DSB 1

; Wave formation system
wave_number    DSB 1           ; Current wave number (increments every 10 kills)
wave_type      DSB 1           ; Active formation type (0=none)
wave_index     DSB 1           ; Enemies spawned in current wave
wave_timer     DSB 1           ; Delay between wave enemy spawns
wave_kills     DSB 1           ; Kills since last wave

; Boss system
boss_active    DSB 1           ; 0 = no boss, 1 = boss active
boss_hp        DSB 1           ; Boss current HP
boss_x         DSB 1           ; Boss X position
boss_y         DSB 1           ; Boss Y position
boss_timer     DSB 1           ; Boss attack timer
boss_phase     DSB 1           ; Boss attack phase (0-2)
boss_dir       DSB 1           ; Boss movement direction (0=left, 1=right)

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
bullet_vx      DSB 8       ; Horizontal velocity for spread shot
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

; Parallax starfield
star_x           DSB 20
star_y           DSB 20
star_speed       DSB 20

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
