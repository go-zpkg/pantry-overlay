# The upstream recipe caps node at `^16 || ^18 || ^20`, and our node 20 line
# CANNOT RUN here: the published nodejs.org v20.20.2 artifact is linked against
# libcrypto.so.1.1, while every openssl artifact in this registry is 3.x or 4.x.
# Measured 2026-10-21 rebuilding vitejs.dev 8.3.5 on both linux arches:
#
#   npm install . --global --prefix=/pkgx/vitejs.dev/v8.3.5+brewing
#   node: error while loading shared libraries: libcrypto.so.1.1
#
# vite 8's own package.json says `engines.node: ^20.19.0 || >=22.12.0`, so the
# `^16 || ^18` half was wrong for this version regardless; `>=22.12` is the
# half that vite accepts AND this registry can satisfy (nodejs.org 26.8.1, on
# openssl 4.0.2).
#
# ⛔ This is the INSTALL half of the same correction. packages/overrides/
# carries the build half, and fixing only that one leaves every CONSUMER
# resolving the upstream constraint — onto the node that cannot start.
dependencies = {
  "nodejs.org" = ">=22.12"
}
