#!/usr/bin/env bash
#
SECONDS=0
ZIPNAME="Neophyte-Solstice-A10-KSU-Ginkgo-$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M").zip"
TC_DIR="$(pwd)/../tc/"
CLANG_DIR="${TC_DIR}clang"
GCC_64_DIR="${TC_DIR}aarch64-linux-android-4.9"
GCC_32_DIR="${TC_DIR}arm-linux-androideabi-4.9"
AK3_DIR="$HOME/AnyKernel3"
DEFCONFIG="vendor/ginkgo_defconfig"

export PATH="$CLANG_DIR/bin:$PATH"
export LD_LIBRARY_PATH="$CLANG_DIR/lib:$LD_LIBRARY_PATH"
export KBUILD_BUILD_VERSION="1"
export LOCALVERSION

# ==== TELEGRAM CONFIG ====
export TELEGRAM_BOT_TOKEN="8338188311:AAFgWEjptCCroGaaYd9oSLgGMNeu_D0pip0"
export TELEGRAM_CHAT_ID="-1002001516627"

TG_API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"
CHAT_ID="${TELEGRAM_CHAT_ID}"

sendTG() {
    curl -s -X POST "$TG_API/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="$1" \
        -d parse_mode="Markdown"
}

# ==== SEND LONG MESSAGE ====
sendLongTG() {
    local text="$1"
    local max=4000

    while [ ${#text} -gt $max ]; do
        part="${text:0:$max}"
        sendTG "$part"
        text="${text:$max}"
    done

    [ -n "$text" ] && sendTG "$text"
}

# ==== NOTIF START ====
sendTG "🚀 *Kernel Build Started!*%0ADevice: *Ginkgo*%0AKernel: *Neophyte Solstice A10*%0AZip: *$ZIPNAME*"

# ==== TOOLCHAIN CHECK ====
if ! [ -d "${CLANG_DIR}" ]; then
    echo "Clang not found! Cloning..."
    git clone --depth=1 https://gitlab.com/nekoprjkt/aosp-clang ${CLANG_DIR}
fi

if ! [ -d "${GCC_64_DIR}" ]; then
    echo "gcc not found! Cloning..."
    git clone --depth=1 -b lineage-19.1 \
        https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git \
        ${GCC_64_DIR}
fi

if ! [ -d "${GCC_32_DIR}" ]; then
    echo "gcc_32 not found! Cloning..."
    git clone --depth=1 -b lineage-19.1 \
        https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git \
        ${GCC_32_DIR}
fi

# ==== BUILD CONFIG ====
mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out \
    ARCH=arm64 \
    CC=clang \
    LD=ld.lld \
    AR=llvm-ar \
    AS=llvm-as \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip \
    CROSS_COMPILE=aarch64-linux-android- \
    CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
    CLANG_TRIPLE=aarch64-linux-gnu- \
    Image.gz-dtb \
    dtbo.img 2>&1 | tee log.txt

# ==== SUCCESS ====
if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then

    sendTG "✅ *Build Success!*%0AUploading zip file..."

    # AnyKernel3
    if [ -d "$AK3_DIR" ]; then
        cp -r $AK3_DIR AnyKernel3
    else
        git clone -q https://github.com/k4ngcaribug/AnyKernel3
    fi

    cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
    cp out/arch/arm64/boot/dtbo.img AnyKernel3

    rm -f *zip
    cd AnyKernel3
    git checkout main &> /dev/null
    zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
    cd ..

    rm -rf AnyKernel3
    rm -rf out/arch/arm64/boot

    sendFileTG "$ZIPNAME"

    DURATION="$((SECONDS / 60)) menit $((SECONDS % 60)) detik"
    sendTG "🎉 *Done!*%0ADone in *$DURATION*"

else
    sendTG "❌ *Build Failed!*%0AMengirim log.txt..."
    sendFileTG "log.txt"
fi

echo -e "======================================="
