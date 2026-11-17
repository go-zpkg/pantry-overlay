# sourceware.org/bzip2 — the bzip2 compressor and libbz2, which 15 recipes in
# this tree name.
#
# ⛔ WRITTEN FROM BZIP2'S OWN FILES (go-zpkg/packages#431), at 1.0.8. Third of
# the twenty-two in go-zpkg/recipes#143, after openssl.org (#145) and
# facebook.com/zstd (#146), and chosen by counting consumers: 15, behind only
# gnu.org/gettext's 26 — which leads for a reason that is partly an artefact.
#
# ⭐ AND IT IS THE PROJECT go-zpkg/packages#310 MEASURED, which is why the
# `provides` list below is four names rather than eleven. See the note there.
#
# ⚠ pkgxdev/pantry's recipe was NOT opened: that tree carries no licence
# (go-zpkg/packages#431), so `consulted` is empty on purpose.

summary = "bzip2: the Burrows-Wheeler block-sorting compressor, and libbz2"

# Read from LICENSE, which is the four-condition bzip2 licence — clause 2 "the
# origin of this software must not be misrepresented" and clause 3 "altered
# source versions must be plainly marked", which are what distinguish it from
# any BSD text. SPDX names this text `bzip2-1.0.6`, after the release in which
# it settled rather than the release that ships it; LICENSE:40 here is signed
# "bzip2/libbzip2 version 1.0.8 of 13 July 2019" and the wording is unchanged.
license = "bzip2-1.0.6"

versions {
  url   = "https://sourceware.org/pub/bzip2/"
  match = "/bzip2-\\d+\\.\\d+\\.\\d+\\.tar\\.gz/"
  strip = [
    "/^bzip2-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  url              = "https://sourceware.org/pub/bzip2/bzip2-{{version.raw}}.tar.gz"
  strip-components = 1

  # ⭐⭐ SIGNATURE-VERIFIED, AND THE TRUST ANCHOR IS A FILENAME. Recorded with:
  #
  #   zpkb sourcepin \
  #     --sig https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz.sig \
  #     --key ./gpgkey-5C1D1AA44BE649DE760A.gpg \
  #     --key-source "https://sourceware.org/pub/bzip2/gpgkey-5C1D1AA44BE649DE760A.gpg, fetched 2026-11-17" \
  #     --fingerprint "EC3C FE88 F6CA 0788 774F 5C1D 1AA4 4BE6 49DE 760A" \
  #     --version 1.0.8 https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
  #
  # 810029 bytes, signed by EC3CFE88F6CA0788774F5C1D1AA44BE649DE760A,
  # `Mark Wielaard <mark@klomp.org>`, verified with NO keyserver asked.
  #
  # ⭐ WHERE THE FINGERPRINT CAME FROM IS THE INTERESTING PART, and it is not
  # prose: the key is published in the download directory as
  # `gpgkey-5C1D1AA44BE649DE760A.gpg`, and the FILENAME carries the last twenty
  # hex characters — eighty bits — of the fingerprint. The signing key's
  # fingerprint ends `…5C1D1AA44BE649DE760A`, so the published name BINDS the
  # file to the key it is supposed to hold. That is weaker than openssl.org,
  # where the full fingerprint is published in a sentence that also names the
  # primary as the trust anchor, and far stronger than facebook.com/zstd
  # (#146), where a signature is published with no anchor at all.
  #
  # ⚠ The honest limit, the same one gnu.org/gzip records: the key is served by
  # the SAME host as the tarball. That establishes continuity, not independence
  # — a host serving different bytes could serve a matching key — and it is
  # still strictly more than a digest alone, because the signature is over the
  # archive and the key file is a published, dated, widely-mirrored artefact.
  sha256 = {
    "1.0.8" = "ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269"
  }

  # ⭐ A THIRD PATH AGREES, and this one is upstream's own statement about the
  # bytes rather than another fetch of them: https://sourceware.org/pub/bzip2/
  # publishes `sha512.sum`, whose line for this archive is
  # 083f5e675d73f3233c7930ebe20425a533feedeaaa9d8cc86831312a6581cefb…
  # and a local `shasum -a 512` of the downloaded file reproduces it exactly.
  # ⚠ Same host again, so it does not break the common cause either; the
  # signature is what does.
  #
  # The signature URL is not a recipe field (`sig` is read by nothing,
  # go-zpkg/zpkb#282; `sha` means "where the expected SHA-256 is PUBLISHED" and
  # a .sig there fails the build):
  #   https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz.sig
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  script = [
    # ⛔⛔ `CC` IS ASSIGNED UNCONDITIONALLY IN BOTH MAKEFILES AND MUST BE
    # OVERRIDDEN ON THE COMMAND LINE. Makefile:18 is `CC=gcc` and
    # Makefile-libbz2_so:25 is `CC=gcc` — plain assignments, not `?=`, so the
    # ENVIRONMENT DOES NOT WIN: exporting CC changes nothing and the build would
    # silently use whatever `gcc` is on PATH, or fail where there is none. A
    # make COMMAND-LINE assignment does override a makefile one, which is why
    # `CC="$CC"` is written on every line below rather than in `env`.
    #
    # ⭐ Same family as gnu.org/mpc, where the fix was `CC="$${CC:-cc}"` on the
    # configure line (go-zpkg/recipes#137) — a project deciding the compiler for
    # us. There the default was conditional and here it is not, which makes this
    # one worse: nothing in the file leaves room for the caller.
    #
    # ⚠ AND `CFLAGS` IS DELIBERATELY NOT PASSED. Makefile-libbz2_so:27 is
    # `CFLAGS=-fpic -fPIC -Wall -Winline -O2 -g $(BIGFILES)`, also a plain
    # assignment — so a command-line `CFLAGS=` would REPLACE it and drop
    # `-fPIC`, producing a shared library that fails to link on any
    # position-independent target. Overriding CC is necessary; overriding CFLAGS
    # here would be a defect.
    #
    # The default target is `all: libbz2.a bzip2 bzip2recover test`
    # (Makefile:38), so this line also runs bzip2's own self-test over the
    # sample files it ships.
    "make --jobs {{ hw.concurrency }} CC=\"$CC\"",

    # ⛔⛔ THE SHARED LIBRARY IS A SECOND MAKEFILE WITH NO INSTALL TARGET.
    # `make install` installs `libbz2.a` and nothing else (Makefile:90), so a
    # recipe that stopped at the line above would publish a STATIC-ONLY
    # artifact — and the 15 recipes that name this project expect to link
    # `-lbz2`. Makefile-libbz2_so builds `libbz2.so.1.0.8` with soname
    # `libbz2.so.1.0` (:38) and has only `all` and `clean` (:37, :43).
    "make -f Makefile-libbz2_so --jobs {{ hw.concurrency }} CC=\"$CC\"",

    "make install PREFIX={{prefix}} CC=\"$CC\"",

    # The shared library, installed by hand because upstream installs none.
    "install -m 755 libbz2.so.1.0.8 {{prefix}}/lib/libbz2.so.1.0.8",

    # ⛔ AND THE DEVELOPMENT SYMLINK, WITHOUT WHICH `-lbz2` FINDS NOTHING. The
    # linker looks for `libbz2.so`; the loader looks for the soname
    # `libbz2.so.1.0`. Upstream's own `ln -s libbz2.so.1.0.8 libbz2.so.1.0`
    # (Makefile-libbz2_so:41) is made in the BUILD directory and never
    # installed, so both links are created here. RELATIVE, so the chain survives
    # a relocated store.
    "ln -sf libbz2.so.1.0.8 {{prefix}}/lib/libbz2.so.1.0",
    "ln -sf libbz2.so.1.0 {{prefix}}/lib/libbz2.so",

    # ⛔⛔ THE FOUR SCRIPT ALIASES ARE INSTALLED AS ABSOLUTE SYMLINKS, and an
    # absolute link into the build-time prefix is the one thing a relocatable
    # store cannot carry. Makefile:93-100:
    #
    #     ln -s -f $(PREFIX)/bin/bzgrep $(PREFIX)/bin/bzegrep
    #     ln -s -f $(PREFIX)/bin/bzgrep $(PREFIX)/bin/bzfgrep
    #     ln -s -f $(PREFIX)/bin/bzmore $(PREFIX)/bin/bzless
    #     ln -s -f $(PREFIX)/bin/bzdiff $(PREFIX)/bin/bzcmp
    #
    # `$(PREFIX)` is our store path, so each link points at an absolute location
    # that is correct only while the store stays where it was built. They are
    # remade relative here — the same property `zpkvenv seal` relies on for a
    # venv's interpreter, "so a relocated store needs no repair at all".
    #
    # ⚠ These four are NOT in `provides` (see below); they are repaired anyway,
    # because a dangling symlink in a published artifact is a defect whether or
    # not anything promised it.
    "ln -sf bzgrep {{prefix}}/bin/bzegrep",
    "ln -sf bzgrep {{prefix}}/bin/bzfgrep",
    "ln -sf bzmore {{prefix}}/bin/bzless",
    "ln -sf bzdiff {{prefix}}/bin/bzcmp",
  ]
}

# ⛔⛔ FOUR NAMES, NOT ELEVEN, AND THIS ONE WAS MEASURED BY A LANE RATHER THAN
# ARGUED. go-zpkg/packages#310 ran the published bottle on a scratch rootfs
# (linux/s390x, packages run 37279391375):
#
#     ✅ OK sourceware.org/bzip2 1.0.8 linux/s390x
#     /pkgx/sourceware.org/bzip2/v1.0.8/bin/bzegrep: line 63: egrep: command not found
#     FAIL sourceware.org/bzip2 1.0.8: exit status 127
#
# The build succeeded and the test failed, because the thing the recipe said it
# provided did not work. Eleven `provides`, no dependencies at all, and SEVEN of
# the eleven are shell scripts calling `grep`, `egrep`, `fgrep`, `sed`, `more`,
# `less`, `diff` and `cmp` — none of them declared, none of them present in an
# empty image.
#
# ⭐ The four below are the compiled binaries, which go-zpkg/packages#310 names as the four
# that work. `bunzip2` and `bzcat` are not symlinks here: Makefile:79-80 is
# `cp -f bzip2 …`, three COPIES of one program that reads argv[0].
#
# go-zpkg/packages#310 left the choice open between declaring the tools, dropping the scripts
# from `provides`, and leaving it. This tree has since answered it three times
# — tukaani.org/xz, openssl.org (#145), facebook.com/zstd (#146) — always by
# keeping the files in the artifact and out of `provides`. This is the fourth,
# and the convention is now filed as a check in go-zpkg/zpkb#500 so the fifth
# recipe does not have to remember it.
provides = [
  "bin/bzip2",
  "bin/bunzip2",
  "bin/bzcat",
  "bin/bzip2recover",
]

test {
  script = [
    "test -f \"{{prefix}}/include/bzlib.h\"",

    # ⛔ BOTH LIBRARIES, because `make install` alone would have given only the
    # static one and the failure would be a consumer's, not ours.
    {
      run = <<EOT
test -f "{{prefix}}/lib/libbz2.a"
test -f "{{prefix}}/lib/libbz2.so.1.0.8"
EOT
    },

    # ⛔⛔ THE DEVELOPMENT SYMLINK CHAIN, RESOLVED. `test -L` would pass on a
    # DANGLING link; `test -f` follows it, so this fails if either hop is
    # broken — which is what an absolute link into a moved store looks like.
    {
      run = <<EOT
test -f "{{prefix}}/lib/libbz2.so"
test -f "{{prefix}}/lib/libbz2.so.1.0"
EOT
    },

    # ⛔ AND THE FOUR REPAIRED ALIASES RESOLVE TOO. If the relinking above is
    # ever dropped, these stay absolute and keep working on the build machine
    # while dangling everywhere else — a defect that cannot be seen from the
    # host that produced it.
    {
      run = <<EOT
for a in bzegrep bzfgrep bzless bzcmp; do
  test -f "{{prefix}}/bin/$a" || { echo "$a does not resolve" >&2; exit 1; }
done
EOT
    },

    # A round trip through the installed binaries: compress with one name,
    # decompress with another, compare the bytes back.
    {
      run = <<EOT
printf 'the quick brown fox jumps over the lazy dog\n' > rt.txt
"{{prefix}}/bin/bzip2" -c rt.txt > rt.bz2
"{{prefix}}/bin/bunzip2" -c rt.bz2 > rt.out
cmp rt.txt rt.out
"{{prefix}}/bin/bzcat" rt.bz2 > rt.cat
cmp rt.txt rt.cat
EOT
    },

    # ⛔ IT HAS TO LINK, which is what 15 recipes actually want from this
    # project. Compiling against the header and linking -lbz2 exercises the
    # development symlink, the soname and the library in one step.
    {
      run = <<EOT
cat > conftest.c <<'SRC'
#include <bzlib.h>
#include <string.h>
#include <stdio.h>
int main(void)
{
  char in[64] = "bzip2 round trip", out[256], back[64];
  unsigned int olen = sizeof out, blen = sizeof back;
  if (BZ2_bzBuffToBuffCompress(out, &olen, in, (unsigned int)strlen(in) + 1, 9, 0, 30) != BZ_OK)
    return 1;
  if (BZ2_bzBuffToBuffDecompress(back, &blen, out, olen, 0, 0) != BZ_OK)
    return 2;
  return strcmp(in, back) == 0 ? 0 : 3;
}
SRC
"$CC" conftest.c -I"{{prefix}}/include" -L"{{prefix}}/lib" -lbz2 -o conftest
./conftest
EOT
    },
  ]
}

provenance {
  read = [
    "LICENSE",             # the four conditions; :40 "version 1.0.8 of 13 July 2019"
    "Makefile",            # :18 CC=gcc unconditional; :27 PREFIX=/usr/local; :38 the default target runs `test`; :72-109 what install copies, including :79-80 bunzip2/bzcat as COPIES and :93-100 the four ABSOLUTE symlinks; :90 libbz2.a is the only library installed
    "Makefile-libbz2_so",  # :25 CC=gcc again; :27 CFLAGS carries -fPIC and must not be overridden; :37-41 builds libbz2.so.1.0.8 with soname libbz2.so.1.0 and has NO install target
    "README",              # the build instructions this recipe follows
  ]

  consulted = []

  note = <<EOT
⭐ THE `provides` LIST IS THE WHOLE POINT OF THIS RECIPE, and it is the first in
this tree whose shape was decided by a LANE rather than by reading.
go-zpkg/packages#310 ran the published bottle on a scratch rootfs and got
`bzegrep: line 63: egrep: command not found` — a green build and a red test,
because seven of eleven `provides` were shell scripts calling programs nothing
declared. Four names here, the compiled binaries, which go-zpkg/packages#310
names as the four that work.

⛔⛔ THREE DEFECTS THAT WOULD NOT HAVE FAILED THE BUILD:

  1. `CC=gcc` is a PLAIN assignment in both makefiles (Makefile:18,
     Makefile-libbz2_so:25). Exporting CC changes nothing; only a make
     command-line assignment wins. Left alone, the build takes whatever `gcc` is
     on PATH — the host's, in a sandbox that staged clang — and succeeds.
  2. `make install` installs `libbz2.a` AND NOTHING ELSE. The shared library is
     a separate makefile with no install target, so the obvious recipe publishes
     a static-only artifact; the fifteen consumers that link `-lbz2` discover it
     one at a time. The `libbz2.so` and `libbz2.so.1.0` links are created here
     because upstream makes them in the build directory and never installs them.
  3. The four script aliases are installed as ABSOLUTE symlinks into
     `$(PREFIX)` (Makefile:93-100). They resolve perfectly on the machine that
     built them and dangle in a relocated store — the failure a build host
     structurally cannot see. Remade relative, and the test resolves them with
     `test -f` rather than `test -L`, because `-L` passes on a dangling link.

⚠ AND ONE THING DELIBERATELY NOT OVERRIDDEN: CFLAGS. Makefile-libbz2_so:27 is a
plain assignment carrying `-fpic -fPIC`, so passing CFLAGS on the make line
would REPLACE it and drop position independence. Overriding CC is necessary and
overriding CFLAGS would be the defect — the same mechanism, opposite verdict,
which is why both are written down.

⭐ THE SIGNATURE'S ANCHOR IS A FILENAME, which is new for this tree. The key is
published beside the tarballs as `gpgkey-5C1D1AA44BE649DE760A.gpg`, and those
twenty hex characters are the last eighty bits of the fingerprint of the key
that signed the archive. A published name binding a published file to a
published key is a real anchor, weaker than openssl.org's sentence naming the
primary as the trust anchor and far stronger than facebook.com/zstd's signature
with no anchor at all. ⚠ Same host as the tarball, so continuity rather than
independence — the limit gnu.org/gzip already records.

⚠ NOT BUILT. Measured here: the digest by three paths (the builder's fetcher, a
local shasum, and upstream's published sha512.sum), the signature against the
published key with the fingerprint named, the version enumeration, the switch
census against the project's own makefiles, and `zpkb lint`. The scripts are a
claim about bzip2's build system read from that build system, and they stay a
claim until a factory runs them.
EOT
}
