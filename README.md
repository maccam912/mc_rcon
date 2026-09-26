# MC RCON

A Flutter Minecraft Java Edition RCON utility for Android and desktop. Save server connections, manage players, browse inventories, and run console commands.

## Workspace

The interface adapts to the window: bottom navigation on phones, and a sidebar in wider desktop windows. Players, Quick actions, and Console retain their state as you switch between them or resize the window. Use **⌘1–3** (or **Ctrl+1–3**) to switch sections on desktop.

Search players and assistant bots by name. Open a player for inventory, play breaks, teleportation, and moderation. The Console keeps its input above the keyboard, offers recent commands from the history icon, and supports **↑ / ↓** history navigation and **Enter** to send. Copy or clear the visible transcript from its toolbar.

Each online player's card has **Teleport to** shortcuts for the other online players. Tap a name to move that card's player directly to them; destinations stay available even when you filter the list with search. Heal, Feed, and Invincible are available inside the player's detail screen.

## Connection and feedback

The app refreshes the player list every 10 seconds to keep the connection active, reconnects after a drop, and checks the connection when returning from the background. A banner shows connection or timer errors. Actions wait for the server's reply and display it; known command errors are shown as failures. Commands whose result is uncertain after a disconnect are **not replayed**, to avoid giving items or performing other actions twice.

RCON must be enabled on the Minecraft server. Use the server's RCON port and password on the connection screen.

## Inventory

Open a player → **Manage Inventory** → **Give Items**. Search by item name or ID, browse categories, or enter a custom/modded namespaced ID. Select an item, quantity, and optional destination slot before sending. Choosing a destination replaces its contents; “Give” lets Minecraft place the item normally. The bundled suggestions match Minecraft 26.2; custom IDs work with other versions and mods.

## Assistant bots

Bots named `[Bot]Owner` from `~/dev/assistant-bot` appear in their own group. **Dismiss bot** sends `assistant Owner dismiss` and verifies the bot has disappeared. The bot's owner must be online, as required by the existing mod command. No mod update is required. Bots are excluded from playtime policies.

## Timed kicks and play breaks

- **Kick** has an optional reconnect lockout in minutes, including a 5-minute preset. Zero means an ordinary kick.
- **Play breaks** applies to one player. For example, configure 60 minutes of play followed by a 2-minute break.
- The app counts time between successful observations of an online player. Short reconnects do not reset accumulated time. It cannot count play before it connected or while it was closed, suspended, or disconnected. Enforcement can lag by one polling interval.
- A break uses Minecraft's `ban` command to block reconnecting, then `pardon` at expiry. Only bans created and still identified as owned by this app are automatically removed; existing or subsequently replaced bans are left alone.
- Policies, accumulated time, and pending releases are saved locally per server host/port. Reconnect to the same host and port after restarting the app to resume them. They are not shared between your phone and desktop, so use one device to administer timers for a server.
- **Keep the app running and connected. On mobile, keep it in the foreground.** If the app closes, the device sleeps, or the connection fails, temporary bans remain until the app reconnects and can release them. An administrator can always use `pardon PlayerName` from the server console.
- Offline players with saved policies or lockouts remain accessible in the player list. **End break now** releases an app-owned temporary ban early. Disabling a policy stops future breaks but preserves the current break.

Timers are implemented entirely in this utility, with no server-side timer mod.

## Development and builds

```sh
flutter pub get
flutter analyze
flutter test
flutter build apk --release
FLUTTER_XCODE_ARCHS=arm64 flutter build macos --release
```

Build outputs:

- Android: `build/app/outputs/flutter-apk/app-release.apk`
- macOS (Apple silicon, macOS 12+): `build/macos/Build/Products/Release/mc_rcon.app`

The Android project currently uses its existing debug signing key for local release APKs. Use your own release signing configuration for distribution through a store. Windows/Linux/iOS Flutter projects are included, but must be built with the corresponding platform toolchain.

The Apple silicon build override avoids the [Flutter/Xcode 27 universal-framework verification issue](https://github.com/flutter/flutter/issues/188346) in the installed toolchain. With a compatible toolchain, omit the override to build a universal macOS app.
