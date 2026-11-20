# nmap.org — Nmap, the network scanner, with its Ncat and Nping companions. This
# tree carried only a dependency list for it (a fragment, go-zpkg/packages#440
# step 1); this is the whole recipe.
#
# ⛔ WRITTEN FROM NMAP'S OWN FILES (go-zpkg/packages#431), at 7.993.
#
# ⭐⭐ WHAT WRITING IT FOUND: nmap's configure picks EVERY one of its libraries by
# looking at the build machine, and falls back to a bundled copy without a word:
#   libpcap  configure.ac:468-550  a system libpcap if one is "suitable", else the bundled
#   pcre2    :562-609              a system pcre2, else the bundled
#   zlib     :621-696              a system zlib, else the bundled (no way to make it fatal)
#   libssh2  :705-779              a system libssh2, else the bundled
#   lua      :843-936              a system Lua that is EXACTLY 5.4, else the bundled
#   liblinear :950-999             a system liblinear, else the bundled
#   openssl  :391-461              WARNS and builds WITHOUT TLS when it finds none
# and `nmap --version` ("Compiled with:", nmap.cc:2808-2902) tells which of them
# won: a bundled one is printed with an `nmap-` prefix. Every choice is named
# below, and the test reads each back from that line.

summary = "Nmap: network exploration and security auditing, with Ncat and Nping"

# LICENSE:1 "Nmap Public Source License Version 0.95" (SPDX NPSL-0.95); ncat/LICENSE
# and nping/LICENSE:1-3 say "the same license terms as Nmap". Added only for code
# this build compiles in: the bundled libpcap (libpcap/LICENSE: three-clause BSD),
# libdnet (libdnet-stripped/LICENSE: three-clause BSD), liblinear
# (liblinear/COPYRIGHT: three-clause BSD) and Lua (liblua/lua.h, its tail: MIT);
# nbase/getopt.c and nselib/base64.lua carry MIT notices. NOT compiled, so not
# added: libz/, libssh2/, libpcre/ (system copies are used), zenmap and ndiff.
# NOT READ: every file of nselib/ and scripts/ (each script's licence is the NPSL
# by LICENSE:1's "Covered Software" clause; individual files were not opened).
license = "NPSL-0.95 AND BSD-3-Clause AND MIT"

versions {
  url   = "https://nmap.org/dist/"
  match = "/nmap-\\d+\\.\\d+(\\.\\d+)?\\.tgz/"
  strip = ["/nmap-/", "/\\.tgz/"]
}

dependencies = {
  # Passed by directory below, and read back by the test: with a DIR argument
  # configure.ac:644-656 (zlib), :723-740 (libssh2) FALL BACK SILENTLY to the
  # bundled copy when the check fails.
  "libssh2.org" = "^1"
  "openssl.org" = "^3"
  "pcre.org/v2" = "^10"
  "zlib.net"    = "*"
}

distributable {
  # 15653215 bytes. Recorded with `zpkb sourcepin --sig` (signature verified, see
  # provenance.note); the project's own digest page agrees (see there).
  url              = "https://nmap.org/dist/nmap-{{version.raw}}.tgz"
  strip-components = 1

  sha256 = {
    "7.993" = "b9477f6208cd67f6de6d0b58cecd61284947f9728b9b3d446bfa6030da088027"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔ OpenSSL, BY DIRECTORY. :393-408: a DIR makes a missing ssl.h / libcrypto /
      # libssl FATAL (:414-415, :429-430, :443-444); the default only warns and
      # builds without TLS, so Ncat's --ssl and the ssl-* scripts would vanish
      # (ncat/ncat_main.c:668-671: "OpenSSL isn't compiled in"). configure.ac:403
      # forwards it to the sub-configures (ncat, nping, libssh2).
      "--with-openssl={{deps.openssl.org.prefix}}",

      # ⛔ pcre2, BY DIRECTORY (:570-575: taken without a check; a wrong DIR is a
      # compile error, not a quiet fallback).
      "--with-libpcre={{deps.pcre.org/v2.prefix}}",

      # ⛔ zlib and libssh2: DIR forms; the fallback to the bundled copy is silent
      # (above), so the test checks "libz-" and "libssh2-" lack the `nmap-` prefix.
      "--with-libz={{deps.zlib.net.prefix}}",
      "--with-libssh2={{deps.libssh2.org.prefix}}",

      # ⛔ BUNDLED, ON PURPOSE, THE SAME ON EVERY BUILDER:
      #   libpcap  `included` (:473, :480-482). No libpcap recipe is in this tree,
      #            and the default would pick whatever the builder has (:476-478).
      #   lua      `included` (:855-863): nmap needs Lua 5.4 EXACTLY (:889-912),
      #            liblua/lua.h:19-21 is 5.4.9, and the default asks the builder.
      #   libdnet  `included` is already the default (:792-799, "we have made many
      #            important fixes"); named so a changed default shows here.
      #   liblinear `included` (:960-967).
      "--with-libpcap=included",
      "--with-liblua=included",
      "--with-libdnet=included",
      "--with-liblinear=included",

      # REFUSED: Ndiff and Zenmap. Both are Python packages installed with
      # `pip install` (Makefile.in:368, :390) and only built when configure finds
      # a Python with setuptools (:244-254, :286-294, :325-333): a builder with
      # Python would ship them, one without would not, and neither is `provides`d.
      "--without-ndiff",
      "--without-zenmap",

      # The bundled libpcap's own probes, which configure.ac:520 hands the same
      # arguments: libnl is "if_available" on linux (libpcap/configure.ac:1015-1017)
      # and netmap is "yes, if support available" (:2535-2563). Both off, so the
      # capture library does not depend on what the builder has. usb, bluetooth
      # and dpdk default to no (:2437-2440, :2773-2776, :2566-2567); dbus and rdma
      # are forced off by nmap's own configure (:520).
      "--without-libnl",
      "--disable-netmap",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# Makefile.in:325-326 installs nmap; ncat and nping are built unless
# --without-ncat / --without-nping (configure.ac:362-379, :1158-1178).
provides = [
  "bin/ncat",
  "bin/nmap",
  "bin/nping",
]

test {
  script = [
    {
      run = <<EOT
set -eu
NMAP="{{prefix}}/bin/nmap"
NCAT="{{prefix}}/bin/ncat"

# nmap.cc:2891-2900: the first line, then which libraries it was built with.
"$NMAP" --version > version.txt
head -1 version.txt | grep -q '^Nmap version {{version.raw}} '
with="$(grep '^Compiled with:' version.txt)"
without="$(grep '^Compiled without:' version.txt)"

# Each backend read off the artifact. A bundled library carries `nmap-`
# (nmap.cc:2813-2815, :2833-2836, :2843-2846, :2854-2858, :2872-2876, :2879-2883).
for want in ' nmap-liblua-5.4.' ' openssl-3.' ' libssh2-' ' libz-' ' libpcre2-' ' nmap-libpcap-' ' nmap-libdnet-' ' ipv6'; do
  case "$with" in *"$want"*) ;; *) echo "'$want' missing from: $with" >&2; exit 1;; esac
done
# the system copies must NOT have fallen back to the bundled ones
for bad in nmap-libz- nmap-libssh2- nmap-libpcre2-; do
  case "$with" in *"$bad"*) echo "bundled $bad was built: $with" >&2; exit 1;; esac
done
[ "$without" = "Compiled without:" ] || { echo "$without" >&2; exit 1; }

# Ncat: --ssl is only listed when OpenSSL is compiled in (ncat_main.c:636-637).
"$NCAT" --version 2>&1 | grep -q 'Ncat: Version {{version.raw}} '
"$NCAT" --help | grep -q 'Connect or listen with SSL'
"{{prefix}}/bin/nping" --version | grep -q 'Nping version {{version.raw}} '

# A real scan of a real listener, unprivileged (-sT), through NSE (Lua) and the
# service database in share/nmap: Ncat answers with a banner, nmap's `banner`
# script reads it back.
PORT=38417
"$NCAT" -l -k 127.0.0.1 $PORT -c 'echo ncat-banner-ok' &
L=$!
trap 'kill $L 2>/dev/null || true' EXIT
sleep 1
"$NMAP" -sT -Pn -n -p $PORT --script banner -oG scan.gnmap -oN scan.nmap 127.0.0.1 > /dev/null
grep -q "Ports: $PORT/open/tcp/" scan.gnmap
grep -q 'banner: ncat-banner-ok' scan.nmap
test -s "{{prefix}}/share/nmap/nmap-services"
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",                    # :391-461 openssl, :465-550 libpcap, :557-615 pcre2, :618-701 zlib, :703-784 libssh2, :787-839 libdnet, :841-945 lua, :950-1005 liblinear, :282-385 ndiff/zenmap/nping, :1156-1186 ncat
    "ncat/configure.ac",               # :14-26 and :66-105 openssl, :120-194 libpcap, :205-238 lua: the same switch grammar
    "libpcap/configure.ac",            # :1015-1017 libnl, :2437 usb, :2535 netmap, :2566 dpdk, :2773 bluetooth
    "nmap.cc",                         # :2808-2902 display_nmap_version, the line the test reads
    "nmap.h",                          # :125-131 NMAP_VERSION
    "ncat/ncat_main.c",                # :636-641 --ssl help, :668-671 no-OpenSSL refusal
    "Makefile.in",                     # :325-344 installed files, :368 and :390 pip for zenmap and ndiff
    "LICENSE",                         # :1 NPSL 0.95, :271-277 the OpenSSL linking permission
    "ncat/LICENSE",                    # same terms as Nmap
    "nping/LICENSE",                   # same terms as Nmap
    "libpcap/LICENSE",                 # BSD
    "libdnet-stripped/LICENSE",        # BSD
    "liblinear/COPYRIGHT",             # BSD
    "liblua/lua.h",                    # :19-21 Lua 5.4.9, the tail: MIT
    "https://nmap.org/book/install.html",        # Example 2.2: the key fingerprints
    "https://nmap.org/dist/sigs/nmap-7.993.tgz.digest.txt",  # the project's own digests
  ]

  consulted = [
    # Read for facts only: URL shape, the pcre2 prefix, and that the upstream test
    # was `nmap -vvvv localhost`. Its python-venv, sed-on-source and linux
    # configure patches were NOT taken: ndiff and zenmap are refused above, and the
    # libdnet patch (netpacket/packet.h absent from a minimal builder's glibc) was
    # not verified here.
    "pkgxdev/pantry projects/nmap.org/package.yml",
  ]

  note = <<EOT
SIGNATURE VERIFIED, against the project's own key file and a fingerprint read from
the project's own chapter.

  signature   https://nmap.org/dist/sigs/nmap-7.993.tgz.asc
  signed at   2026-10-26T21:08:35Z
  signer      Nmap Project Signing Key
  fingerprint 436D66AB9A798425FDA0E3F801AF9F036B9355D0
  fingerprint from  https://nmap.org/book/install.html, Example 2.2 (the project's
              own installation chapter; the key file is nmap_gpgkeys.txt, linked from
              the same chapter)

No keyserver was asked (zpkb v0.92.0, sourcepin --sig). A SECOND, INDEPENDENT
CHECK: the project's digest page https://nmap.org/dist/sigs/nmap-7.993.tgz.digest.txt
lists SHA256 = B9477F62 08CD67F6 DE6D0B58 CECD6128 4947F972 8B9B3D44 6BFA6030
DA088027, and `curl` + `shasum -a 256` of the archive gave the same digest. ⚠ The
digest page is on the host that serves the archive: continuity, not independence;
the signature is the warrant.

BUILT AND TESTED ON A MACHINE, NOT BY THE FACTORY: configure, make and make install
on this source, darwin/arm64, with Homebrew's openssl 3.6.5, pcre2 10.49 and libssh2
1.11.1 and the macOS SDK's zlib passed by directory, all the switches above. It printed
`Compiled with: nmap-liblua-5.4.9 openssl-3.6.5 libssh2-1.11.1 libz-1.2.12
libpcre2-10.49 nmap-libpcap-(64-bit nmap-libdnet-1.18.2 ipv6` and `Compiled without:`
(the libpcap token is nmap.cc:2871's own word-splitting of libpcap's version string),
and the scan above found 38417/open and the banner. The switches --without-libnl and
--disable-netmap were accepted without a warning on darwin, where those probes are not
reached, so their effect on linux is read from libpcap/configure.ac, not measured.

⛔ NOT BUILT BY THE FACTORY, NOT BUILT ON LINUX. No session here can run it.
EOT
}
