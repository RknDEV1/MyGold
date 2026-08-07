#!/usr/bin/env bash

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOCAL_BUILD_DIR="/tmp/mygold_build_$$"
THEOS_CACHE=~/.theos_cache
OUTPUT_DIR="$SCRIPT_DIR/build"

cleanup() {
    rm -rf "$LOCAL_BUILD_DIR" 2>/dev/null || true
}
trap cleanup EXIT

echo -e "${CYAN}======================================================${NC}"
echo -e "${CYAN}     Getting Started with MyGoldAPI Quick Build       ${NC}"
echo -e "${CYAN}======================================================${NC}"

if [ ! -d "$THEOS_CACHE" ] || [ ! -d "$THEOS_CACHE/sdks" ]; then
    echo -e "${YELLOW}[1/4] Baixando Theos e SDKs do iOS (Apenas na 1ª execução)...${NC}"
    mkdir -p "$THEOS_CACHE"
    git clone --recursive https://github.com/theos/theos.git "$THEOS_CACHE"
    
    curl -sSL https://github.com/theos/sdks/archive/master.zip -o "$THEOS_CACHE/sdks.zip"
    unzip -q -X "$THEOS_CACHE/sdks.zip" -d "$THEOS_CACHE/"
    mv "$THEOS_CACHE/sdks-master"/* "$THEOS_CACHE/sdks/" 2>/dev/null || true
    rm -rf "$THEOS_CACHE/sdks-master" "$THEOS_CACHE/sdks.zip"
fi

mkdir -p "$THEOS_CACHE/toolchain/linux/iphone/bin"
ln -sf /usr/bin/clang "$THEOS_CACHE/toolchain/linux/iphone/bin/clang"
ln -sf /usr/bin/clang++ "$THEOS_CACHE/toolchain/linux/iphone/bin/clang++"
ln -sf /usr/bin/lld "$THEOS_CACHE/toolchain/linux/iphone/bin/ld"
ln -sf /usr/bin/lld "$THEOS_CACHE/toolchain/linux/iphone/bin/ld64"
ln -sf /usr/bin/ld.lld "$THEOS_CACHE/toolchain/linux/iphone/bin/ld.lld"
ln -sf /usr/bin/true "$THEOS_CACHE/toolchain/linux/iphone/bin/strip"

if [ ! -f "$THEOS_CACHE/toolchain/linux/iphone/bin/ldid" ] || [ $(wc -c < "$THEOS_CACHE/toolchain/linux/iphone/bin/ldid") -lt 1000 ]; then
    curl -sSL https://github.com/ProcursusTeam/ldid/releases/download/v2.1.5-procursus7/ldid_linux_x86_64 -o "$THEOS_CACHE/toolchain/linux/iphone/bin/ldid"
    chmod +x "$THEOS_CACHE/toolchain/linux/iphone/bin/ldid"
fi

export THEOS="$THEOS_CACHE"

echo -e "${YELLOW}[2/4] Sincronizando código fonte para /tmp...${NC}"
rm -rf "$LOCAL_BUILD_DIR"
mkdir -p "$LOCAL_BUILD_DIR"
cp -r "$SCRIPT_DIR"/*.h "$SCRIPT_DIR"/*.mm "$SCRIPT_DIR"/Makefile "$SCRIPT_DIR"/control "$SCRIPT_DIR"/*.plist "$LOCAL_BUILD_DIR"/ 2>/dev/null || true

echo -e "${YELLOW}[3/4] Compilando MyGoldAPI.dylib e pacote .deb...${NC}"
cd "$LOCAL_BUILD_DIR"
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless STRIP=true

echo -e "${YELLOW}[4/4] Salvando arquivos gerados em build/...${NC}"
mkdir -p "$OUTPUT_DIR"

if [ -f "$LOCAL_BUILD_DIR/.theos/obj/MyGoldAPI.dylib" ]; then
    cp "$LOCAL_BUILD_DIR/.theos/obj/MyGoldAPI.dylib" "$OUTPUT_DIR/MyGoldAPI.dylib"
elif [ -f "$LOCAL_BUILD_DIR/.theos/obj/debug/MyGoldAPI.dylib" ]; then
    cp "$LOCAL_BUILD_DIR/.theos/obj/debug/MyGoldAPI.dylib" "$OUTPUT_DIR/MyGoldAPI.dylib"
fi

cp "$LOCAL_BUILD_DIR/packages"/*.deb "$OUTPUT_DIR/" 2>/dev/null || true

echo -e "${GREEN}======================================================${NC}"
echo -e "${GREEN}  Compilation completed SUCCESSFULLY!                 ${NC}"
echo -e "${GREEN}======================================================${NC}"
echo -e "Files saved in the ‘build’ folder/:"
ls -lh "$OUTPUT_DIR"/MyGoldAPI.dylib "$OUTPUT_DIR"/*.deb 2>/dev/null || true
