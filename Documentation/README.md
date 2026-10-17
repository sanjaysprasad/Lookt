# Lookt

Face ID for your Mac. Lookt watches your camera when your MacBook is
locked, recognizes your face, and wakes your screen with the password
field ready to go — so unlocking feels closer to an iPhone than a
password prompt. It works **alongside** Touch ID and your password, not
instead of them — nothing about your existing login changes.

Runs entirely on your Mac. No internet connection, no cloud account, no
data ever leaves your machine.

## Requirements

- A Mac with Apple Silicon (M1 or later)
- macOS 13 or later
- A built-in or external camera

## What it does

- 🎥 Watches for your face only while the screen is locked — not
  constantly, not in the background otherwise
- 💡 Brightens your screen automatically during recognition, helping the
  camera see you in low light
- 👁️ Checks for liveness (blinking, natural movement) so a photo held up
  to the camera won't fool it
- 🔒 On a match, wakes the screen and focuses the password field — you
  finish with Touch ID or your password, same as always
- 📴 Works completely offline — enrollment and recognition both happen
  locally on your device

## What it doesn't do

- It does **not** type your password for you. A face match gets your Mac
  ready to unlock; you still complete it with Touch ID or your password.
  This is a deliberate choice — see [SECURITY.md](SECURITY.md) for why.
- It does **not** replace or disable Touch ID or your password — both
  keep working exactly as before.
- It does **not** send anything anywhere. There's no server, no account,
  no analytics.

## Installing

> This project doesn't have a signed release yet. For now, building from
> source is the way to run it — see [DEVELOPMENT.md](DEVELOPMENT.md) for
> setup steps in Xcode.

Once packaged releases are available, they'll be posted under
[Releases](../../releases) as a downloadable `.dmg`.

## Setting it up

1. Launch Lookt — you'll see a face icon appear in your menu bar
2. Click it → **Enroll / Re-enroll Face**
3. Follow the on-screen prompts (look straight ahead, turn slightly left,
   then right — a few quick captures each)
4. Grant camera access when macOS asks
5. That's it — lock your screen (Control+Command+Q) to try it out

You can re-run enrollment any time from the menu bar icon, useful if you
change your look (glasses, facial hair, etc.) and matching gets less
reliable.

## A note on how well this works

This is an independent, open source project, not an Apple product. The
face-matching technology behind it is a good-faith implementation, but
it's not held to the same testing and certification standards as Apple's
own Face ID or Touch ID. Please read [SECURITY.md](SECURITY.md) before
relying on it for anything sensitive — it's a genuinely useful convenience
feature, but it's not a guarantee against a determined attacker.

## Contributing / building it yourself

See [DEVELOPMENT.md](DEVELOPMENT.md) for the Xcode project setup and
architecture notes.

## License

MIT — see [LICENSE](LICENSE). Free to use, modify, and share.
