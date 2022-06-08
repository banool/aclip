#!/bin/bash

if [[ -z "$ANDROID_NDK_HOME" ]]; then
    echo "ERROR: You must set ANDROID_NDK_HOME"
fi

platform=`ls -1 $ANDROID_NDK_HOME/toolchains/llvm/prebuilt | head -n1`
clangversion=`ls -1 $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$platform/lib64/clang | head -n1`

for t in aarch64 arm i386 x86_64; do
    echo 'INPUT(-lunwind)' > $ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$platform/lib64/clang/$clangversion/lib/linux/$t/libgcc.a
done
