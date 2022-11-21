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

Make sure to build android like this:
```
ANDROID_NDK_HOME='/Users/dport/Library/Android/sdk/ndk/25.1.8937393/' flutter build appbundle
```

To get the NDK working, run `./fix_ndk_gcc.sh`.

To regenerate bindings, you might want to take this for a spin:
```
just && cargo build && cargo build --release && cd .. && just && cd native
```

If you decide to release this app for MacOS, you'll have to look into these steps again, I haven't done the MacOS stuff.
