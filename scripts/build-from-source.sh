#!/bin/bash
set -euo pipefail

# Build a Python wheel from source for riscv64

PACKAGE="${1:-}"
SRC_BASE="${HOME}/wheels-src"
WHEEL_DIR="${HOME}/wheels"

if [ -z "$PACKAGE" ]; then
    echo "Usage: $0 PACKAGE_NAME"
    echo ""
    echo "Supported packages:"
    echo "  tokenizers, pydantic-core, safetensors, tiktoken,"
    echo "  blake3, sentencepiece, pillow, cffi, cryptography,"
    echo "  watchfiles, zstandard, pyyaml, tree-sitter,"
    echo "  tree-sitter-bash, textual-speedups, numpy, grpcio,"
    echo "  orjson, multidict, frozenlist, propcache"
    exit 1
fi

# Map package names to subdirectories within their source repos
declare -A SUBDIR_MAP=(
    ["tokenizers"]="bindings/python"
    ["safetensors"]="bindings/python"
    ["pydantic-core"]="."
    ["tiktoken"]="."
    ["blake3"]="."
    ["sentencepiece"]="."
    ["pillow"]="."
    ["cffi"]="."
    ["cryptography"]="."
    ["watchfiles"]="."
    ["zstandard"]="."
    ["pyyaml"]="."
    ["tree-sitter"]="."
    ["tree-sitter-bash"]="."
    ["textual-speedups"]="."
    ["numpy"]="."
    ["grpcio"]="src/python/grpcio"
    ["orjson"]="."
    ["multidict"]="."
    ["frozenlist"]="."
    ["propcache"]="."
)

# Map packages to their build system
declare -A BUILD_SYSTEM=(
    ["tokenizers"]="maturin"
    ["safetensors"]="maturin"
    ["pydantic-core"]="maturin"
    ["tiktoken"]="maturin"
    ["blake3"]="maturin"
    ["sentencepiece"]="setuptools"
    ["pillow"]="setuptools"
    ["cffi"]="setuptools"
    ["cryptography"]="maturin"
    ["watchfiles"]="maturin"
    ["zstandard"]="setuptools"
    ["pyyaml"]="setuptools"
    ["tree-sitter"]="setuptools"
    ["tree-sitter-bash"]="setuptools"
    ["textual-speedups"]="maturin"
    ["numpy"]="meson"
    ["grpcio"]="setuptools"
    ["orjson"]="maturin"
    ["multidict"]="setuptools"
    ["frozenlist"]="setuptools"
    ["propcache"]="setuptools"
)

# Map package names to fork repository names (when they differ)
declare -A REPO_MAP=(
    ["tokenizers"]="tokenizers"
    ["pydantic-core"]="pydantic-core"
    ["safetensors"]="safetensors"
    ["tiktoken"]="tiktoken"
    ["blake3"]="BLAKE3"
    ["sentencepiece"]="sentencepiece"
    ["pillow"]="Pillow"
    ["cffi"]="cffi"
    ["cryptography"]="cryptography"
    ["watchfiles"]="watchfiles"
    ["zstandard"]="python-zstandard"
    ["pyyaml"]="pyyaml"
    ["tree-sitter"]="py-tree-sitter"
    ["tree-sitter-bash"]="tree-sitter-bash"
    ["textual-speedups"]="textual"
    ["numpy"]="numpy"
    ["grpcio"]="grpc"
    ["orjson"]="orjson"
    ["multidict"]="multidict"
    ["frozenlist"]="frozenlist"
    ["propcache"]="propcache"
)

SUBDIR="${SUBDIR_MAP[$PACKAGE]:-"."}"
BUILDER="${BUILD_SYSTEM[$PACKAGE]:-"setuptools"}"
REPO_NAME="${REPO_MAP[$PACKAGE]:-"$PACKAGE"}"
SRC_DIR="${SRC_BASE}/${PACKAGE}"

if [ ! -d "$SRC_DIR" ]; then
    echo "Source directory not found: $SRC_DIR — cloning..."
    mkdir -p "$SRC_BASE"
    git clone "https://github.com/gounthar/${REPO_NAME}.git" "$SRC_DIR"
fi

BUILD_DIR="${SRC_DIR}/${SUBDIR}"
if [ ! -d "$BUILD_DIR" ]; then
    echo "Error: Build directory not found: $BUILD_DIR"
    exit 1
fi

mkdir -p "$WHEEL_DIR"

echo "Building $PACKAGE from $BUILD_DIR"
echo "Build system: $BUILDER"
echo "Fork repo: gounthar/$REPO_NAME"
echo "Output directory: $WHEEL_DIR"
echo ""

# Create a temporary venv for building
VENV_DIR=$(mktemp -d)
python3 -m venv "$VENV_DIR"
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

# Install build dependencies
case "$BUILDER" in
    maturin)
        pip install --quiet maturin
        ;;
    meson)
        pip install --quiet meson-python meson ninja cython setuptools wheel build
        ;;
    *)
        pip install --quiet setuptools wheel build
        ;;
esac

# Build the wheel
cd "$BUILD_DIR"
pip wheel --no-deps --wheel-dir "$WHEEL_DIR" .

# Clean up venv
deactivate
rm -rf "$VENV_DIR"

# Verify platform tag
echo ""
echo "Built wheels:"
FOUND=0
for whl in "$WHEEL_DIR"/*.whl; do
    if [[ "$(basename "$whl")" == *"linux_riscv64"* ]]; then
        echo "  OK: $(basename "$whl")"
        FOUND=1
    fi
done

if [ "$FOUND" -eq 0 ]; then
    echo "WARNING: No wheels with linux_riscv64 platform tag found."
    echo "The build may have produced a pure Python wheel or wrong platform."
    ls -la "$WHEEL_DIR"/*.whl 2>/dev/null || true
fi
