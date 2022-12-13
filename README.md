# aclip: Aptos "Read Later" App

Download the app for [iOS](https://apps.apple.com/us/app/aclip/id1627071553?uo=2), [Android](https://play.google.com/store/apps/details?id=com.banool.aclip&hl=en_GB&gl=US), and [Chrome](https://chrome.google.com/webstore/detail/aclip/kfpgpafcofdgikmemhkgfoaanmomhooc).

This project is made up of two major components:
- `frontend`: This is the frontend for the project, made with Flutter. todo
- `move`: This is where the core logic lives, on the [Aptos Blockchain](https://aptoslabs.com). todo

In addition to the core feature components, deployment is handled in `.github`.

Each of these components has their own README explaining how to develop and deploy them.

## Learning
First, the premise of the app. If you've ever used the "Reading List" functionality in your browser or an app like Pocket, you'll understand aclip. It works similarly to those with the key diference being that instead of using a centralized database as its backend, it uses the Aptos blockchain. This has some nice properties:
- No risk of the centralized provider shutting down.
- You can view other people's reading lists, though items can also be encrypted if you don't want your list to be public.
- You're not paying for the app with your personal data like you do with some [other providers](https://getpocket.com/en/privacy/#sharing).

I made this project with the intent of demonstrating a full end-to-end dapp built on Aptos. As such, there is a lot of code here that isn't diretly relevant to the Aptos part of the app, but to other functionality. For example, all the code in [frontend/native/](frontend/native/) has nothing to do with Aptos, instead focusing on downloading articles for offline reading. I will ignore those components as part of this mini writeup, instead focusing on the parts relevant to dapp development.

My aim with this write up is to focus specifically on the frontend <--> Move boundary, since that's where we are somewhat lacking on documentation right now. I don't intend for this write up to cover a full dev journey from start to finish; instead I'll point out interesting quirks / tips. Though note, I'm also learning, so my recommendations may actually be antipatterns, warranty not included!

### Move
On the first line of [move/sources/aclip.move](move/sources/aclip.move) you'll notice a comment pointing to [frontend/lib/constants.dart](frontend/lib/constants.dart). This is where the address, module name, and struct names are kept in the frontend. This is something you'll probably want to plan for from the beginning. Beyond just having these as constants, you'll likely want to make this configurable ([frontend/lib/settings_page.dart](frontend/lib/settings_page.dart)). In the frontend, I've made all of these values configurable:
- Module address.
- Module name.
- Struct names in the module.

Doing this is handy if you want to play with the names while developing. Often while developing you'll find it necessary to add `vx` to the module name, e.g. `aclipv1`, so having this configurable in the frontend is handy. An alternative is to use the `upgradable` [upgrade policy](https://aptos.dev/guides/move-guides/upgrading-move-code/#upgrade-policies), though early in development you'll likely make incompatible changes.

Looking at the code, immediately you'll notice this pattern where the top level struct looks like this:
```
struct Root has key {
    inner: Inner,
}
```

On mainnet this might be an antipattern because you borrow more than necessary, but on testnet, this is nice because it means you only have to borrow once to access everything you need:
```
let inner = &mut borrow_global_mut<Root>(addr).inner;
```

The `Root` wrapper struct is necessary because this isn't allowed:
```
let root = &mut borrow_global_mut<Root>(addr);
```

Moving on, in many Move modules, you'll find yourself reaching for a map-like data structure. What you do next turns out to be one of the most important choices you can make, but we don't actually have much documentation on the decision. When selecting a map type, you have many options. Below I'll list some of them and some pros and cons:

`aptos_std::table`:

Pros:

- Supports millions of items efficiently.

Cons:

- In a Move module, you cannot iterate through the table in any way, both for keys and values.
- You cannot read values without knowing the table key in advance.
- The only thing you can do via the node API is read a value if you know the key. See [this post](https://stackoverflow.com/questions/74604965/how-do-i-get-all-the-keys-in-a-table) and [this post](https://stackoverflow.com/questions/74296605/given-a-key-how-do-i-read-the-value-from-a-table-via-the-api) on Stack Overflow for more info on the limitations of tables.

`aptos_std::table_with_length`:

Same as `table`, but it has length. If you need to know how many items are in the table in your Move module, use this.

`aptos_std::simple_map`:

Pros:

- You can read the items in the map via the API. You can see how I do this in `fetchData` in [frontend/lib/list_manager.dart](frontend/lib/list_manager.dart).

Cons:

- Data is sorted by key, not insertion. This may / may not be what you want.
- Operations get expensive as the size of the map grows, so you shouldn't store many items in this.

`move-examples/data_structures/sources/iterable_table.move`:

Pros:

- It is like `table` but you can iterate through items one by one in Move.
- You can read items one by one off chain, by using the pointer to the next item.

Cons:

- Otherwise all the same cons as table, in general you still can't easily read data via the API.
- It is not deployed on mainnet, and only deployed on testnet at custom addresses.

If you have access to an indexer and the expertise to configure it to index your table, consider using a table. You'll see here that I chose to use simple map, but this app only runs on testnet, so gas costs aren't a concern.

Looking at the Move tests, it should serve as a handy example for setting up test accounts and initializing the clock.

### Frontend
When making a frontend you need to make some choices early on about how you're going to deal with updating and fetching data from the blockchain. Here are some good questions to ask yourself.

Do you expect the data backing the app to change outside of the user's session? For example, will other users / on chain activity change the data your frontend relies on. Will the user have multiple sessions active at once? If not, you may not need a streaming / subscription model, you might be able to just update the app state in response to user actions. If yes, you will likely want to have a component that is responsible for periodicially querying the on-chain state via the API / an indexer, updating the frontend representation of the data, and then notifying downstream UI components of these changes. Provider is a good pattern for this. Note that this intermediary component where you convert polling into a notifier / listener model is extra necessary becuase we don't have good support for streaming blockchain data directly right now.

Do you expect users to be able to use the app offline? If yes, you will need to have some kind of local storage where user actions and stored, and when the app comes online, it will "flush" those actions (write to the blockchain). What if that stuff fails, where will you show the users the errors?

How will you handle blockchain writes? Will you just block the app while that's happening, or will you do it in the background and show the user a message later based on what happened? How will you reconcile app state in the case of failure?

I don't handle all of these cases (such as the offline update flushing case) in this app, but I do handle some of them. The place to look for this is [frontend/lib/list_manager.dart](frontend/lib/list_manager.dart).

This app has some maybe helpful examples of state management given backend changes, though note that I'm not a Frontend Engineer TM. If you are, this probably looks pretty crusty. See these files:
- [frontend/lib/list_page_selector.dart](frontend/lib/list_page_selector.dart)
- [frontend/lib/add_item_screen.dart](frontend/lib/add_item_screen.dart)
- [frontend/lib/list_page.dart](frontend/lib/list_page.dart)

One other sort of novel thing I do in this app is store "secret" data on chain. You can see how I do this in [frontend/lib/list_manager.dart](frontend/lib/list_manager.dart). This has _not_ been vetted by a cryptography expert, so tread carefully!

### Account management
If you're building a cross platform / mobile app like I am, you need to think about how you're going to manage user accounts since there is no wallet to call out to. You can see how I manage this in [frontend/lib/register_page.dart](frontend/lib/register_page.dart). This is of course pretty risky business, so consider just starting with web so you can call out to a wallet like Petra.

You'll also need to consider the "sign up" flow. For example, in this app you need to initialize a list to your account. The page for that is here: [frontend/lib/register_page.dart](frontend/lib/register_page.dart).

## Setting up this repo
When first pulling this repo, add this to `.git/hooks/pre-commit` and make it executable:
```
#!/bin/bash

cd frontend
./bump_version.sh
git add pubspec.yaml
git add web/manifest_extension.json
```

Also run this:
```
cd frontend/android
ln -s ../../secrets/key.properties
ln -s ../../secrets/upload_keystore.jks
```
