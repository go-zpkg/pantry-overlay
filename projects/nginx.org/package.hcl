# nginx.org — the nginx HTTP and reverse proxy server, with the stream (TCP/UDP)
# proxy. A whole recipe (go-zpkg/packages#440 step 1): it was a fragment of
# three dependencies.
#
# ⛔ WRITTEN FROM NGINX'S OWN FILES (go-zpkg/packages#431), at 1.31.9.
#
# WHAT IS INSTALLED, under the prefix: sbin/nginx, conf/ (nginx.conf and the
# samples), html/ and an empty logs/. No service registration: no systemd unit,
# no launchd plist, no init script, no user or group is created (--user and
# --group are not passed, so workers run as the user who started the master).
# The log, pid and temp paths stay RELATIVE to the prefix (auto/options:650-668),
# which is what a prefix that is not writable at run time needs `nginx -p <dir>`
# for; the test does exactly that.
#
# ⭐⭐ WHAT WRITING IT FOUND:
#   1. THE FRAGMENT DECLARED THE WRONG REGEX LIBRARY. It pinned pcre.org 8.45,
#      the legacy PCRE. Since 1.21.5 nginx tries PCRE2 FIRST (auto/options:160
#      PCRE2=YES; auto/lib/pcre/conf:75-111) and only falls back to the old
#      library when PCRE2 is not found (:113-). A builder with both ends up with
#      PCRE2, a builder with only 8.45 with an unmaintained library, and nothing
#      said which. Named below: pcre.org/v2, and `--with-pcre` so a missing one
#      is fatal rather than silently regex-less.
#   2. OpenSSL is PROBED, not pointed at: --with-openssl=DIR means the OpenSSL
#      SOURCE tree (auto/lib/openssl/conf:6-45), and the system probe walks
#      /usr/local, /usr/pkg, /opt/local and /opt/homebrew in turn (:75-137), so
#      on a Mac the library that links is the first one that answers. The
#      -I/-L options below make the first plain probe (:62-66) answer.
#   3. THE FRAGMENT'S OPENSSL BOUGHT NOTHING: http_ssl_module defaults to NO
#      (auto/options:64), so without it there is no `ssl` directive at all.

summary = "nginx: an HTTP and reverse proxy server, a mail proxy server and a generic TCP/UDP proxy server"

# LICENSE:1-9: BSD-2-Clause, "Copyright (C) 2002-2021 Igor Sysoev, Copyright
# (C) 2011-2026 Nginx, Inc.". Nothing is bundled: PCRE2, OpenSSL and zlib are
# linked from their own recipes, and no --with-*=DIR source option is used.
license = "BSD-2-Clause"

versions {
  url   = "https://nginx.org/download/"
  match = "/nginx-\\d+\\.\\d+\\.\\d+\\.tar\\.gz/"
  strip = ["/nginx-/", "/\\.tar\\.gz/"]
}

dependencies = {
  # --with-http_ssl_module, --with-stream_ssl_module: fatal when not found
  # (auto/lib/openssl/conf:183).
  "openssl.org" = "^3"
  # --with-pcre, below.
  "pcre.org/v2" = "*"
  # The gzip module, on by default (auto/options:63), sets USE_ZLIB
  # (auto/modules:269) and auto/lib/zlib/conf stops without a zlib.
  "zlib.net" = "*"
}

distributable {
  url              = "https://nginx.org/download/nginx-{{version.raw}}.tar.gz"
  strip-components = 1

  # 1388470 bytes. ⚠ A SINGLE-HOST CHAIN, stated, but a signed one:
  #
  #   signed by    D6786CE303D9A9022998DC6CC8464D549AF75C0A, 2026-11-11
  #                Sergey Kandaurov <pluknet@nginx.com>
  #   key bytes    https://nginx.org/keys/pluknet.key, listed on
  #                https://nginx.org/en/pgp_keys.html (that page prints no
  #                fingerprint; the fingerprint is the key file's own)
  #   signature    https://nginx.org/download/nginx-1.31.9.tar.gz.asc
  #   tarball      nginx.org
  #
  # VERIFIED with `zpkb sourcepin --sig auto --key pluknet.key --fingerprint …`
  # (v0.92.0), no keyserver asked, and confirmed by a second, independent
  # fetch-and-hash. The tarball, the signature and the key come from ONE host,
  # so this chain does not survive nginx.org being compromised.
  sha256 = {
    "1.31.9" = "a11c5eeee2e257f4478f0e649f84b0040787d277d2d3e5233952aa6b6dcb80ad"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # Where the libraries are. See finding 2: the probes are the only
      # mechanism nginx has for an installed OpenSSL, PCRE2 or zlib.
      "--with-cc-opt=-I{{deps.openssl.org.prefix}}/include -I{{deps.pcre.org/v2.prefix}}/include -I{{deps.zlib.net.prefix}}/include",
      "--with-ld-opt=-L{{deps.openssl.org.prefix}}/lib -L{{deps.pcre.org/v2.prefix}}/lib -L{{deps.zlib.net.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib -Wl,-rpath,{{deps.pcre.org/v2.prefix}}/lib -Wl,-rpath,{{deps.zlib.net.prefix}}/lib",

      # ⛔⛔ THE LIBRARIES, EACH NAMED.
      "--with-pcre", # auto/options:388, fatal when none is found; PCRE2 is tried first (:160)
      "--with-http_ssl_module",
      "--with-stream",
      "--with-stream_ssl_module",
      "--with-stream_ssl_preread_module",

      # Named modules that cost no library, chosen as the ones deployments
      # routinely use and that are OFF by default (auto/options:64-117, 127-143):
      "--with-http_v2_module",
      "--with-http_realip_module",
      "--with-http_addition_module",
      "--with-http_sub_module",
      "--with-http_gunzip_module",
      "--with-http_gzip_static_module",
      "--with-http_auth_request_module",
      "--with-http_random_index_module",
      "--with-http_secure_link_module",
      "--with-http_slice_module",
      "--with-http_stub_status_module",
      "--with-stream_realip_module",
      # Thread pools (auto/options:46), a runtime feature of the aio directive.
      "--with-threads",

      # ⛔ REFUSED, each OFF by default and named so a change of default shows:
      # modules that need a library no recipe in this tree provides —
      #   --with-http_xslt_module     (libxml2 and libxslt, :69, :174)
      #   --with-http_image_filter_module (libgd, :70, :175)
      #   --with-http_geoip_module, --with-stream_geoip_module (GeoIP, :85, :132, :176)
      #   --with-http_perl_module     (a perl, :96, :171)
      #   --with-google_perftools_module (:178)
      #   --with-libatomic            (:181)
      # QUIC/HTTP/3 needs an OpenSSL with the QUIC API (:66, :163), which the
      # ^3 pin does not promise:
      #   --with-http_v3_module
      # Features left off:
      #   --with-mail, --with-mail_ssl_module (:121)  — no mail proxy
      #   --with-file-aio (:48), --with-http_dav_module (:73), --with-http_flv_module,
      #   --with-http_mp4_module, --with-http_degradation_module, --with-http_json_module,
      #   --with-compat, --with-debug (:24, :153)
      # and --user / --group are not given (see the header).
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

provides = [
  "sbin/nginx",
]

test {
  script = [
    # `nginx -V` prints the configure line; every pin above is read back.
    "nginx -V 2> nginx.v",
    "grep -q -- --with-http_ssl_module nginx.v",
    "grep -q -- --with-pcre nginx.v",
    "grep -q -- --with-stream_ssl_module nginx.v",
    "grep -q 'built with OpenSSL 3' nginx.v",
    "! grep -q -- --with-http_xslt_module nginx.v",
    "! grep -q -- --user= nginx.v",
    "test ! -e \"{{prefix}}/lib/systemd\"",
    "test -z \"$(find {{prefix}} -name '*.service' -o -name '*.plist')\"",
    # The regex engine that linked is PCRE2, not the legacy PCRE.
    {
      run = <<EOT
set -eu
case "$(uname -s)" in
  Linux)  ldd "$(command -v nginx)" > libs.txt ;;
  Darwin) otool -L "$(command -v nginx)" > libs.txt ;;
esac
grep -q pcre2 libs.txt
! grep -q 'libpcre\.' libs.txt
EOT
    },
    # A configuration that can only parse when each named module is in the
    # binary: `ssl_protocols` (http_ssl), `http2` (v2), a regex location
    # (PCRE2), gzip_static, stub_status, stream with ssl_preread. nginx -t
    # reports an unknown directive otherwise.
    {
      run = <<EOT
set -eu
D="$(mktemp -d)"
trap 'rm -rf "$D"' EXIT
mkdir -p "$D/logs"
cat > "$D/nginx.conf" <<CONF
pid $D/nginx.pid;
error_log $D/logs/error.log;
events {}
http {
  access_log off;
  gzip on;
  server {
    listen unix:$D/http.sock;
    http2 on;
    location ~ ^/a(.)\$ { return 200 \$1; }
    location /status { stub_status; }
    location /s { gzip_static on; }
  }
  server {
    listen unix:$D/https.sock ssl;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_certificate $D/none.pem;
    ssl_certificate_key $D/none.key;
  }
}
stream {
  server { listen unix:$D/stream.sock; ssl_preread on; return ok; }
}
CONF
# -t also loads the certificate; give it a self-signed one when openssl exists.
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$D/none.key" -out "$D/none.pem" -subj /CN=t -days 1 >/dev/null 2>&1
nginx -p "$D" -c "$D/nginx.conf" -t
EOT
    },
  ]
}

provenance {
  read = [
    "auto/options",            # :24 debug, :46-48 threads and file-aio, :61-117 every HTTP module's default, :121-143 mail and stream, :155-176 pcre, openssl, zlib, perl, xslt, gd, geoip, :388-392 the pcre options, :452-637 the option list, :650-668 the relative paths
    "auto/lib/pcre/conf",      # :6-62 a source tree, :75-111 PCRE2 first, :113-151 then PCRE
    "auto/lib/conf",           # :6-16 rewrite needs PCRE, :28 zlib
    "auto/lib/openssl/conf",   # :6-45 DIR is a SOURCE tree, :62-137 the system probes by platform, :183 fatal when missing
    "auto/modules",            # :269, :362 which modules set USE_ZLIB
    "auto/unix",               # :132-155 crypt() from libc or -lcrypt, no failure when absent
    "LICENSE",                 # :1-9 BSD-2-Clause
    "https://nginx.org/en/pgp_keys.html",
    "https://nginx.org/keys/pluknet.key",
  ]

  consulted = [
    # Read for facts only: URL shape. Nothing copied.
    "pkgxdev/pantry projects/nginx.org/package.yml",
  ]

  note = <<EOT
⚠ crypt() (auth_basic's {CRYPT} passwords) is taken from whatever the platform's
libc or libcrypt provides (auto/unix:132-155) and is silently left out when
neither does. No recipe here provides libxcrypt, so on a glibc without libcrypt
the module still builds and rejects crypt hashes at run time.

⚠ The test's certificate comes from the `openssl` command when the test
environment has one; without it `nginx -t` fails on the missing certificate,
which is a failure of the fixture and not of the build.

⛔ NOT BUILT. No session here can run the factory; configure's options and the
test are read from the sources, not run.
EOT
}
