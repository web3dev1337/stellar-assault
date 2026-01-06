# Stellar Assault

An advanced NES game written in pure 6502 assembly, showcasing the full capabilities of the NES hardware and demonstrating that LLMs can write sophisticated, optimized assembly code.

## Features (Planned)

- **Vertical scrolling space shooter** with smooth multi-directional scrolling
- **Advanced sprite multiplexing** - Handle 64+ simultaneous enemies
- **Custom sound engine** - Multi-channel music and sound effects
- **Power-up system** - Weapon upgrades, shields, and special abilities
- **Optimized collision detection** - Pixel-perfect collision algorithms
- **Advanced graphics** - Parallax backgrounds, particle effects
- **Full test coverage** - Automated testing with emulator
- **CI/CD pipeline** - Automated builds and testing

## Technical Showcase

This project demonstrates:
- Optimal 6502 assembly patterns and best practices
- NES PPU programming (sprites, backgrounds, scrolling)
- NES APU sound programming
- Memory-efficient data structures
- Cycle-accurate timing
- Bank switching for large games
- CHR-ROM graphics management

## Building

```bash
# Build the ROM
make

# Run in emulator
make run

# Run tests
make test
```

## Development

See [CLAUDE.md](CLAUDE.md) for complete 6502 assembly specification and development guidelines.

## License

MIT
