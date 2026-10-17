# Security Policy

Lookt is a biometric authentication tool. Bugs here have different
stakes than a typical utility app — a flaw in matching or liveness could
mean unauthorized access to someone's Mac.

## Please read before relying on this for anything sensitive

- **The default face embedding is a placeholder** (landmark geometry, not a
  trained recognition model). It is easier to fool than production-grade
  face recognition. Do not treat it as equivalent to Apple's Face ID/Touch
  ID security guarantees unless you've swapped in a proper CoreML
  recognition model and tested it thoroughly yourself.
- **Liveness detection (blink + micro-motion) is a deterrent, not a
  guarantee.** It's designed to stop a static photo, not necessarily a
  sophisticated replay attack (e.g. a video of the enrolled user blinking
  naturally). Test against your own attack attempts before trusting it.
- **No auto-password-fill is implemented by design.** Successful face match
  wakes the screen and focuses the password field — it does not type your
  password for you. If you extend this to auto-fill, understand you're
  taking on full responsibility for that credential's exposure if the
  matching pipeline is ever fooled.
- **Brightness control uses a private Apple framework.** It may stop
  working after a macOS update with no warning.

## Reporting a vulnerability

If you find a way to bypass authentication (spoof a match, defeat
liveness, extract stored embeddings, etc.), please report it privately
rather than opening a public issue:

- Open a [GitHub Security Advisory](../../security/advisories/new) on this
  repo, or
- Email the maintainer directly (add your contact here before publishing)

Please include: macOS version, hardware (M-series/Intel), steps to
reproduce, and whether you tested against the default placeholder embedder
or a custom CoreML model.

We'll aim to acknowledge reports within a few days. Please give us
reasonable time to ship a fix before public disclosure.

## Not in scope

- General bugs / crashes / UI issues — just open a normal GitHub issue for
  those, no need for private disclosure.
