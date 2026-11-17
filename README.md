# recipes

The recipes we own, consumed by
[`go-zpkg/artifact`](https://github.com/go-zpkg/artifact) via
`ZPKG_RECIPES_OVERLAY`. A recipe here wins over any same-named recipe in the
pkgx pantry the factory is reading; what is absent here still falls back to that
pantry.

⛔ That fallback is the half that is going away, and it is why this repository
is no longer called `pantry-overlay`: we are no longer compatible with pkgx, the
sovereign recipe set is being written
([packages#420](https://github.com/go-zpkg/packages/issues/420),
[#431](https://github.com/go-zpkg/packages/issues/431)), and `pantry` was always
pkgx's word rather than ours. `overlay` describes a relationship to an upstream
that is being removed; `recipes` describes the contents, which stays true before
and after. These 234 recipes are the part that is already ours.

⚠ Two names deliberately keep the old word, because they name somebody else's
thing: `PantryBase` (it *is* pkgx's pantry, compiled in) and the
`ZPKG_RECIPES_OVERLAY` *overlay* mechanism itself, which exists only for as long
as there is an upstream to sit over.

Two purposes.

**1. Correct stale dependency constraints** so `zpkm install` resolves the
closure that our published artifacts were actually built against — e.g. curl/wget/git
pin `openssl.org: ^1.1`, but openssl is now 3.x/4.x, so the upstream recipe is
unsatisfiable against the current registry.

BSD-3-Clause, © the go-zpkg authors.

**2. Carry recipes that exist only here.** A recipe the go-zpkg factory adds
through `packages/overrides/` (a creation patch) reaches the BUILD and nothing
else: `overrides/` is applied to the pantry checkout the factory builds from,
while a consumer resolving a closure reads the pantry over HTTP and gets a 404.

`kernel.org/linux` is the case that showed it. The artifact is published, signed
and attested — and `artifact.ResolveClosureFor` could not resolve it at all, so
the only way to install the kernel was to pick its version straight from the
registry and skip the closure walk. **A package published without a readable
recipe is half published.** Recipes created by an override belong here too.
