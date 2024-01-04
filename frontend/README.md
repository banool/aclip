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

When building the extension as part of the dev cycle, build it like this:
```
flutter build web --dart-define=IS_BROWSER_EXTENSION=true --web-renderer html --csp --profile --dart-define=Dart2jsOptimization=O0
```
The flags `--profile --dart-define=Dart2jsOptimization=O0` ensure you can see proper debug messages.

Once built, go to `chrome://extensions` and "load unpacked" the `build/web` directory.

To deploy the extension, for now do that manually:
```
./switch_web.sh extension
flutter build web --dart-define=IS_BROWSER_EXTENSION=true --web-renderer html --csp
cd build/web
rm -f index_normal.html manifest_normal.html
zip -r ~/Downloads/extension.zip .
```

Then upload that to https://chrome.google.com/webstore/devconsole.

Firefox is not supported right now as this extension stands today because it doesn't support manifest v3: https://blog.mozilla.org/addons/2022/05/18/manifest-v3-in-firefox-recap-next-steps/.

## Deploying to Web
The website is configured to deploy to GitHub pages. For perpetuity, here is how I did this:
1. I added the `build_web` and `deploy_web` GitHub Actions jobs in `full_ci.yml`.
2. I went to the [GitHub Pages UI for the aclip repo](https://github.com/banool/aclip/settings/pages) (*not* the UI for banool.github.io) and set the custom domain to `aclip.app`.
3. I followed the steps [here](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site#configuring-an-apex-domain) (the apex domain option) that explain how to point your DNS name at GitHub's GitHub Pages servers. I used the A name option.
4. I made a CNAME record for the www subdomain, which GH Pages treats specially.

In the end I had these DNS records set up:
- A: @ 185.199.108.153
- A: @ 185.199.109.153
- A: @ 185.199.110.153
- A: @ 185.199.111.153
- CNAME: www banool.github.io (it automatically put a dot at the end)

This approach doesn't result in the build files appearing in the repos for banool.github.io or aclip, they just get put somewhere that GitHub hosts. I did not need to do anything to the GH Pages configuration of banool.github.io. If you did the DNS stuff properly, it should tell you so at the GitHub Pages UI.

## Deploying Chrome extension
See above.

## Deploying to Android
This is done automatically via Github Actions.

## Deploying to iOS
Currently this must be done manually:
```
flutter pub get
flutter pub run flutter_launcher_icons:main
flutter pub run flutter_native_splash:create
flutter build ios --release --no-codesign
./ios/publish.sh
```

If you run into problems with this, run some combination of these commands:
```
rm Gemfile.lock
sudo gem cleanup
sudo gem update
bundle install
pod install
```

If you have issues with the cert stuff, try this:
```
. publish.env && yes | fastlane match nuke distribution && yes | fastlane match nuke development
```

Then open Xcode and disable and enable "automatically manage signing".

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
