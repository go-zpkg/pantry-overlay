# openresty.org — the nginx-based web platform bundling LuaJIT and the lua-nginx
# module. One of the fragments of go-zpkg/packages#440: it declared four
# dependencies and nothing else.
#
# ⛔ WRITTEN FROM OPENRESTY'S OWN FILES, at 1.31.8.1.
#
# ⭐⭐ THE FINDING IS ABOUT PCRE. OpenResty's `configure` is a Perl program that
# hands nearly every option to the bundled nginx 1.31.8, and nginx PREFERS PCRE2:
# auto/options:160 sets PCRE2=YES, and auto/lib/pcre/conf:75 probes PCRE2 first.
# The dependency this recipe declares is PCRE 8 (pcre.org = 8), so a builder that
# also has PCRE2 on its search path would build against PCRE2 and say nothing.
# Both pins are below, each with the line that makes it loud.

summary = "OpenResty: nginx with LuaJIT and the lua-nginx modules bundled, for scriptable web servers"

# BSD-2-Clause for OpenResty's own code: COPYRIGHT:1-36 is the two-clause text
# (retain the notice, reproduce it in binaries) over the copyright holders. The
# bundle also carries MIT (nginx, lua-cjson, LuaJIT) and PCRE's BSD licence in
# the same COPYRIGHT file; the recipe states the licence of the project itself.
license = "BSD-2-Clause"

versions {
  # ⚠ FOUR-COMPONENT versions (1.31.8.1), unlike zlib's four-part tag that has
  # to be ignored. Measured 2026-11-21 with `zpkb versions`: 65 versions
  # resolve, in the right order (1.31.8.1 first; 1.11.2.x above 1.9.15.1;
  # 1.2.4.14 above 1.2.3.8; 1.0.6.22 last), so the newest is the one pinned.
  url   = "https://openresty.org/download/"
  match = "/openresty-\\d+\\.\\d+\\.\\d+\\.\\d+\\.tar\\.gz/"
  strip = [
    "/^.*openresty-/",
    "/\\.tar\\.gz$/",
  ]
}

dependencies = {
  # PCRE 8 and OpenSSL and zlib are LINKED by the nginx binary; perl runs
  # `configure` and the installed `resty` and `opm` command-line tools, which
  # are Perl scripts, so it is runtime and not only build.
  "openssl.org" = "^3"
  "pcre.org"    = 8
  "perl.org"    = "*"
  "zlib.net"    = "^1.2"
}

distributable {
  url              = "https://openresty.org/download/openresty-{{version}}.tar.gz"
  strip-components = 1

  # 6704565 bytes. The tarball is signed (the .asc beside it, key
  # B550E09EA0E98066), but the key bytes could not be obtained without a
  # keyserver, so the signature was NOT verified. The second witness is an
  # independent fetch: fossies.org serves the same file and its sha256 is
  # identical. See provenance.note for what that does and does not prove.
  sha256 = {
    "1.31.8.1" = "b569c63b420f80a4ac8466f2deffe73ed93ab760026532e039c3658409a997f4"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ PCRE, TWICE. (1) `--without-pcre2` (auto/options:393) sets
      # PCRE2=DISABLED, which skips the PCRE2 probe at auto/lib/pcre/conf:75
      # entirely; without it a PCRE2 on the builder wins silently over the
      # declared PCRE 8. (2) `--with-pcre` (auto/options:388) is USE_PCRE=YES:
      # a miss of -lpcre then reaches conf:223-232, "the HTTP rewrite module
      # requires the PCRE library", exit 1. ⚠ NOT `--with-pcre=DIR`: that is
      # the path to PCRE's SOURCES, which nginx builds (conf:8), not an
      # installed prefix. The prefix is given through the search paths below.
      "--without-pcre2",
      "--with-pcre",
      "--with-pcre-jit",

      # The default is on (configure:1393); named so a future default change
      # is not a silent loss of TLS. Its probe is fatal when OpenSSL is missing.
      "--with-http_ssl_module",
    ]
  }

  script = [
    # The installed prefixes reach nginx only through the compiler and linker
    # options (configure:258-263 pass them on), and they carry spaces, so they
    # are quoted here rather than put in ARGS. -rpath makes the installed
    # nginx find the libraries it was linked against.
    {
      run = <<EOT
set -eu
./configure $ARGS \
  "--with-cc-opt=-I{{deps.pcre.org.prefix}}/include -I{{deps.openssl.org.prefix}}/include -I{{deps.zlib.net.prefix}}/include" \
  "--with-ld-opt=-L{{deps.pcre.org.prefix}}/lib -L{{deps.openssl.org.prefix}}/lib -L{{deps.zlib.net.prefix}}/lib -Wl,-rpath,{{deps.pcre.org.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib -Wl,-rpath,{{deps.zlib.net.prefix}}/lib"
EOT
    },
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# configure:444 links bin/openresty to the nginx binary; :1146-1180 install opm
# and resty-cli into $prefix/bin/. The nginx binary itself is under
# nginx/sbin/ and is not listed.
provides = [
  "bin/openresty",
  "bin/resty",
  "bin/opm",
]

test {
  script = [
    "test -x \"{{prefix}}/bin/openresty\"",
    "test -x \"{{prefix}}/bin/resty\"",
    "test -x \"{{prefix}}/nginx/sbin/nginx\"",
    {
      run = <<EOT
set -eu
out=$("{{prefix}}/bin/openresty" -V 2>&1)
case "$out" in
  *"{{version}}"*) ;;
  *) echo "openresty -V does not name {{version}}:" >&2; echo "$out" >&2; exit 1 ;;
esac
for flag in --with-pcre-jit --without-pcre2 --with-http_ssl_module; do
  case "$out" in
    *"$flag"*) ;;
    *) echo "nginx was configured without $flag:" >&2; echo "$out" >&2; exit 1 ;;
  esac
done
EOT
    },

    # ⛔ THE REGRESSION TEST FOR THE PCRE PIN, read off the artifact: the nginx
    # binary names PCRE 8's shared object (libpcre.so.1 or libpcre.1.dylib)
    # and not PCRE2's (libpcre2-8). The pattern `libpcre\.` cannot match
    # `libpcre2-8`, which is the point.
    "grep -qa 'libpcre\\.' \"{{prefix}}/nginx/sbin/nginx\"",

    # LuaJIT and the lua-nginx module are actually in the binary.
    "\"{{prefix}}/bin/resty\" -e 'print(jit.version)'",
  ]
}

provenance {
  read = [
    "configure",                                  # Perl; :258-263 cc/ld-opt; :274-283 --with-luajit*; :347-358 --with-pcre=DIR is a SOURCE path; :444 bin/openresty link; :1146-1180 opm and resty; :1267 default prefix; :1355-1394 options
    "COPYRIGHT",                                  # :1-36 BSD-2-Clause text; :97 NGINX, :158 Lua, :396 PCRE licences of the bundle
    "bundle/nginx-1.31.8/auto/options",           # :160 PCRE2=YES; :388-393 --with-pcre, --with-pcre=, --without-pcre2
    "bundle/nginx-1.31.8/auto/lib/pcre/conf",     # :8 --with-pcre=DIR is sources; :75 PCRE2 probed first; :113-206 PCRE (1) probe via -lpcre; :223-232 the fatal exit
    "https://openresty.org/en/download.html",     # line 238: "All the releases are signed by the public PGP key A0E98066 of Yichun Zhang"
    "https://openresty.org/download/",            # the release index, and an .asc beside every archive
  ]

  note = <<EOT
⚠ THE SIGNATURE WAS NOT VERIFIED, and this is stated rather than papered over.

  signature   https://openresty.org/download/openresty-1.31.8.1.tar.gz.asc
  key id      B550E09EA0E98066 (the page says A0E98066, its last eight digits)
  fingerprint 25451EB088460026195BD62CB550E09EA0E98066 (read from the issuer
              fingerprint subpacket of the signature itself)
  signed at   2026-10-26

Signature present, key unobtainable without a keyserver: openresty.org links no
public key (misc/openresty.asc is a 404; package/pubkey.gpg is a different key,
the package-signing one, E52218E7087897DC6DEA6D6D97DB7443D5EDEB74), and
GitHub's account endpoint for the maintainer answers "The keys with the
following IDs couldn't be exported and need to be reuploaded B550E09EA0E98066"
— it binds the key id to the account, as for libssh2, but cannot serve the
bytes. No keyserver was asked.

THE SECOND WITNESS is an independent fetch, as recipe-rules.md allows when no
key or checksum file exists: openresty.org and fossies.org serve the same
6704565 bytes with the same sha256. That shows two hosts agree on the bytes
today; it does not show the author signed them, and fossies.org is a mirror
that itself fetched from upstream.
Neither a .md5 nor a .sha256 is published (both 404).
EOT
}
