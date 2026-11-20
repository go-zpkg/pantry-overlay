# curl.se/ca-certs — the Mozilla CA bundle, as curl.se converts and publishes it.
#
# ⛔ WRITTEN FROM THE PROJECT'S OWN PAGE AND FILE (go-zpkg/packages#431), as the
# first recipe on go-zpkg/zpkb v0.92.0's `extract = false` (go-zpkg/zpkb#518,
# go-zpkg/zpkb#487). It is what projects/curl.se/package.hcl's runtime store
# comes from (`--with-ca-fallback` reads OpenSSL's `SSL_CERT_FILE`, set below)
# and what rust-lang.org/cargo's `CARGO_HTTP_CAINFO` names.
#
# ⛔ THE DEFECT THIS REPLACES. pkgxdev/pantry's recipe has `distributable: ~` and
# fetches the bundle INSIDE THE BUILD SCRIPT with `curl -k` — TLS verification
# switched off, and no digest anywhere — so the one package whose whole content
# is "what to trust" was itself fetched trusting nothing, with a build
# dependency on curl.se that made the ca-certs ⇄ curl.se cycle (curl.se's
# recipe declares ca-certs at runtime). Here the file is the `distributable`:
# fetched by the builder's own fetcher, over verified TLS, against a pinned
# SHA-256, and the cycle is gone — nothing is needed to BUILD this package.

summary = "Mozilla's CA certificate store in PEM format, as extracted and published by curl.se"

# https://curl.se/docs/caextract.html, "CA certificate store license": "The PEM
# file is only a converted version of the original one and thus it is licensed
# under the same license as the Mozilla source file: MPL 2.0".
license = "MPL-2.0"

# ⭐ THE VERSION IS THE DATE OF THE DATED FILE, `2026.11.05` for
# https://curl.se/ca/cacert-2026-11-05.pem. Why that and not another number:
#
#   - It is the project's OWN identifier. caextract.html lists every revision
#     "per date of appearance" and links each as /ca/cacert-YYYY-MM-DD.pem with
#     a .sha256 beside it; the bundle has no other version. The undated
#     /ca/cacert.pem is a moving name (its bytes today equal the 2026-11-05 file,
#     and will not on the next conversion), which is exactly what a pin cannot
#     be built on.
#   - It orders. The bundle is replaced, never extended, so "newer" is a date
#     comparison and `*` (what curl.se and rust-lang.org/cargo declare) selects
#     the latest conversion. A curl release number or a Mozilla NSS number would
#     not identify a file: several bundles appear per NSS release, none is named.
#   - ⚠ The date is curl.se's conversion date, which is NOT the date inside the
#     file: the PEM header says "Certificate data from Mozilla as of: Thu Nov 5
#     04:12:01 2026 GMT" and caextract.html says the same of the current one, but
#     the page also says "we only make a new conversion if there is a change in
#     either the script or the source file", so the two can differ.
#
# ⚠ `zpkb versions` renders the file name's dashes as dots and keeps the zero
# padding (`cacert-2026-11-05.pem` → `2026.11.05`), and `{{version.raw}}` keeps
# the dots, so it cannot be spelled back into the URL: the URL below names the
# file and the digest map names the version, and any other version is REFUSED by
# the fail-closed map rather than resolved to the wrong bytes. A new bundle is
# one new line here and a new key, written by `zpkb sourcepin`.
versions {
  url   = "https://curl.se/docs/caextract.html"
  match = "/cacert-\\d{4}-\\d{2}-\\d{2}\\.pem/"
  strip = ["/^cacert-/", "/\\.pem$/"]
}

distributable {
  url     = "https://curl.se/ca/cacert-2026-11-05.pem"
  extract = false

  # 200116 bytes, 118 certificates. Recorded with
  #
  #   zpkb sourcepin --version 2026.11.05 https://curl.se/ca/cacert-2026-11-05.pem
  #
  # ⛔ NOT SIGNED, SO THERE IS NO SIGNER TO NAME. https://curl.se/ca/ has no
  # .asc for the bundle (cacert-2026-11-05.pem.asc answers 404, measured
  # 2026-11-20), and https://curl.se/docs/verify.html says nothing about the
  # bundle (a search of it for "cacert", "pem" and "ca bundle" found none). Daniel
  # Stenberg's key, recorded in projects/curl.se/package.hcl, signs curl's
  # release archives and is not claimed here. What curl.se publishes is a digest:
  # https://curl.se/ca/cacert-2026-11-05.pem.sha256, which is
  # 427c0642… for this file.
  #
  # ⭐ THREE FETCHES AGREE, and two of them are independent of curl.se's
  # answer about itself:
  #   - the builder's own fetcher (`zpkb sourcepin`), 427c0642…;
  #   - `curl` and `shasum -a 256` on a second, separate download, 427c0642…;
  #   - the Internet Archive's copy of the same URL
  #     (web.archive.org/web/2026id_/https://curl.se/ca/cacert-2026-11-05.pem),
  #     a different host and a different publisher, 427c0642… — and
  #     the .sha256 file above says the same.
  # ⚠ THE HONEST LIMIT: no signature, so nothing says WHO made these bytes
  # beyond "what curl.se serves over TLS", and the Archive copy shows the file
  # was the same when it was captured, not that it was right. A digest pins the
  # bytes; whether Mozilla's store is what you want to trust is a policy question
  # this recipe does not answer. caextract.html also says the bundle carries NO
  # NAME CONSTRAINTS ("Several of those CAs have constraints in Firefox … those
  # constraints are thus not brought along"), which is a property of the
  # conversion and is not repaired here.
  sha256 = {
    "2026.11.05" = "427c064216761a1e72a8b30f0d954d08cb6e4435a82091fb865afd20c8497285"
  }
}

build {
  # `extract = false` leaves the file in the build directory under the last
  # segment of the URL's path, mode 0644. The installed name `ssl/cert.pem` is
  # the one both consumers use: runtime.env below and rust-lang.org/cargo's
  # CARGO_HTTP_CAINFO.
  script = [
    "mkdir -p \"{{prefix}}/ssl\"",
    "cp cacert-2026-11-05.pem \"{{prefix}}/ssl/cert.pem\"",
    "chmod 0644 \"{{prefix}}/ssl/cert.pem\"",
  ]
}

# OpenSSL's documented store variable (X509_get_default_cert_file_env). Two
# readers honour it in curl.se's recipe: the curl tool itself
# (src/tool_operate.c:2273-2289) and libcurl through `--with-ca-fallback`
# (lib/vtls/openssl.c:3081-3088), both cited in projects/curl.se/package.hcl.
runtime {
  env = {
    SSL_CERT_FILE = "{{prefix}}/ssl/cert.pem"
  }
}

test {
  dependencies = {
    "openssl.org" = "*"
  }

  script = [
    "test -f \"{{prefix}}/ssl/cert.pem\"",

    # ⛔ EVERY CERTIFICATE PARSES, not just the first: `storeutl` decodes each
    # PEM block as X.509 and stops with an error on one that is not, and its
    # `Total found` has to equal the number of BEGIN lines — a bundle truncated
    # mid-certificate, or an HTML error page saved as .pem, fails one of the two.
    # 118 at 2026.11.05; the floor is a sanity bound, not a pin, because the
    # next conversion changes the count (caextract.html: 145, 144, 148 … 118).
    {
      run = <<EOT
set -eu
pem="{{prefix}}/ssl/cert.pem"
want=$(grep -c '^-----BEGIN CERTIFICATE-----$' "$pem")
[ "$want" -ge 100 ] || { echo "only $want certificates in the bundle" >&2; exit 1; }
openssl storeutl -noout -certs "$pem" > store.txt
grep -qx "Total found: $want" store.txt || { cat store.txt >&2; echo "openssl parsed a different number than the $want BEGIN lines" >&2; exit 1; }
EOT
    },

    # ⛔ AND THE ENVIRONMENT VARIABLE POINTS AT IT, shown by use rather than by
    # string: the first certificate of the bundle is a self-signed root, so it
    # verifies only if the default store is the bundle. With the variable set it
    # must verify; with the variable pointing nowhere the SAME command must fail,
    # which is what makes the first result mean something.
    {
      run = <<EOT
set -eu
pem="{{prefix}}/ssl/cert.pem"
openssl x509 -in "$pem" -out first.pem
SSL_CERT_FILE="$pem" openssl verify -no-CApath first.pem
if SSL_CERT_FILE=/nonexistent openssl verify -no-CApath first.pem >/dev/null 2>&1; then
  echo "verification succeeded without the bundle: the control is void" >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "https://curl.se/docs/caextract.html",              # the dated-revision table (10 entries), "we only make a new conversion if there is a change", the MPL 2.0 licence, the missing name constraints, the "Automated downloads" statement
    "https://curl.se/ca/cacert-2026-11-05.pem",         # lines 1-13 of the header: "Certificate data from Mozilla as of: Thu Nov  5 04:12:01 2026 GMT" and the certdata.txt it was extracted from; 118 BEGIN CERTIFICATE blocks, 200116 bytes
    "https://curl.se/ca/cacert-2026-11-05.pem.sha256",  # 427c0642… for cacert-2026-11-05.pem
    "https://curl.se/docs/verify.html",                 # searched for the bundle: it covers release archives only
  ]

  consulted = [
    # Read for ONE fact, not copied: the consumption contract
    # (`SSL_CERT_FILE: ${{prefix}}/ssl/cert.pem`), and the defect — the bundle
    # fetched with `curl -k` from inside the build script.
    "pkgxdev/pantry projects/curl.se/ca-certs/package.yml",
  ]

  note = <<EOT
⭐ FIRST RECIPE ON `extract = false`. The package IS one file, so it is the
`distributable` and there is no build script that fetches anything.

⛔ NOT SIGNED. The bundle has a digest (.sha256) published by the same host and
no signature, so the chain is: the digest curl.se publishes, the builder's own
fetch, a second download hashed locally, and the Internet Archive's copy — all
four 427c064216761a1e72a8b30f0d954d08cb6e4435a82091fb865afd20c8497285. That is
more than the pantry's `curl -k` had (nothing), and less than a signature: no
key of Daniel Stenberg's is claimed to cover it.

The version is the date of curl.se's dated file; see `versions` for why and for
the one limit it carries (the URL names the file, the digest map names the
version).

⚠ NOT BUILT by the factory. Measured with a local OpenSSL 4.1.0: the test's
three commands against the real file — 118 BEGIN lines, `Total found: 118`, the
first root verifying with SSL_CERT_FILE set and failing with it pointing at a
missing file.
EOT
}
