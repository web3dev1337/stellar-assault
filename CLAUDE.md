# Stellar Assault - NES Development Guide

## 🚨 MANDATORY: Read This Entire Document 🚨

This file contains the complete 6502 assembly specification, NES hardware documentation, modern tooling guidelines, and best practices. Read every section before starting work.

## 🚨 FIRST STEPS 🚨

**Before ANY work:**
1. Check current git branch: `git branch --show-current`
2. If on master, create feature branch: `git fetch origin master && git checkout -b feature/your-feature origin/master`
3. Read ENTIRE CLAUDE.md file (this document)
4. Set up development environment

**When done:**
1. Commit and push regularly
2. Create PR using `gh pr create`
3. Include PR URL in response to user

---

# 6502 Assembly Language - Complete Specification

## 1. Scope and Intent

This document defines everything required to:
- Correctly write, analyze, generate, and optimize 6502 assembly
- Build emulators, assemblers, static analyzers
- Apply modern software engineering discipline to NES development
- Avoid folklore, myths, and emulator-only behavior unless explicitly stated

## 2. Architectural Overview

### 2.1 Core Characteristics

| Property | Value |
|----------|-------|
| CPU width | 8-bit |
| Address space | 16-bit (64 KB) |
| Endianness | Little-endian |
| Instruction size | 1–3 bytes |
| Stack | Fixed page ($0100–$01FF) |
| Flags | 8 |
| Clock model | Deterministic, cycle-counted |

## 3. Registers

| Register | Size | Purpose |
|----------|------|---------|
| A | 8-bit | Accumulator |
| X | 8-bit | Index |
| Y | 8-bit | Index |
| SP | 8-bit | Stack pointer |
| PC | 16-bit | Program counter |
| P | 8-bit | Processor status |

### 3.1 Status Flags (P)

```
Bit:  7 6 5 4 3 2 1 0
Flag: N V - B D I Z C
```

| Flag | Meaning |
|------|---------|
| N | Negative (bit 7 of result) |
| V | Overflow (signed overflow) |
| B | Break (only on stack) |
| D | Decimal (BCD mode) |
| I | Interrupt disable |
| Z | Zero |
| C | Carry |

**Note:** Bit 5 is unused but always reads as 1 when pushed.

## 4. Memory Model

### 4.1 Addressing
- Flat 64 KB memory space
- No memory protection
- No segmentation
- No MMU

### 4.2 Zero Page
- Addresses $0000–$00FF
- Faster addressing
- Frequently used for variables and pointers
- Treat as registers by competent code

### 4.3 Stack
- Fixed to $0100–$01FF
- SP decrements on push
- Grows downward
- Wraps silently on overflow

## 5. Instruction Encoding

### 5.1 Opcode Structure
- Exactly 256 opcodes
- Each opcode is 1 byte
- Operands follow opcode

### 5.2 Instruction Length

| Length | Meaning |
|--------|---------|
| 1 | Implied / Accumulator |
| 2 | Immediate / Zero Page / Relative |
| 3 | Absolute |

## 6. Addressing Modes (Authoritative)

| Mode | Syntax | Notes |
|------|--------|-------|
| Implied | `CLC` | No operand |
| Accumulator | `ASL A` | Operates on A |
| Immediate | `LDA #$10` | Constant |
| Zero Page | `LDA $20` | Fast |
| Zero Page,X | `LDA $20,X` | Wraps |
| Zero Page,Y | `LDX $20,Y` | Wraps |
| Absolute | `LDA $1234` | Full address |
| Absolute,X | `LDA $1234,X` | Page penalty |
| Absolute,Y | `LDA $1234,Y` | Page penalty |
| Indirect | `JMP ($1234)` | Buggy |
| Indexed Indirect | `LDA ($20,X)` | Pointer table |
| Indirect Indexed | `LDA ($20),Y` | Pointer + Y |
| Relative | `BEQ label` | ±127 bytes |

## 7. The JMP Indirect Bug (Mandatory Knowledge)

```asm
JMP ($12FF)
```

Reads low byte from $12FF, high byte from $1200, not $1300.

**This is real hardware behavior and must be preserved for compatibility.**

## 8. Instruction Set Summary

### 8.1 Official Instructions (By Category)

**Load / Store**
- LDA, LDX, LDY, STA, STX, STY

**Arithmetic**
- ADC, SBC

**Logic**
- AND, ORA, EOR, BIT

**Shifts / Rotates**
- ASL, LSR, ROL, ROR

**Increments / Decrements**
- INC, INX, INY, DEC, DEX, DEY

**Comparisons**
- CMP, CPX, CPY

**Branches**
- BCC, BCS, BEQ, BMI, BNE, BPL, BVC, BVS

**Jumps / Calls**
- JMP, JSR, RTS, RTI

**Stack**
- PHA, PLA, PHP, PLP

**Flags**
- CLC, SEC, CLI, SEI, CLV, CLD, SED

**System**
- BRK, NOP

## 9. Cycle Accuracy (Required for Emulation & Games)

- Every instruction has a fixed base cycle cost
- Some addressing modes add +1 cycle on page boundary cross
- Branches:
  - +1 cycle if taken
  - +2 cycles if page crossed
- Cycle accuracy is non-optional for:
  - Deterministic gameplay
  - Synchronizing audio / video
  - Proper PPU/APU timing

## 10. Illegal / Undocumented Opcodes

### 10.1 Facts
- ~105 undocumented opcodes
- Many are stable across silicon
- Widely used in demos and games

### 10.2 Best Practice
- Document but sandbox
- Allow opt-in usage
- Never rely on them unless explicitly required
- Examples: LAX, SAX, DCP, ISC, RLA, RRA

## 11. Modern Best Practices

### 11.1 Treat Zero Page as Registers
```asm
zp_ptr_lo = $00
zp_ptr_hi = $01
```

### 11.2 Avoid Self-Modifying Code
Unless:
- Emulator target
- Performance-critical demo
- Puzzle mechanic

### 11.3 Prefer Table-Driven Logic
6502 excels at:
- Lookup tables
- Jump tables
- State machines

### 11.4 Deterministic Control Flow
Avoid:
- Implicit flag reliance across long spans
- Hidden side effects

## 12. Structured Programming on 6502

### 12.1 Calling Convention (Recommended)

| Register | Usage |
|----------|-------|
| A | Return value |
| X | Temp / index |
| Y | Temp / index |
| Stack | Parameters |

### 12.2 Example
```asm
JSR func
; A = result
```

## 13. Interrupts

| Vector | Address |
|--------|---------|
| NMI | $FFFA |
| RESET | $FFFC |
| IRQ/BRK | $FFFE |

**Rules:**
- Interrupt pushes PC and P
- B flag differs for BRK vs IRQ
- Always preserve registers

## 14. Decimal Mode (BCD)

- Enabled via SED
- Affects ADC, SBC
- **Ignored on NES (2A03 CPU has no decimal mode)**
- Supported on real 6502 silicon

**Modern guidance:**
- Disable unless explicitly needed (not available on NES anyway)
- Many emulators mishandle edge cases

---

# NES Hardware Specification

## NES Architecture Overview

The NES (Nintendo Entertainment System) / Famicom uses a **2A03 CPU** (modified 6502 with integrated APU and no decimal mode).

### Hardware Components

| Component | Description |
|-----------|-------------|
| **CPU** | 2A03 (6502-based, 1.79 MHz NTSC) |
| **PPU** | Picture Processing Unit (2C02) |
| **APU** | Audio Processing Unit (integrated in 2A03) |
| **RAM** | 2KB internal RAM ($0000-$07FF, mirrored) |
| **VRAM** | 2KB video RAM (PPU) |
| **PRG-ROM** | Program code (typically 16KB-512KB) |
| **CHR-ROM/RAM** | Graphics data (8KB typical) |

## Memory Map

### CPU Memory Map

| Address Range | Description |
|---------------|-------------|
| $0000-$07FF | 2KB internal RAM |
| $0800-$1FFF | Mirrors of RAM |
| $2000-$2007 | PPU registers |
| $2008-$3FFF | Mirrors of PPU registers |
| $4000-$4017 | APU and I/O registers |
| $4018-$401F | Test mode / disabled |
| $4020-$FFFF | Cartridge space (PRG-ROM, mapper registers) |

### PPU Memory Map

| Address Range | Description |
|---------------|-------------|
| $0000-$1FFF | Pattern tables (CHR-ROM/RAM) |
| $2000-$23FF | Nametable 0 |
| $2400-$27FF | Nametable 1 |
| $2800-$2BFF | Nametable 2 |
| $2C00-$2FFF | Nametable 3 |
| $3000-$3EFF | Mirrors of nametables |
| $3F00-$3F1F | Palette RAM |
| $3F20-$3FFF | Mirrors of palette |

## PPU (Picture Processing Unit)

### PPU Registers (CPU $2000-$2007)

| Address | Register | Purpose |
|---------|----------|---------|
| $2000 | PPUCTRL | PPU control |
| $2001 | PPUMASK | PPU mask (show/hide sprites/bg) |
| $2002 | PPUSTATUS | PPU status (VBlank, sprite 0 hit) |
| $2003 | OAMADDR | OAM (sprite) address |
| $2004 | OAMDATA | OAM data read/write |
| $2005 | PPUSCROLL | Scroll position |
| $2006 | PPUADDR | PPU address |
| $2007 | PPUDATA | PPU data read/write |

### Sprites (OAM - Object Attribute Memory)

- 64 sprites maximum
- 8 sprites per scanline limit
- 4 bytes per sprite:
  - Byte 0: Y position
  - Byte 1: Tile index
  - Byte 2: Attributes (palette, priority, flip)
  - Byte 3: X position

### Backgrounds

- 32x30 tiles (256x240 pixels)
- 4 nametables (supports scrolling)
- 8x8 pixel tiles
- 4 palette groups (4 colors each)

## APU (Audio Processing Unit)

### Channels

| Channel | Type | Description |
|---------|------|-------------|
| Pulse 1 | $4000-$4003 | Square wave |
| Pulse 2 | $4004-$4007 | Square wave |
| Triangle | $4008-$400B | Triangle wave |
| Noise | $400C-$400F | Noise generator |
| DMC | $4010-$4013 | Sample playback |

### Key Registers

| Address | Purpose |
|---------|---------|
| $4015 | Channel enable |
| $4017 | Frame counter |

## NES ROM Format (.nes / iNES)

### iNES Header (16 bytes)

```
Offset  Description
0-3     "NES" followed by MS-DOS EOF ($1A)
4       PRG-ROM size (16KB units)
5       CHR-ROM size (8KB units)
6       Flags 6 (mapper, mirroring, etc.)
7       Flags 7 (mapper)
8       PRG-RAM size (8KB units)
9       TV system
10      TV system, PRG-RAM
11-15   Unused (should be zero)
```

### Typical Memory Layout

```
Header (16 bytes)
PRG-ROM (Program code)
CHR-ROM (Graphics data)
```

---

# Modern NES Development Toolchain (2025)

## Recommended Toolchain

Based on comprehensive research, the optimal toolchain for modern NES development is:

### Assembler: **asm6f**

**Why asm6f:**
- ✅ Actively maintained (latest release: **January 27, 2025**)
- ✅ Easiest CI/CD integration (single command, no config files)
- ✅ Modern tooling (Mesen/FamiStudio symbol export)
- ✅ Fast compilation (perfect for test-driven development)
- ✅ Clean, simple syntax
- ✅ Community momentum ("common go-to" in 2024-2025)
- ✅ NES-native (designed specifically for NES/Famicom)

**Installation:**
```bash
git clone https://github.com/freem/asm6f
cd asm6f && gcc -o asm6f asm6f.c
sudo cp asm6f /usr/local/bin/
```

**Usage:**
```bash
asm6f game.asm game.nes
```

**Alternative: cc65/ca65** (for large projects with C integration)
- More powerful but requires linker configuration
- Best for teams or mixed C/assembly projects

### Emulator: **Mesen2**

**Why Mesen2:**
- ✅ Native headless mode via `--testrunner` flag
- ✅ Lua scripting with exit code support (0 = pass, 1+ = fail)
- ✅ 96.61% accuracy on standardized test ROMs (highest)
- ✅ Cycle-accurate CPU, PPU, and APU emulation
- ✅ Excellent debugging features
- ✅ Active maintenance (latest release: July 2025)
- ✅ Cross-platform (Windows, Linux, macOS)

**Installation:**
```bash
wget https://github.com/SourMesen/Mesen2/releases/latest/download/Mesen2-linux-x64.tar.gz
tar -xzf Mesen2-linux-x64.tar.gz
chmod +x mesen
sudo mv mesen /usr/local/bin/
```

**Headless Testing:**
```bash
mesen --testrunner game.nes test_script.lua
```

### Linter: **lin6**

**Installation:**
```bash
git clone https://git.sr.ht/~rabbits/lin6
cd lin6 && make
sudo cp lin6 /usr/local/bin/
```

**Usage:**
```bash
lin6 src/*.asm
```

### Testing Framework: **NESTest**

NESTest is a modern unit testing framework for NES (cc65/Mesen).

**Repository:** https://github.com/Akadeax/nestest

## Build System

### Makefile Template

```makefile
# Makefile for NES development with asm6f

ASM = asm6f
EMULATOR = mesen
SRC = src/main.asm
ROM = build/game.nes
TEST_SCRIPT = tests/test.lua

.PHONY: all clean run test lint

all: $(ROM)

$(ROM): $(SRC)
	@mkdir -p build
	$(ASM) $(SRC) $(ROM)

run: $(ROM)
	$(EMULATOR) $(ROM)

test: $(ROM)
	$(EMULATOR) --testrunner $(ROM) $(TEST_SCRIPT)

lint:
	lin6 src/*.asm

clean:
	rm -rf build/
```

## Testing Strategy

### Test ROM Suites (for validation)

1. **nestest** - Basic CPU instruction validation
   - Automation mode: Jump to $C000
   - No PPU/APU/input required
   - Clear pass/fail output

2. **blargg_nes_cpu_test5** - Comprehensive CPU tests
   - 18 separate test ROMs
   - Covers all instructions, addressing modes, edge cases

3. **ppu_vbl_nmi** - PPU VBL flag and NMI timing
   - 11 test ROMs for accurate PPU emulation

**Test ROM Repository:**
https://github.com/christopherpow/nes-test-roms

### Automated Testing with Mesen2

**Example Lua Test Script:**

```lua
-- Generic test ROM validator
local maxFrames = 3600  -- 60 seconds at 60 FPS
local frameCount = 0

emu.addEventCallback(function()
  frameCount = frameCount + 1

  -- Check result register
  local result = emu.read(0x6000, emu.memType.cpu)

  if result == 0x00 then
    print("TEST PASSED")
    emu.stop(0)
  elseif result ~= 0x80 then  -- 0x80 = test running
    print("TEST FAILED: " .. result)
    emu.stop(1)
  end

  -- Timeout protection
  if frameCount >= maxFrames then
    print("TEST TIMEOUT")
    emu.stop(2)
  end
end, emu.eventType.inputPolled)
```

## CI/CD Pipeline

### GitHub Actions Workflow

```yaml
name: NES ROM CI/CD

on: [push, pull_request]

jobs:
  build-and-test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      # Install asm6f
      - name: Install asm6f
        run: |
          git clone https://github.com/freem/asm6f
          cd asm6f && gcc -o asm6f asm6f.c
          sudo cp asm6f /usr/local/bin/

      # Install Mesen2
      - name: Install Mesen2
        run: |
          wget https://github.com/SourMesen/Mesen2/releases/latest/download/Mesen2-linux-x64.tar.gz
          tar -xzf Mesen2-linux-x64.tar.gz
          chmod +x mesen
          sudo mv mesen /usr/local/bin/

      # Install lin6
      - name: Install lin6
        run: |
          git clone https://git.sr.ht/~rabbits/lin6
          cd lin6 && make
          sudo cp lin6 /usr/local/bin/

      # Lint
      - name: Lint assembly
        run: make lint

      # Build
      - name: Build ROM
        run: make all

      # Test
      - name: Run tests
        run: make test

      # Run nestest validation
      - name: Validate CPU
        run: |
          mesen --testrunner test-roms/nestest.nes tests/nestest.lua

      # Upload ROM artifact
      - name: Upload ROM
        uses: actions/upload-artifact@v3
        with:
          name: stellar-assault.nes
          path: build/game.nes
```

---

# Code Style Guidelines

## Assembly Style

### Naming Conventions

```asm
; Constants (SCREAMING_SNAKE_CASE)
SCREEN_WIDTH = 256
SPRITE_SIZE = 8

; Labels (snake_case for local, PascalCase for public)
main_loop:
  JSR UpdateSprites
  JMP main_loop

UpdateSprites:
  ; Public subroutine
  RTS

.local_helper:
  ; Local subroutine (use . prefix)
  RTS
```

### Commenting

```asm
; ============================================
; Module: Player Movement
; ============================================

; UpdatePlayer - Update player position and animation
; Inputs: None
; Outputs: None
; Clobbers: A, X, Y
UpdatePlayer:
  LDA player_x
  CLC
  ADC player_dx      ; Add velocity to position
  STA player_x       ; Store new position
  RTS
```

### Code Organization

```asm
; 1. Constants and includes
.include "constants.inc"
.include "macros.inc"

; 2. Zero page variables
.segment "ZEROPAGE"
temp:       .res 1
pointer:    .res 2

; 3. RAM variables
.segment "BSS"
player_x:   .res 1
player_y:   .res 1

; 4. Code
.segment "CODE"

; Reset vector
Reset:
  ; Initialization
  ; ...

; 5. Interrupt handlers
NMI:
  ; VBlank handler
  RTI

; 6. Data tables
.segment "RODATA"
sprite_table:
  .byte $00, $01, $02, $03
```

## Project Structure

```
stellar-assault/
├── src/
│   ├── main.asm           # Entry point
│   ├── init.asm           # Initialization
│   ├── game.asm           # Game logic
│   ├── player.asm         # Player routines
│   ├── enemies.asm        # Enemy routines
│   ├── rendering.asm      # PPU/drawing code
│   ├── sound.asm          # APU/music code
│   ├── input.asm          # Controller input
│   ├── constants.inc      # Constants
│   └── macros.inc         # Macros
├── tests/
│   ├── test.lua           # Main test script
│   ├── nestest.lua        # CPU validation
│   └── test-roms/         # Standard test ROMs
├── assets/
│   ├── chr/               # Graphics data
│   └── sfx/               # Sound effects
├── build/                 # Build outputs (gitignored)
├── Makefile
├── README.md
└── CLAUDE.md             # This file
```

---

# NES Programming Patterns

## PPU Update Pattern (during VBlank)

```asm
NMI:
  ; Save registers
  PHA
  TXA
  PHA
  TYA
  PHA

  ; Check if we should update PPU
  LDA nmi_ready
  BEQ @skip

  ; Update PPU during VBlank
  JSR update_background
  JSR update_sprites

  ; Clear flag
  LDA #0
  STA nmi_ready

@skip:
  ; Restore registers
  PLA
  TAY
  PLA
  TAX
  PLA
  RTI
```

## Sprite DMA Pattern

```asm
; Fast sprite upload using $4014 (OAM DMA)
update_sprites:
  LDA #$00
  STA OAMADDR      ; Reset OAM address

  LDA #>oam_buffer ; High byte of OAM buffer
  STA $4014        ; Trigger DMA
  RTS

; OAM buffer (256 bytes, page-aligned)
.segment "BSS"
.align 256
oam_buffer: .res 256
```

## Controller Reading Pattern

```asm
read_controller:
  ; Strobe controller
  LDA #1
  STA $4016
  LDA #0
  STA $4016

  ; Read 8 buttons
  LDX #8
@loop:
  LDA $4016
  LSR A            ; Bit 0 = button state
  ROL buttons      ; Shift into buttons variable
  DEX
  BNE @loop
  RTS

; Button masks
BUTTON_A      = %10000000
BUTTON_B      = %01000000
BUTTON_SELECT = %00100000
BUTTON_START  = %00010000
BUTTON_UP     = %00001000
BUTTON_DOWN   = %00000100
BUTTON_LEFT   = %00000010
BUTTON_RIGHT  = %00000001
```

## Scrolling Pattern

```asm
; Set scroll position (must be in VBlank)
set_scroll:
  BIT $2002        ; Reset PPU latch

  LDA scroll_x
  STA $2005        ; X scroll

  LDA scroll_y
  STA $2005        ; Y scroll
  RTS
```

---

# Performance Optimization

## Cycle Counting

Always be aware of instruction cycle costs:

| Operation | Cycles | Notes |
|-----------|--------|-------|
| LDA #imm | 2 | Fastest |
| LDA zp | 3 | Fast |
| LDA abs | 4 | Slower |
| LDA abs,X | 4+ | +1 if page crossed |

## Zero Page Usage

```asm
; BAD (slower)
LDA $0200

; GOOD (faster)
LDA $20
```

## Loop Unrolling

```asm
; BAD (slower, 7 cycles per iteration)
  LDX #8
@loop:
  STA buffer,X
  DEX
  BNE @loop

; GOOD (faster, 4 cycles per store)
  STA buffer+0
  STA buffer+1
  STA buffer+2
  STA buffer+3
  STA buffer+4
  STA buffer+5
  STA buffer+6
  STA buffer+7
```

## Table Lookups

```asm
; Multiplication by table lookup (faster than repeated addition)
multiply_by_16:
  TAX
  LDA mul16_table,X
  RTS

mul16_table:
  .byte 0*16, 1*16, 2*16, 3*16, 4*16, 5*16, 6*16, 7*16
  ; ... etc
```

---

# Debugging Tips

## Mesen Debugger

- Set breakpoints on memory access (read/write/execute)
- Watch memory regions in real-time
- Step through code instruction by instruction
- View PPU state (tiles, sprites, palettes)

## Debug Macros

```asm
; Write debug value to a visible memory location
.macro DEBUG_WRITE addr, value
  LDA #value
  STA addr
.endmacro

; Infinite loop for debugging
.macro DEBUG_HALT
@halt:
  JMP @halt
.endmacro
```

## Logging Pattern

```asm
; Write to a log buffer for later analysis
log_event:
  LDX log_index
  LDA event_type
  STA log_buffer,X
  INX
  STX log_index
  RTS
```

---

# Common Gotchas

## PPU Address Latch

The PPU address is set via two writes to $2006. Always reset the latch with a read from $2002:

```asm
; WRONG (might use wrong address)
LDA #$20
STA $2006
LDA #$00
STA $2006

; CORRECT (reset latch first)
BIT $2002        ; Reset latch
LDA #$20
STA $2006
LDA #$00
STA $2006
```

## Sprite 0 Hit Timing

Sprite 0 hit detection is tricky:

```asm
wait_sprite0:
  BIT $2002
  BVS wait_sprite0  ; Wait until sprite 0 hit clears
@wait:
  BIT $2002
  BVC @wait         ; Wait until sprite 0 hit sets
  RTS
```

## VBlank Timing

You only have ~2273 CPU cycles during VBlank (NTSC). Plan PPU updates carefully.

## Mapper Gotchas

Different mappers have different register layouts. Document which mapper you're targeting.

---

# References

## Essential Reading

- **NESDev Wiki**: https://www.nesdev.org/wiki/
- **6502 Reference**: http://www.6502.org/
- **Mesen Documentation**: https://www.mesen.ca/docs/

## Test ROM Resources

- **christopherpow/nes-test-roms**: https://github.com/christopherpow/nes-test-roms
- **NESDev Emulator Tests**: https://www.nesdev.org/wiki/Emulator_tests

## Community

- **NESDev Forums**: https://forums.nesdev.org/
- **Reddit /r/nesdev**: https://www.reddit.com/r/nesdev/

---

# Development Commands

```bash
# Build ROM
make

# Run in emulator
make run

# Run tests
make test

# Lint code
make lint

# Clean build
make clean
```

---

# Summary

This document provides everything needed to develop professional-quality NES games using modern tools and best practices. The combination of:

- **asm6f** (assembler)
- **Mesen2** (emulator/testing)
- **lin6** (linting)
- **GitHub Actions** (CI/CD)
- **Standard test ROMs** (validation)

...creates a robust, automated development workflow that rivals modern game development while targeting vintage hardware.

**Remember:** The 6502 is fully enumerable and deterministic. There are no hidden behaviors. Write clear, tested, cycle-aware code and you will create something truly impressive.
