# aclip frontend 

## Flutter -> Rust bindings
See `native/README.md`.

## Notes on building for web / extension
While initially I considered having two separate flutter projects and a shared package, one for the app / web and one for the extension, I realised that I like the potential to have the full app functionality right there in the extension. Once I'd made that choice, the differences between the two became pretty light.

When developing locally, if you want to build the web or extension, run this command:
```
./switch_web.sh
```
This will toggle between web and extension build modes. You can also invoke it to specifically target one or the other:
```
./switch_web.sh web
./switch_web.sh extension
```

If building for extension, make sure to build it like this:
```
flutter build web --dart-define=IS_BROWSER_EXTENSION=true --web-renderer html --csp
```

This is all handled in CI properly.

## Deploying to Android
This is done automatically via Github Actions.

## Deploying to iOS
Currently this must be done manually:
```
flutter pub get
flutter build ios --release --no-codesign
cd ios && ./publish.sh
```

If you run into problems with this, run some combination of these commands:
```
brew reinstall fastlane
rm Gemfile.lock
sudo gem cleanup
sudo gem update
pod install
```
Make sure you're using an up to date ruby / gem and it is configured first in your PATH. Make sure `pod` is coming from that gem install too. [See here](https://stackoverflow.com/questions/20755044/how-do-i-install-cocoapods). Make sure to use the one with `-n`.

## Screenshots
First, make sure you've implemented the fix in https://github.com/flutter/flutter/issues/91668 if the issue is still active. In short, make the following change to `IntegrationTestPlugin.m`
```
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    [[IntegrationTestPlugin instance] setupChannels:registrar.messenger];
}
```

You might find the file at locations like these:
```
~/homebrew/Caskroom/flutter/2.10.3/flutter/packages/integration_test/ios/Classes/
~/.flutter/packages/integration_test/ios/Classes/
```

You may also need to `flutter clean && flutter pub get` after this.

Then run this:
```
python3 screenshots/take_screenshots.py
```

This takes screenshots for both platforms on multiple devices. You can then upload them with these commands:
```
ios/upload_screenshots.sh
```
The Apple App Store will expect that you also upload a build for this app version first. You might need to also manually upload the photos for the 2nd gen 12.9 inch iPad (just use the 5th gen pics).

For Android, you need to just go to the Google Play Console and do it manually right now.

See my [Stack Overflow question](https://stackoverflow.com/questions/71699078/how-to-locate-elements-in-ios-ui-test-for-flutter-fastlane-screnshots/71801310#71801310) for more information about this whole setup.

## Icons
To generate icons, do this:
```
flutter pub run icons_launcher:create
```
