# Flutter -> Rust bindings
The reason we have these bindings is to leverage the Monolith library for downloading web pages.

To get the Flutter -> Rust bindings to work, you have to follow these instructions:
- http://cjycode.com/flutter_rust_bridge/template/setup_android.html
- http://cjycode.com/flutter_rust_bridge/template/setup_ios.html
- http://cjycode.com/flutter_rust_bridge/template/generate_install.html

I also followed other instructions already that you shouldn't need to do again, e.g.
- http://cjycode.com/flutter_rust_bridge/integrate/ios_linking.html
- http://cjycode.com/flutter_rust_bridge/integrate/ios_headers.html

Note this issue re ffigen: https://github.com/fzyzcjy/flutter_rust_bridge/issues/478.

Make sure to set appropriate value in `android/gradle.properties`:
```
ANDROID_NDK=/Users/dport/Library/Android/sdk/ndk-bundle
```

I followed the latter part of the android setup to get the latest NDK working, so do something like this:
```
for t in aarch64 arm i386 x86_64; do
    echo 'INPUT(-lunwind)' > ~/Library/Android/sdk/ndk/24.0.8215888/toolchains/llvm/prebuilt/darwin-x86_64/lib64/clang/14.0.1/lib/linux/$t/libgcc.a
done
```

To regenerate bindings, you might want to take this for a spin:
```
cargo build && cargo build --release && cd .. && just && cd native
```

If you decide to release this app for MacOS, you'll have to look into these steps again, I haven't done the MacOS stuff.