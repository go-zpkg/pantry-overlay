# vitejs.dev — Vite, the front-end build tool and dev server (vitejs/vite).
#
# ⛔ A FRAGMENT UNTIL NOW: it carried only the dependency line below and took its
# source, versions and build from the upstream pantry. This is the WHOLE recipe,
# written from the published package's own files (go-zpkg/packages#440 step 1),
# at 8.3.8.
#
# The node line: the upstream recipe capped node at `^16 || ^18 || ^20`, and our
# node 20 line CANNOT RUN here: the published nodejs.org v20.20.2 artifact is
# linked against libcrypto.so.1.1, while every openssl artifact in this registry
# is 3.x or 4.x. Measured 2026-10-21 rebuilding vitejs.dev 8.3.5 on both linux
# arches:
#
#   npm install . --global --prefix=/pkgx/vitejs.dev/v8.3.5+brewing
#   node: error while loading shared libraries: libcrypto.so.1.1
#
# (Quoted verbatim from that day's log; the staging suffix is `+builddir` since
# zpkb v0.80.0 and the store is `/zpkg`, which does not change what was measured.)
#
# package.json:"engines" is `node: ^20.19.0 || >=22.12.0`; `>=22.12` is the half
# that vite accepts AND this registry can satisfy (nodejs.org 26.8.1, on openssl
# 4.0.2). Every CONSUMER resolves this constraint too, so it is kept here.

summary = "Vite: native-ESM front-end build tool and dev server"

# package.json:"license" "MIT"; LICENSE.md is the MIT text.
license = "MIT"

versions {
  npm = "vite"
}

dependencies = {
  "nodejs.org" = ">=22.12"
}

distributable {
  # THE PACKAGE'S OWN npm TARBALL (592262 bytes): dist/, bin/vite.js, types and
  # package.json, with the single top directory `package/`.
  url              = "https://registry.npmjs.org/vite/-/vite-{{version.raw}}.tgz"
  strip-components = 1

  # Recorded with `zpkb sourcepin`. SECOND WITNESS: the registry's own metadata
  # (registry.npmjs.org/vite/latest, dist.shasum) lists the SHA-1
  # ad713bf2e46c241f344b5e50401297b77a08621d for this file, and shasum -a 1 of
  # the fetched file gave the same value. ⚠ Both come from ONE host. The
  # registry also carries signatures and a SLSA provenance attestation
  # (dist.attestations); neither was verified here. 8.3.8 is the newest
  # release `zpkb versions` resolves.
  sha256 = {
    "8.3.8" = "96b14ea41f889b70b1ccf74dd5861e365816fce8632c5073ce8d70c90509738b"
  }
}

provides = [
  "bin/vite",
]

build {
  dependencies = {
    "nodejs.org" = ">=22.12"
  }

  script = [
    {
      # The tarball ships no lockfile and no npm-shrinkwrap.json
      # (registry metadata: "_hasShrinkwrap": false), so the five runtime
      # dependencies (postcss, rolldown, picomatch, tinyglobby, lightningcss;
      # package.json "dependencies") and their transitive tree are resolved by npm
      # from the registry at build time. ⚠ THAT TREE IS NOT PINNED BY THIS
      # RECIPE. --omit=dev drops devDependencies (the monorepo build tooling);
      # --install-links copies the package instead of symlinking the build
      # directory, which would dangle after the build.
      run = <<EOT
set -eu
npm install --global --omit=dev --install-links --prefix "{{prefix}}" .
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
OUT="$(vite --version)"
case "$OUT" in
  *"{{version.raw}}"*) ;;
  *) echo "--version printed '$OUT'" >&2; exit 1 ;;
esac
vite --help > help.txt
test -s help.txt
EOT
    },
  ]
}

provenance {
  read = [
    "package.json", # "version" 8.3.8; "license" MIT; "bin" vite -> bin/vite.js; "engines" node ^20.19.0 || >=22.12.0; "dependencies" (five); "optionalDependencies" fsevents
    "LICENSE.md",   # MIT
    "bin/vite.js",  # the executable
  ]

  consulted = [
    # Facts only: the name. NOT taken: its node constraint (see the header).
    "pkgxdev/pantry projects/vitejs.dev/package.yml",
  ]

  note = <<EOT
⛔ NOT BUILT, NOT TESTED. The first factory run is this file's test. The
`vite --version` output format ("vite/8.3.8 <platform> node-<v>") is from
vite's cli source and was not run here.

⚠ THE DEPENDENCY TREE IS RESOLVED AT BUILD TIME by npm (no lockfile ships in the
tarball), so two builds of one version may differ in transitive versions. rolldown
and lightningcss select a per-platform native binary through optionalDependencies.
Pinning the tree needs the monorepo's pnpm-lock.yaml and pnpm, neither of which is
in this registry.
EOT
}
