# Heilman for iPhone

One app with two tabs: **Basecamp** and **Almanac**. The Family App is Basecamp's Family page, so it doesn't need a tab of its own. Each tab is the live claude.ai page shown full screen, so it shows the same data as claude.ai and Claude's routines keep updating it. You sign in to Claude once, inside the app.

## Put it on your iPhone

1. Open `Heilman.xcodeproj` in Xcode 16 or newer.
2. Click **Heilman** at the top of the file list, then the **Heilman** target, then **Signing & Capabilities**. Set **Team** to your developer account. If Xcode says the bundle identifier is taken, change `com.travisheilman.heilman` to anything unique, like `com.yourname.heilman`.
3. Plug in the iPhone, pick it in the device menu at the top of the window, and press **Run** (⌘R).
   The first time, the phone asks you to turn on **Settings → Privacy & Security → Developer Mode** and restart.
4. When the app opens, sign in to Claude (see [Signing in](#signing-in)). That one sign-in covers both tabs.

A build you install with Run keeps working for a year on a paid developer account. TestFlight is the better route once you're happy with it.

## Send it to TestFlight

This lets you install the app from the TestFlight app like any other app.

1. In [App Store Connect](https://appstoreconnect.apple.com) go to **Apps → + → New App**. Choose iOS, pick the bundle ID from step 2 above, and give it a name. App Store names have to be unique worldwide, so something like "Heilman Basecamp" works better than "Heilman". The name under the icon stays "Heilman" either way.
2. In Xcode, set the device menu to **Any iOS Device (arm64)**, then **Product → Archive**.
3. The Organizer window opens. Click **Distribute App → TestFlight Internal Only → Distribute**. Xcode raises the build number for you.
4. After Apple processes the build (usually 10 to 30 minutes), go to **TestFlight → Internal Testing** in App Store Connect, make a group, and add yourself.
5. Install the **TestFlight** app on the iPhone and tap **Install** next to Heilman.

TestFlight builds stop working after 90 days. Archive and upload again before then.

## Build from your phone (no Mac)

GitHub can build the app on its own Macs and upload it to TestFlight. The workflow is `.github/workflows/testflight.yml`. Setup is one time.

1. **Make an API key.** In [App Store Connect](https://appstoreconnect.apple.com) go to **Users and Access → Integrations → App Store Connect API → Team Keys** and tap **+**. (The first time, you accept the API terms with **Request Access**.) Name it "GitHub", set access to **Admin**, and generate it.
   - Note the **Issuer ID** at the top of the page and the key's **Key ID**.
   - Tap **Download**. Apple only lets you download it once. It lands in **Files → Downloads** as `AuthKey_….p8`.
2. **Copy the key's text.** In Files, press and hold the key file, **Rename** it to end in `.txt`, then open it, select all and copy. If iOS won't let you select the text, open it in Pages and copy from there.
3. **Find your Team ID.** It's on [developer.apple.com/account](https://developer.apple.com/account) under **Membership details**.
4. **Add four secrets on GitHub.** Open this repository, then **Settings → Secrets and variables → Actions → New repository secret** (if Settings is missing on your phone, turn on **Request Desktop Website** in Safari):
   | Name | Value |
   |---|---|
   | `ASC_ISSUER_ID` | the Issuer ID |
   | `ASC_KEY_ID` | the Key ID |
   | `ASC_KEY_P8` | the key text you copied |
   | `APPLE_TEAM_ID` | the Team ID |
5. **Run it.** Go to **Actions → TestFlight → Run workflow**. The first run registers the app's bundle ID with Apple and stops, asking you to create the app in App Store Connect (**Apps → + → New App**, pick that bundle ID). Then run it again. A build takes about 10 to 15 minutes.
6. **Install.** In App Store Connect, add yourself under **TestFlight → Internal Testing**, then install from the TestFlight app.

After that it builds by itself whenever the app's code changes on the default branch, and on the 1st of every other month so the TestFlight build never expires. You can also tap **Run workflow** any time.

Builds made this way don't include the offline Almanac copy (it's not in git), so the Almanac tab needs a connection.

## How it works

- The tab switcher is at the top, because Basecamp draws its own tab bar at the bottom.
- **↻** reloads the current tab. **⋯** has **Open on claude.ai**, **Paste sign-in link** and **Sign out of Claude**.
- Links to other sites (Strava, Walmart, Etsy) open in Safari or in their own app. A link from one tab's page to another switches tabs.
- claude.ai shows its own slim header above each page. The app leaves it alone.
- The Almanac works offline from a copy saved inside the app. Basecamp needs a connection, because its data lives in Claude.
- The app is for you. Basecamp keeps all its data owner-only, its Family page included, so Payton would see nothing in it.

## Signing in

Use **Continue with Google**. Google blocks sign-in inside most apps, so this app reports itself to websites as Safari, which lets Google's sign-in through.

If Google still refuses, use the email option. Tapping the emailed link opens Safari instead of the app, so in Mail press and hold the link, choose **Copy Link**, then in the app tap **⋯ → Paste sign-in link**.

## The offline Almanac

`Heilman/almanac.html` is the copy the Almanac tab shows when there's no connection. It's left out of git because it holds Strava GPS traces and family dates, and this repository is public. Without the file the app still builds (cloud builds never have it), and the Almanac tab just needs a connection.

To refresh it, ask Claude for the current Almanac page saved as `almanac.html`, drop it into the `Heilman` folder, and archive a new build.

## Changing the pages

The claude.ai links are in `Heilman/Destination.swift`.

## Troubleshooting

To see what a page is doing, turn on **Settings → Apps → Safari → Advanced → Web Inspector** on the phone, then open Safari on the Mac and choose **Develop → [your iPhone] → Heilman**.
