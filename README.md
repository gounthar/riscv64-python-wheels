# riscv64 Python Wheels

Prebuilt Python wheels for RISC-V 64-bit (riscv64) Linux, for packages that don't yet publish riscv64 wheels on PyPI.

Many Python packages with native extensions (Rust, C, C++) lack official riscv64 wheels on PyPI, forcing users to compile from source on every install. This repo provides prebuilt wheels to save time and simplify riscv64 Python development.

## Installation

### Direct from GitHub Release

```bash
pip install PACKAGE --find-links https://github.com/gounthar/riscv64-python-wheels/releases/download/RELEASE_TAG/
```

Replace `PACKAGE` with the package name and `RELEASE_TAG` with the release version.

### Via PEP 503 index (coming soon)

```bash
pip install PACKAGE --extra-index-url https://gounthar.github.io/riscv64-python-wheels/simple/
```

## Supported Packages

| Package | Version | Python | Source Language | Status |
|---------|---------|--------|----------------|--------|
| tokenizers | - | cp313 | Rust | Planned |
| pydantic-core | - | cp313 | Rust | Planned |
| safetensors | - | cp313 | Rust | Planned |
| tiktoken | - | cp313 | Rust | Planned |
| blake3 | - | cp313 | Rust + C | Planned |
| sentencepiece | - | cp313 | C++ | Planned |
| pillow | - | cp313 | C | Planned |

## Build Hardware

All wheels are built natively on:

- **BananaPi F3** (SpacemiT K1)
- 8x rv64imafdcv cores @ 1.6 GHz
- RVV 1.0 with vlen=256
- 16 GB RAM
- Debian Linux

## Scripts

- `scripts/extract-wheels.sh` - Extract riscv64 wheels from pip cache
- `scripts/build-from-source.sh` - Build a package wheel from source
- `scripts/generate-index.py` - Generate PEP 503 compliant index
- `scripts/check-upstream.sh` - Check for new upstream versions on PyPI

## Contributing

Contributions are welcome! If you have access to riscv64 hardware and want to help build wheels:

1. Fork this repo
2. Build a wheel using `scripts/build-from-source.sh PACKAGE`
3. Open a PR with the wheel file and updated `packages.json`

## License

Apache-2.0. See [LICENSE](LICENSE) for details.
