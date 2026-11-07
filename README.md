# pantry-overlay

The recipes we own, consumed by
[`go-zpkg/bottle`](https://github.com/go-zpkg/bottle) via
`ZPKG_PANTRY_OVERLAY`. A recipe here wins over any same-named recipe in the
pantry the factory is reading; what is absent here still falls back to that
pantry, which is why this is called an overlay.

⛔ That fallback is the half that is going away: we are no longer compatible
with pkgx and the sovereign pantry is being written
([packages#420](https://github.com/go-zpkg/packages/issues/420),
[#431](https://github.com/go-zpkg/packages/issues/431)). These 213 recipes are
the part that is already ours.

Two purposes.

**1. Correct stale dependency constraints** so `pkgm install` resolves the
closure that our published bottles were actually built against — e.g. curl/wget/git
pin `openssl.org: ^1.1`, but openssl is now 3.x/4.x, so the upstream recipe is
unsatisfiable against the current registry.

BSD-3-Clause, © the go-pkgx authors.

**2. Carry recipes that exist only here.** A recipe the go-pkgx factory adds
through `packages/overrides/` (a creation patch) reaches the BUILD and nothing
else: `overrides/` is applied to the pantry checkout the factory builds from,
while a consumer resolving a closure reads the pantry over HTTP and gets a 404.

`kernel.org/linux` is the case that showed it. The bottle is published, signed
and attested — and `bottle.ResolveClosureFor` could not resolve it at all, so
the only way to install the kernel was to pick its version straight from the
registry and skip the closure walk. **A package published without a readable
recipe is half published.** Recipes created by an override belong here too.
