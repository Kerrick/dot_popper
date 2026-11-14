---
status: accepted
date: 2026-11-10
deciders: coding agents, without the maintainer; Lota's maintainers were consulted on the computer stores
---

# Native features Lota lacks are reached outside the Ruby process

## Context and Problem Statement

Lota binds only what LÖVE has. LÖVE has no share sheet and no store: it can't call iOS's `UIActivityViewController`, Android's `ACTION_SEND`, StoreKit, Play Billing or Windows.Services.Store. It can open a URL (`Lota::System.open_url`, SDL's `SDL_OpenURL`), which answers only yes or no. A gem can't add native code to the phones' hosts, and Dot Popper already owns a few host files over Lota's. How does the game reach these native features?

## Decision Drivers

* No other app may be able to send the game a request, and the game must keep its focus.
* All native code lives where Dot Popper already owns code: its host files on phones.
* An answer may come long after the request (a purchase sheet), and a missed one must cost nothing.
* On computers, a store's API must run where it is supported: StoreKit 2 is Swift-only and asynchronous; the build machines and CI have MinGW and no C++/WinRT.

## Considered Options

1. The game opens a URL in a scheme of its own (`dotpopper-share:`, `dotpopper-store:`); each phone host catches it before it leaves the app (`DotPopperApplication` in `ios/host/Host/main.m`, `MainActivity#startActivity` in `android/host`) and answers, where an answer is needed, by rewriting a file the URL names, as the whole state each time. On computers, a store build ships a small native program, a store helper (`macos/store/main.swift`, `windows/store/dot_popper_store.c`), started once per request with the same URL, writing the same answers to its standard output.
2. Register the URL scheme with the system, and an activity for it, so the system routes the URL back to the app.
3. Load the store's library into the Ruby process through Fiddle.

## Decision Outcome

Chosen: option 1. Against option 2, catching the URL in the host means no other app can send it, there is no round trip through the system and no disambiguation dialog, and the game keeps its focus; the scheme is registered nowhere. Against option 3, Lota's maintainers confirmed there is no supported in-process route: loading a Swift library through Fiddle would depend on `disable-library-validation` and on Fledge shipping Fiddle. Confidence: medium. The share sheet and the phones' store code compile in CI, and the URL and answer handling pass the store contract; no real purchase has run through any of them, and the computer helpers have run against no real store.

### Consequences

* Good, because one mechanism (a URL out, a whole-state answer back) serves every native feature and every store, so the game's side is the same Ruby on every system ([ADR-0009](0009-the-store-is-a-port.md)).
* Good, because if a host won't take the URL, `open_url` answers false and the game falls back (the share preview opens in the game).
* Bad, because the answer is polled from a file (the store's, four times a second, never during a game) rather than delivered.
* Bad, because the native code is in Objective-C, Swift, Java and C beside the Ruby, each with its own build, and the Windows helper calls WinRT by hand-worked vtable slots and interface IDs.
* Bad, because the Mac helper must be accepted by StoreKit as the app (it sits in `Contents/Helpers` with an Info.plist naming `com.setdef.DotPopper`), which is unverified.

### Confirmation

The store contract (`test/store_contract.rb`) runs against the hosts' answer files through `NativeStore` and against real helper processes through `Shell::StoreHelper` (`test/shell/store_helper_test.rb`). `ios/store_check` drives `Store.swift` against StoreKit's local test store; `test/windows_store_helper_test.rb` runs the Windows helper's self-test on Windows.

## More Information

The hosts are described in [platforms](../design/platforms.md), the share sheet in [screens](../design/screens.md), and the store's answers and helpers in [store and Pro](../design/store-and-pro.md).
