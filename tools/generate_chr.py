#!/usr/bin/env python3
"""
Generate CHR-ROM data for Stellar Assault
Creates 8KB of tile/sprite graphics data with BETTER sprites!
"""

def create_sprite(pattern):
    """Convert 8x8 pattern to NES CHR format (2 bitplanes)"""
    bitplane0 = []
    bitplane1 = []

    for row in pattern:
        bp0 = 0
        bp1 = 0
        for bit_pos, pixel in enumerate(row):
            if pixel >= 1:
                bp0 |= (1 << (7 - bit_pos))
            if pixel >= 2:
                bp1 |= (1 << (7 - bit_pos))
        bitplane0.append(bp0)
        bitplane1.append(bp1)

    return bytes(bitplane0 + bitplane1)

# Define sprites (0 = transparent, 1-3 = palette colors)

# ===== PLAYER SHIP (sleek fighter) =====
player_ship = [
    [0,0,0,3,3,0,0,0],
    [0,0,0,3,3,0,0,0],
    [0,0,2,3,3,2,0,0],
    [0,0,2,3,3,2,0,0],
    [0,2,2,3,3,2,2,0],
    [1,2,2,2,2,2,2,1],
    [1,2,1,2,2,1,2,1],
    [1,1,0,0,0,0,1,1],
]

# Player with thrust animation
player_thrust = [
    [0,0,0,3,3,0,0,0],
    [0,0,0,3,3,0,0,0],
    [0,0,2,3,3,2,0,0],
    [0,0,2,3,3,2,0,0],
    [0,2,2,3,3,2,2,0],
    [1,2,2,2,2,2,2,1],
    [1,2,1,2,2,1,2,1],
    [1,1,0,3,3,0,1,1],
]

# ===== PLAYER BULLETS =====
player_bullet = [
    [0,0,0,3,3,0,0,0],
    [0,0,0,3,3,0,0,0],
    [0,0,1,3,3,1,0,0],
    [0,0,1,2,2,1,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
]

# Spread bullet (smaller)
spread_bullet = [
    [0,0,0,0,0,0,0,0],
    [0,0,0,3,3,0,0,0],
    [0,0,1,3,3,1,0,0],
    [0,0,0,2,2,0,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
]

# ===== ENEMY 1: Basic grunt (insect-like) =====
enemy1 = [
    [0,1,0,0,0,0,1,0],
    [1,0,1,2,2,1,0,1],
    [0,1,2,3,3,2,1,0],
    [0,2,3,3,3,3,2,0],
    [0,2,2,3,3,2,2,0],
    [0,1,2,2,2,2,1,0],
    [0,0,1,0,0,1,0,0],
    [0,1,0,0,0,0,1,0],
]

# ===== ENEMY 2: Shooter (angular ship) =====
enemy2 = [
    [0,0,0,2,2,0,0,0],
    [0,0,2,3,3,2,0,0],
    [0,2,3,3,3,3,2,0],
    [2,3,3,1,1,3,3,2],
    [2,3,3,1,1,3,3,2],
    [0,2,3,3,3,3,2,0],
    [0,0,2,3,3,2,0,0],
    [0,0,0,2,2,0,0,0],
]

# ===== ENEMY 3: Fast (dart shape) =====
enemy3 = [
    [0,0,0,1,1,0,0,0],
    [0,0,1,2,2,1,0,0],
    [0,1,2,3,3,2,1,0],
    [1,2,3,3,3,3,2,1],
    [0,1,2,3,3,2,1,0],
    [0,0,1,2,2,1,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,0,0,0,0,0],
]

# ===== BOSS (large, menacing) - 4 tiles =====
boss_tl = [
    [0,0,0,1,1,2,2,2],
    [0,0,1,2,3,3,3,3],
    [0,1,2,3,3,3,3,3],
    [1,2,3,3,1,1,3,3],
    [1,2,3,1,3,3,1,3],
    [1,2,3,1,3,3,1,3],
    [1,2,3,3,1,1,3,3],
    [1,2,3,3,3,3,3,3],
]

boss_tr = [
    [2,2,2,1,1,0,0,0],
    [3,3,3,3,2,1,0,0],
    [3,3,3,3,3,2,1,0],
    [3,3,1,1,3,3,2,1],
    [3,1,3,3,1,3,2,1],
    [3,1,3,3,1,3,2,1],
    [3,3,1,1,3,3,2,1],
    [3,3,3,3,3,3,2,1],
]

boss_bl = [
    [1,2,3,3,3,3,3,3],
    [1,2,3,3,3,3,3,3],
    [0,1,2,3,3,3,3,3],
    [0,0,1,2,3,3,3,3],
    [0,0,0,1,2,2,2,2],
    [0,0,0,0,1,1,1,1],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
]

boss_br = [
    [3,3,3,3,3,3,2,1],
    [3,3,3,3,3,3,2,1],
    [3,3,3,3,3,2,1,0],
    [3,3,3,3,2,1,0,0],
    [2,2,2,2,1,0,0,0],
    [1,1,1,1,0,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
]

# ===== ENEMY BULLET =====
enemy_bullet = [
    [0,0,0,0,0,0,0,0],
    [0,0,0,2,2,0,0,0],
    [0,0,2,3,3,2,0,0],
    [0,0,2,3,3,2,0,0],
    [0,0,0,2,2,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
]

# ===== POWERUPS =====
powerup_weapon = [
    [0,1,1,1,1,1,1,0],
    [1,2,2,2,2,2,2,1],
    [1,2,3,3,3,3,2,1],
    [1,2,3,1,1,3,2,1],
    [1,2,3,1,1,3,2,1],
    [1,2,3,3,3,3,2,1],
    [1,2,2,2,2,2,2,1],
    [0,1,1,1,1,1,1,0],
]

powerup_health = [
    [0,0,1,1,1,1,0,0],
    [0,1,3,3,3,3,1,0],
    [1,3,3,2,2,3,3,1],
    [1,3,2,3,3,2,3,1],
    [1,3,2,3,3,2,3,1],
    [1,3,3,2,2,3,3,1],
    [0,1,3,3,3,3,1,0],
    [0,0,1,1,1,1,0,0],
]

powerup_shield = [
    [0,0,1,1,1,1,0,0],
    [0,1,2,2,2,2,1,0],
    [1,2,3,2,2,3,2,1],
    [1,2,2,3,3,2,2,1],
    [1,2,2,3,3,2,2,1],
    [1,2,3,2,2,3,2,1],
    [0,1,2,2,2,2,1,0],
    [0,0,1,1,1,1,0,0],
]

powerup_bomb = [
    [0,0,0,1,1,0,0,0],
    [0,0,1,2,2,1,0,0],
    [0,1,2,3,3,2,1,0],
    [0,1,2,3,3,2,1,0],
    [0,1,2,3,3,2,1,0],
    [0,1,2,3,3,2,1,0],
    [0,0,1,2,2,1,0,0],
    [0,0,0,1,1,0,0,0],
]

# ===== EXPLOSIONS =====
explosion1 = [
    [0,0,0,0,0,0,0,0],
    [0,0,0,2,2,0,0,0],
    [0,0,2,3,3,2,0,0],
    [0,2,3,3,3,3,2,0],
    [0,2,3,3,3,3,2,0],
    [0,0,2,3,3,2,0,0],
    [0,0,0,2,2,0,0,0],
    [0,0,0,0,0,0,0,0],
]

explosion2 = [
    [0,0,1,0,0,1,0,0],
    [0,1,2,2,2,2,1,0],
    [1,2,3,3,3,3,2,1],
    [0,2,3,2,2,3,2,0],
    [0,2,3,2,2,3,2,0],
    [1,2,3,3,3,3,2,1],
    [0,1,2,2,2,2,1,0],
    [0,0,1,0,0,1,0,0],
]

explosion3 = [
    [1,0,0,1,1,0,0,1],
    [0,1,2,2,2,2,1,0],
    [0,2,1,3,3,1,2,0],
    [1,2,3,1,1,3,2,1],
    [1,2,3,1,1,3,2,1],
    [0,2,1,3,3,1,2,0],
    [0,1,2,2,2,2,1,0],
    [1,0,0,1,1,0,0,1],
]

explosion4 = [
    [1,0,1,0,0,1,0,1],
    [0,1,0,1,1,0,1,0],
    [1,0,1,2,2,1,0,1],
    [0,1,2,1,1,2,1,0],
    [0,1,2,1,1,2,1,0],
    [1,0,1,2,2,1,0,1],
    [0,1,0,1,1,0,1,0],
    [1,0,1,0,0,1,0,1],
]

# ===== SHIELD BUBBLE =====
shield = [
    [0,1,1,1,1,1,1,0],
    [1,0,0,0,0,0,0,1],
    [1,0,0,0,0,0,0,1],
    [1,0,0,0,0,0,0,1],
    [1,0,0,0,0,0,0,1],
    [1,0,0,0,0,0,0,1],
    [1,0,0,0,0,0,0,1],
    [0,1,1,1,1,1,1,0],
]

# ===== STAR =====
star = [
    [0,0,0,0,0,0,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
]

# Empty tile
empty = [[0]*8 for _ in range(8)]

# Number tiles 0-9 for score display
def make_digit(pattern_str):
    """Convert string pattern to 8x8 grid"""
    lines = pattern_str.strip().split('\n')
    result = []
    for line in lines:
        row = [int(c) if c != '.' else 0 for c in line]
        while len(row) < 8:
            row.append(0)
        result.append(row[:8])
    while len(result) < 8:
        result.append([0]*8)
    return result

digit_0 = make_digit("""
.1111..
1....1.
1....1.
1....1.
1....1.
1....1.
.1111..
.......
""")

digit_1 = make_digit("""
...1...
..11...
...1...
...1...
...1...
...1...
..111..
.......
""")

digit_2 = make_digit("""
.1111..
1....1.
.....1.
..111..
.1.....
1......
111111.
.......
""")

digit_3 = make_digit("""
.1111..
1....1.
.....1.
..111..
.....1.
1....1.
.1111..
.......
""")

digit_4 = make_digit("""
1....1.
1....1.
1....1.
111111.
.....1.
.....1.
.....1.
.......
""")

digit_5 = make_digit("""
111111.
1......
11111..
.....1.
.....1.
1....1.
.1111..
.......
""")

digit_6 = make_digit("""
.1111..
1......
1......
11111..
1....1.
1....1.
.1111..
.......
""")

digit_7 = make_digit("""
111111.
.....1.
....1..
...1...
..1....
..1....
..1....
.......
""")

digit_8 = make_digit("""
.1111..
1....1.
1....1.
.1111..
1....1.
1....1.
.1111..
.......
""")

digit_9 = make_digit("""
.1111..
1....1.
1....1.
.11111.
.....1.
.....1.
.1111..
.......
""")

# Build CHR-ROM (8KB = 512 tiles)
chr_data = bytearray()

# Pattern Table 0 (Sprites) - Tiles $00-$FF
sprites = [
    player_ship,      # $00 - Player
    player_thrust,    # $01 - Player with thrust
    empty,            # $02
    empty,            # $03
    player_bullet,    # $04 - Main bullet
    spread_bullet,    # $05 - Spread bullet
    empty,            # $06
    empty,            # $07
    enemy1,           # $08 - Basic enemy
    enemy2,           # $09 - Shooter enemy
    enemy3,           # $0A - Fast enemy
    empty,            # $0B
    enemy_bullet,     # $0C - Enemy bullet
    empty,            # $0D
    empty,            # $0E
    empty,            # $0F
    powerup_weapon,   # $10 - Weapon powerup
    powerup_health,   # $11 - Health powerup
    powerup_shield,   # $12 - Shield powerup
    powerup_bomb,     # $13 - Bomb powerup
    explosion1,       # $14 - Explosion frame 1
    explosion2,       # $15 - Explosion frame 2
    explosion3,       # $16 - Explosion frame 3
    explosion4,       # $17 - Explosion frame 4
    shield,           # $18 - Shield bubble
    star,             # $19 - Star for background
    empty,            # $1A
    empty,            # $1B
    boss_tl,          # $1C - Boss top-left
    boss_tr,          # $1D - Boss top-right
    boss_bl,          # $1E - Boss bottom-left
    boss_br,          # $1F - Boss bottom-right
]

# Add sprites to CHR data
for sprite in sprites:
    chr_data.extend(create_sprite(sprite))

# Fill remaining pattern table 0 (256 tiles total)
for i in range(256 - len(sprites)):
    chr_data.extend(create_sprite(empty))

# Pattern Table 1 (Background) - Tiles $00-$FF
# Tile $00: Empty (black)
chr_data.extend(create_sprite(empty))

# Tiles $01-$0F: Stars of different patterns
star_patterns = [
    [[0,0,0,1,0,0,0,0], [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0],
     [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0]],
    [[0,0,0,0,0,0,0,0], [0,0,0,0,0,0,1,0], [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0],
     [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0]],
    [[0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0],
     [0,1,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0]],
]

for sp in star_patterns:
    chr_data.extend(create_sprite(sp))

# Fill more empty tiles
for i in range(12):
    chr_data.extend(create_sprite(empty))

# Tiles $30-$39: Digits 0-9 for score
digits = [digit_0, digit_1, digit_2, digit_3, digit_4, digit_5, digit_6, digit_7, digit_8, digit_9]

# Add padding to reach $30
current_tiles = 1 + 3 + 12  # empty + stars + padding = 16
for i in range(0x30 - current_tiles):
    chr_data.extend(create_sprite(empty))

# Add digits
for digit in digits:
    chr_data.extend(create_sprite(digit))

# Fill rest with empty
remaining = 256 - 0x3A
for i in range(remaining):
    chr_data.extend(create_sprite(empty))

# Ensure exactly 8KB
if len(chr_data) < 8192:
    chr_data.extend(bytes(8192 - len(chr_data)))
elif len(chr_data) > 8192:
    chr_data = chr_data[:8192]

assert len(chr_data) == 8192, f"CHR-ROM must be 8KB, got {len(chr_data)} bytes"

# Write to file
with open('assets/chr/chr_data.chr', 'wb') as f:
    f.write(chr_data)

print(f"Generated {len(chr_data)} bytes of CHR-ROM data")
print("\nSprite mapping (Pattern Table 0):")
print("  $00: Player ship")
print("  $01: Player with thrust")
print("  $04: Main bullet")
print("  $05: Spread bullet")
print("  $08: Enemy 1 (basic)")
print("  $09: Enemy 2 (shooter)")
print("  $0A: Enemy 3 (fast)")
print("  $0C: Enemy bullet")
print("  $10: Powerup - Weapon")
print("  $11: Powerup - Health")
print("  $12: Powerup - Shield")
print("  $13: Powerup - Bomb")
print("  $14-$17: Explosion frames")
print("  $18: Shield bubble")
print("  $19: Star")
print("  $1C-$1F: Boss (4 tiles)")
print("\nBackground mapping (Pattern Table 1):")
print("  $00: Empty")
print("  $01-$03: Star patterns")
print("  $30-$39: Digits 0-9")
