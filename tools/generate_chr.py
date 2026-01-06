#!/usr/bin/env python3
"""
Generate CHR-ROM data for Stellar Assault
Creates 8KB of tile/sprite graphics data
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

# Sprite $00-$03: Player ship (16x16, 4 tiles)
player_top_left = [
    [0,0,1,1,1,1,0,0],
    [0,1,2,2,2,2,1,0],
    [1,2,3,3,3,3,2,1],
    [1,2,3,3,3,3,2,1],
    [1,2,2,2,2,2,2,1],
    [1,2,2,2,2,2,2,1],
    [1,2,2,1,1,2,2,1],
    [1,1,1,0,0,1,1,1],
]

player_top_right = [
    [0,0,1,1,1,1,0,0],
    [0,1,2,2,2,2,1,0],
    [1,2,3,3,3,3,2,1],
    [1,2,3,3,3,3,2,1],
    [1,2,2,2,2,2,2,1],
    [1,2,2,2,2,2,2,1],
    [1,2,2,1,1,2,2,1],
    [1,1,1,0,0,1,1,1],
]

player_bottom_left = [
    [0,1,1,0,0,1,1,0],
    [0,0,1,1,1,1,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
]

player_bottom_right = [
    [0,1,1,0,0,1,1,0],
    [0,0,1,1,1,1,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
]

# Sprite $04: Player bullet
player_bullet = [
    [0,0,0,1,1,0,0,0],
    [0,0,1,2,2,1,0,0],
    [0,1,2,3,3,2,1,0],
    [0,1,2,3,3,2,1,0],
    [0,0,1,2,2,1,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
]

# Sprite $08: Enemy (simple)
enemy1 = [
    [0,0,1,1,1,1,0,0],
    [0,1,2,2,2,2,1,0],
    [1,2,1,3,3,1,2,1],
    [1,2,3,3,3,3,2,1],
    [1,2,2,3,3,2,2,1],
    [1,1,2,2,2,2,1,1],
    [0,1,1,1,1,1,1,0],
    [0,0,1,0,0,1,0,0],
]

# Sprite $0C: Enemy bullet
enemy_bullet = [
    [0,0,0,0,0,0,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,1,2,2,1,0,0],
    [0,1,2,3,3,2,1,0],
    [0,0,1,2,2,1,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
]

# Sprite $10: Powerup
powerup = [
    [0,0,1,1,1,1,0,0],
    [0,1,2,3,3,2,1,0],
    [1,2,3,2,2,3,2,1],
    [1,3,2,3,3,2,3,1],
    [1,3,2,3,3,2,3,1],
    [1,2,3,2,2,3,2,1],
    [0,1,2,3,3,2,1,0],
    [0,0,1,1,1,1,0,0],
]

# Sprite $14-$17: Explosion frames
explosion1 = [
    [0,0,0,1,1,0,0,0],
    [0,0,1,2,2,1,0,0],
    [0,1,2,3,3,2,1,0],
    [1,2,3,3,3,3,2,1],
    [1,2,3,3,3,3,2,1],
    [0,1,2,3,3,2,1,0],
    [0,0,1,2,2,1,0,0],
    [0,0,0,1,1,0,0,0],
]

explosion2 = [
    [1,0,0,1,1,0,0,1],
    [0,1,1,2,2,1,1,0],
    [0,1,2,3,3,2,1,0],
    [1,2,3,2,2,3,2,1],
    [1,2,3,2,2,3,2,1],
    [0,1,2,3,3,2,1,0],
    [0,1,1,2,2,1,1,0],
    [1,0,0,1,1,0,0,1],
]

# Sprite $FE: Small particle
particle = [
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,1,2,2,1,0,0],
    [0,0,1,2,2,1,0,0],
    [0,0,0,1,1,0,0,0],
    [0,0,0,0,0,0,0,0],
    [0,0,0,0,0,0,0,0],
]

# Empty tile
empty = [[0]*8 for _ in range(8)]

# Build CHR-ROM (8KB = 512 tiles)
chr_data = bytearray()

# Add defined sprites
sprites = [
    player_top_left,     # $00
    player_top_right,    # $01
    player_bottom_left,  # $02
    player_bottom_right, # $03
    player_bullet,       # $04
    empty,               # $05
    empty,               # $06
    empty,               # $07
    enemy1,              # $08
    empty,               # $09
    empty,               # $0A
    empty,               # $0B
    enemy_bullet,        # $0C
    empty,               # $0D
    empty,               # $0E
    empty,               # $0F
    powerup,             # $10
    empty,               # $11
    empty,               # $12
    empty,               # $13
    explosion1,          # $14
    explosion2,          # $15
    empty,               # $16
    empty,               # $17
]

# Add sprites to CHR data
for sprite in sprites:
    chr_data.extend(create_sprite(sprite))

# Fill remaining pattern table 0 (256 tiles total)
for i in range(256 - len(sprites)):
    chr_data.extend(create_sprite(empty))

# Pattern table 1 (background tiles - 256 tiles)
# Tile $00: Solid black
black = [[0]*8 for _ in range(8)]
chr_data.extend(create_sprite(black))

# Tile $01: Stars (random dots)
stars = [
    [0,0,0,1,0,0,0,0],
    [0,0,0,0,0,0,1,0],
    [0,1,0,0,0,0,0,0],
    [0,0,0,0,1,0,0,0],
    [0,0,0,0,0,0,0,1],
    [1,0,0,0,0,0,0,0],
    [0,0,1,0,0,0,0,0],
    [0,0,0,0,0,1,0,0],
]
chr_data.extend(create_sprite(stars))

# Fill rest with empty
for i in range(254):
    chr_data.extend(create_sprite(empty))

# Add particle sprite at $FE
chr_data_list = list(chr_data)
particle_start = 0xFE * 16
chr_data_list[particle_start:particle_start+16] = create_sprite(particle)
chr_data = bytes(chr_data_list)

# Ensure exactly 8KB
assert len(chr_data) == 8192, f"CHR-ROM must be 8KB, got {len(chr_data)} bytes"

# Write to file
with open('assets/chr/chr_data.chr', 'wb') as f:
    f.write(chr_data)

print(f"Generated {len(chr_data)} bytes of CHR-ROM data")
print("Sprite mapping:")
print("  $00-$03: Player ship (16x16)")
print("  $04: Player bullet")
print("  $08: Enemy")
print("  $0C: Enemy bullet")
print("  $10: Powerup")
print("  $14-$15: Explosion frames")
print("  $FE: Particle")
