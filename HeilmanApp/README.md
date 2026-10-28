# Heilman for iPhone

One app with three tabs: **Basecamp**, **Family** and **Almanac**. Each tab is the live claude.ai page shown full screen, so it shows the same data as claude.ai, Payton's copy of the Family App stays in sync, and Claude's routines keep updating Basecamp. You sign in to Claude once, inside the app.

## Put it on your iPhone

1. Open `Heilman.xcodeproj` in Xcode 16 or newer.
2. Click **Heilman** at the top of the file list, then the **Heilman** target, then **Signing & Capabilities**. Set **Team** to your developer account. If Xcode says the bundle identifier is taken, change `com.travisheilman.heilman` to anything unique, like `com.yourname.heilman`.
3. Plug in the iPhone, pick it in the device menu at the top of the window, and press **Run** (⌘R).
   The first time, the phone asks you to turn on **Settings → Privacy & Security → Developer Mode** and restart.
4. When the app opens, sign in to Claude (see [Signing in](#signing-in)). That one sign-in covers all three tabs.

A build you install with Run keeps working for a year on a paid developer account. TestFlight is the better route once you're happy with it.

## Send it to TestFlight

This lets you install the app from the TestFlight app like any other app, and add Payton.

1. In [App Store Connect](https://appstoreconnect.apple.com) go to **Apps → + → New App**. Choose iOS, pick the bundle ID from step 2 above, and give it a name. App Store names have to be unique worldwide, so something like "Heilman Basecamp" works better than "Heilman". The name under the icon stays "Heilman" either way.
2. In Xcode, set the device menu to **Any iOS Device (arm64)**, then **Product → Archive**.
3. The Organizer window opens. Click **Distribute App → TestFlight Internal Only → Distribute**. Xcode raises the build number for you.
4. After Apple processes the build (usually 10 to 30 minutes), go to **TestFlight → Internal Testing** in App Store Connect, make a group, and add yourself. To add Payton, first invite her under **Users and Access**.
5. Install the **TestFlight** app on the iPhone and tap **Install** next to Heilman.

TestFlight builds stop working after 90 days. Archive and upload again before then.

## How it works

- The tab switcher is at the top, because Basecamp and the Family App draw their own tab bars at the bottom.
- **↻** reloads the current tab. **⋯** has **Open on claude.ai**, **Paste sign-in link** and **Sign out of Claude**.
- Links to other sites (Strava, Walmart, Etsy) open in Safari or in their own app. A link from one tab's page to another switches tabs.
- claude.ai shows its own slim header above each page. The app leaves it alone.
- The Almanac works offline from a copy saved inside the app. Basecamp and Family need a connection, because their data lives in Claude.
- If Payton installs it, Basecamp won't show her your money or job pages. They're owner-only.

## Signing in

Use **Continue with Google**. Google blocks sign-in inside most apps, so this app reports itself to websites as Safari, which lets Google's sign-in through.

If Google still refuses, use the email option. Tapping the emailed link opens Safari instead of the app, so in Mail press and hold the link, choose **Copy Link**, then in the app tap **⋯ → Paste sign-in link**.

## The offline Almanac

`Heilman/almanac.html` is the copy the Almanac tab shows when there's no connection. It's left out of git because it holds Strava GPS traces and family dates, and this repository is public. Without the file the app still builds, and the Almanac tab just needs a connection.

To refresh it, ask Claude for the current Almanac page saved as `almanac.html`, drop it into the `Heilman` folder, and archive a new build.

## Changing the pages

The three claude.ai links are in `Heilman/Destination.swift`.

## Troubleshooting

To see what a page is doing, turn on **Settings → Apps → Safari → Advanced → Web Inspector** on the phone, then open Safari on the Mac and choose **Develop → [your iPhone] → Heilman**.
