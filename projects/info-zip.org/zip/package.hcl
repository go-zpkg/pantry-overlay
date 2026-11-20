# info-zip.org/zip — Info-ZIP's Zip: zip, zipcloak, zipnote and zipsplit.
#
# ⛔ WRITTEN FROM ZIP'S OWN FILES (go-zpkg/packages#431), at 3.0 — the last
# release (July 2008; Info-ZIP has published nothing since) — with Debian's patch
# set 3.0-16 applied on top. Second recipe on go-zpkg/zpkb v0.92.0's `sources`
# (go-zpkg/zpkb#518), after curl.se/ca-certs's `extract = false`.
#
# ⛔ THE DEFECTS OF THE RECIPE THIS REPLACES (pkgxdev/pantry, consulted for facts):
#   - it fetched Debian's patches INSIDE THE BUILD SCRIPT with `wget`, no digest,
#     from `zip_3.0-11.debian.tar.xz`, a file deb.debian.org no longer serves
#     (404, measured 2026-11-20: the pool keeps 3.0-12, -13, -15+deb13u1 and -16).
#     That recipe cannot build today;
#   - 3.0-11's set predates FIVE fixes (the gcc 14 build, two buffer overflows,
#     symlink updates and a command injection reachable through an archive's
#     name — see the patches below; the injection's fix is dated 2026);
#   - `dependencies: sourceware.org/bzip2` was a RUNTIME dependency for a binary
#     that links libbz2 STATICALLY (see the build), so every consumer paid for it;
#   - gnu.org/wget was a build dependency only to fetch those patches.

summary = "Info-ZIP Zip: create and modify ZIP archives (zip, zipcloak, zipnote, zipsplit)"

# LICENSE:1 "version 2007-Mar-4 of the Info-ZIP license", a BSD-style licence
# with four conditions; SPDX names it `Info-ZIP`. Condition 2 (LICENSE:34-40)
# requires binary redistributions to reproduce the licence "in documentation
# and/or other materials", which is why the build installs it.
license = "Info-ZIP"

# Info-ZIP's Zip is frozen: 3.0 is "Zip 3.x (latest)" on the SourceForge file
# list and nothing newer exists, so there is nothing to enumerate.
versions = ["3.0"]

distributable {
  # SourceForge, as upstream's recipe has it ("Zip 3.x (latest)", version 3.0,
  # file zip30.tar.gz).
  url              = "https://downloads.sourceforge.net/project/infozip/Zip%203.x%20%28latest%29/{{version.marketing}}/zip{{version.major}}{{version.minor}}.tar.gz"
  strip-components = 1

  # 1118845 bytes. ⭐ A SECOND, UNRELATED HOST SERVES THE SAME BYTES: Debian's
  # pool and snapshot archive hold `zip_3.0.orig.tar.gz` (first seen 2009-04-11)
  # with this very SHA-256, and Debian's signed .dsc names it (see the note). It is
  # not listed as a fallback mirror: the list form is a separate shape of
  # `distributable` and one URL is what upstream's recipe uses.
  #
  # ⚠ NOT SIGNED BY UPSTREAM: no Info-ZIP signature for zip30.tar.gz was looked
  # for beyond the project's SourceForge download link and none is used. What
  # vouches for the bytes is Debian's maintainer, below.
  sha256 = {
    "3.0" = "f0e8bb1f9b7eb0b01285495a2699df3a4b766784c1765a8f1aeedf63c0806369"
  }
}

# ⭐ DEBIAN'S PATCH SET, pinned and fetched by the builder, not by the script.
# The snapshot URL is IMMUTABLE (the archive is addressed by the instant the file
# first appeared, 2026-08-07T20:20:35Z, found through
# https://snapshot.debian.org/mr/package/zip/3.0-16/srcfiles?fileinfo=1) where the
# pool's file disappears when 3.0-17 is uploaded, as 3.0-11 did. It unpacks to
# `debian/patches/*.patch` and `debian/patches/series`.
#
# 12512 bytes. Debian's signed `zip_3.0-16.dsc` lists this SHA-256 on its
# `Checksums-Sha256` line, so the pin is the maintainer's own statement.
sources = [
  {
    url                = "https://snapshot.debian.org/archive/debian/20260807T202035Z/pool/main/z/zip/zip_3.0-16.debian.tar.xz"
    sha256             = { "3.0" = "fa79a0226f00f487b290489f62e1cd7f4a338df529a1e413fea4d168b8eee8f7" }
    dest               = "debian"
    "strip-components" = 1
  },
]

build {
  dependencies = {
    "gnu.org/gcc"         = "*"
    "gnu.org/make"        = "*"
    "gnu.org/patch"       = "*"
    "sourceware.org/bzip2" = "*"
  }

  script = [
    # ⛔⛔ THE PATCHES, TEN OF SEVENTEEN, in the order of debian/patches/series
    # (they apply in that order: 13410 rewrites the allocation that the command
    # injection fix then rewrites again). Each is judged from its OWN header.
    #
    # APPLIED
    #
    # stack-markings-to-avoid-executable-stack — Kees Cook, Debian #528280:
    # "put stack markings in i386 assembly to avoid executable stack". It adds
    # `.section .note.GNU-stack` to crc_i386.S and match.S, the two assembler
    # files; without it an i386 link marks the stack executable. ⚠ ONLY i386
    # ASSEMBLES THEM: match.S is written for i386 and m68k (match.S:59, :184), and
    # measured on x86_64 and aarch64 (gcc 14.4, the `flags` line says `OBJA=""`,
    # unix/configure:236-258) neither file is built. The patch is still applied because
    # it is the fix for the 32-bit ELF target and costs nothing elsewhere; the test
    # reads GNU_STACK off the binary rather than trusting this paragraph.
    "patch -p1 < debian/patches/stack-markings-to-avoid-executable-stack.patch",

    # fclose-in-file-not-fclose-x — Christian Spieler, Debian #628594: zipnote.c
    # closed `x`, "undefined file", instead of `in_file`. A real defect (the
    # wrong stream closed), in the one-line change that touches no behaviour else.
    "patch -p1 < debian/patches/fclose-in-file-not-fclose-x.patch",

    # hardening-build-fix-1 — Santiago Vila, Debian #673476: `printf(text[i])`
    # becomes `printf("%s", text[i])` at zip.c:1028 and :1225. A format string
    # that is data; the build breaks under -Werror=format-security.
    "patch -p1 < debian/patches/hardening-build-fix-1.patch",

    # hardening-build-fix-2 — same bug: unix/configure's `LFLAGS1=''` becomes
    # `LFLAGS1=${LDFLAGS}`, so the linker flags the caller states reach the link
    # line. Without it the LDFLAGS below would be silently dropped.
    "patch -p1 < debian/patches/hardening-build-fix-2.patch",

    # remove-build-date — Santiago Vila, Debian #779042: "Remove (optional) build
    # date to make the build reproducible". unix/unix.c:1022 tests __DATE__, which
    # `zip -v` prints as "Compiled with gcc … on <date>". The test asserts the date
    # is gone.
    "patch -p1 < debian/patches/remove-build-date.patch",

    # fix-build-with-gcc-14 — Debian #1075706. ⛔ WITHOUT IT THE BUILD DOES NOT
    # COMPILE. unix/configure probes by compiling `memset(&k,0,0)`,
    # `closedir(opendir("."))`, `errno = 0` and `rmdir()` WITHOUT their headers;
    # gcc 14 makes an implicit declaration an error, so the probes FAIL and
    # configure answers "missing": -DZMEM (zip's own memset, memcpy and memcmp),
    # -DNO_RMDIR, -DNO_ERRNO, -DNO_VALLOC and -DNO_DIR. MEASURED in gcc:14 (14.4.0),
    # this patch left out and everything else as here: zip.h:726-728 "conflicting
    # types for 'memset'", 'memcpy' and 'memcmp', `make: *** [generic] Error 2`.
    # The patch stops asking on glibc and pins the answers "present", which is
    # right for every target this tree builds (glibc, and darwin whose libc has
    # all of them; the patched tree was also built with Apple clang 21).
    "patch -p1 < debian/patches/fix-build-with-gcc-14.patch",

    # buffer-overflow-unicode-filename — Shengjing Zhu, Debian #1077054/#1093629:
    # fileio.c:3505 `mbstowcs(wc_string, local_string, strlen(local_string) + 1)`
    # allowed more wide characters than the `wsize + 1` buffer holds; a file name
    # with multi-byte characters overflowed the heap. Forwarded upstream
    # (infozip bugs/81).
    "patch -p1 < debian/patches/buffer-overflow-unicode-filename.patch",

    # buffer-overflow-cve-2018-13410 — Florent Jacquet, Debian #1093629: the `-T
    # -TT` command buffer was one byte short (`+ 3` for " ", "'", "'" and NUL is
    # four). CVE-2018-13410, which Debian rates negligible (the attacker would
    # control the -TT value) and which is one character.
    "patch -p1 < debian/patches/buffer-overflow-cve-2018-13410.patch",

    # fix-symlink-update-detection — Marcin Owsiany, Debian #1005943:
    # unix/unix.c:426 gave a symlink's size as -1, so an updated symlink was never
    # detected as changed. SYMLINK_SUPPORT is on (see `zip -v`), so this is a
    # behaviour a user can meet with `zip -u`.
    "patch -p1 < debian/patches/fix-symlink-update-detection.patch",

    # fix-command-injection — Paul Marquess, Debian #1143866, reported upstream by
    # Harry Sintonen: `zip -T archive.zip` with nothing to add (zip.c:4697-4699)
    # builds `unzip -t '<archive name>'` for system(), quoting with single quotes
    # only, so an archive name containing a quote breaks out of them. (When files
    # are being added the tested name is zip's own temporary file, zip.c:5924, which
    # is why this needs an EXISTING hostile name.) quote_arg() escapes `"`, `$`,
    # `` ` `` and `\` and wraps the name in double quotes. The test tests an
    # archive named `x';touch pwned;'.zip` and requires that no file `pwned`
    # appears.
    "patch -p1 < debian/patches/fix-command-injection.patch",

    # SKIPPED, and why — SEVEN, of which five are documentation text:
    #
    #   typo-it-is-transferring-not-transfering      man/zip.1 and zip.txt only
    #   typo-it-is-privileges-not-priviliges         man/zip.1 and zip.txt only
    #   typo-it-is-preceding-not-preceeding          man/zip.1 and zip.txt only
    #   typo-it-is-ambiguities-not-amgibuities       man/zip.1 and zip.txt only
    #   typo-it-is-os-2-not-risc-os-2                man/zip.1 and zip.txt only
    #       each corrects one word of the manual. Nothing runs differently, no
    #       header names a defect, and every hunk applied is a hunk this recipe
    #       must keep applying as the series moves. The page is installed as
    #       upstream wrote it. (Cheap to add if the owner wants the typos fixed.)
    #   manpages-in-section-1-not-in-section-1l      man/zip.1 headers `1L` → `1`
    #       the page installs to man/man1/zip.1 (unix/Makefile:44, MANEXT=1) either
    #       way; only the title line's section label differs.
    #   do-not-set-unwanted-cflags                   unix/configure:101
    #       comments out `CFLAGS_OPT='-O3'` "as it breaks DEB_BUILD_OPTIONS". That
    #       is Debian handing optimisation to its packaging; applied here it would
    #       leave the build UNOPTIMISED (no -O at all) unless a LOCAL_ZIP carried
    #       one. Unpatched, configure's own GNU C branch (:100-102) chooses -O3,
    #       which `flags` shows and the build measured.
    #
    # ⛔ BZIP2 IS DECLARED, AND LINKED STATICALLY, because that is the ONLY way Zip
    # links it: bzip2/install.txt:70-72 "Zip on UNIX uses the "bzlib.h" include
    # file and the compiled "libbz2.a" library to static link to bzip2. Currently
    # we do not support using the shared library". bzip2/install.txt:74-99: drop
    # both files in the source tree's bzip2/ directory and `generic` finds them.
    # sourceware.org/bzip2's recipe installs both (include/bzlib.h, lib/libbz2.a).
    #
    # ⚠ AND CONFIGURE FALLS BACK TO NO BZIP2 IN SILENCE when either file is
    # missing (unix/configure:129-217: every branch ends "no bzip2" with an echo
    # and no error), which is why the test asserts BZIP2_SUPPORT in `zip -v` and
    # a bzip2 entry in a real archive. No `bzip2` is needed at RUN time: nothing
    # is declared in `dependencies`.
    "cp \"{{deps.sourceware.org/bzip2.prefix}}/include/bzlib.h\" \"{{deps.sourceware.org/bzip2.prefix}}/lib/libbz2.a\" bzip2/",

    # ⛔ `CC` NAMED. unix/Makefile:25 is `CC = cc`, a plain assignment, so the
    # environment does not win; and `generic` hands CC to unix/configure
    # (Makefile:179-180) which hands it back in the `flags` file (configure:689),
    # so one command-line `CC=` reaches the probes AND the build. Without it the
    # build takes whatever `cc` is on PATH.
    #
    # ⛔ AUTO-DETECTION, NAMED RATHER THAN REFUSED: unix/configure is ~25 probes
    # that choose flags for the PLATFORM (Large File Support :406-450, Unicode
    # :456-488, UID size :346-399, directory header :589-597, terminal I/O
    # :609-617). They are what "make generic" is documented to do (INSTALL:56-67)
    # and they pick no external library. The one that does — bzip2 — is stated
    # above, and the test reads its outcome (zip -v) instead of assuming it.
    # What the probes chose is printed by `cat flags` below.
    {
      run = <<EOT
set -eu
# Linux only: darwin's linker has no -z. noexecstack is what the first patch is
# for on i386 and defence in depth elsewhere; relro and now make the GOT read-only.
if [ "$(uname -s)" = Linux ]; then
  export LDFLAGS="-Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack"
fi
make -f unix/Makefile generic CC="$CC"
cat flags
EOT
    },

    # `install` depends on the four programs, which exist, so nothing is rebuilt.
    # unix/Makefile:40-44 default prefix /usr/local, :157-171 install.
    "make -f unix/Makefile install prefix=\"{{prefix}}\" MANDIR=\"{{prefix}}/man/man1\" CC=\"$CC\"",

    # LICENSE condition 2: binary redistributions reproduce the licence.
    "mkdir -p \"{{prefix}}/share/doc/zip\"",
    "cp LICENSE \"{{prefix}}/share/doc/zip/LICENSE\"",
  ]
}

# unix/Makefile:122 `ZIPS = zip$E zipcloak$E zipnote$E zipsplit$E`: four compiled
# programs, no scripts.
provides = [
  "bin/zip",
  "bin/zipcloak",
  "bin/zipnote",
  "bin/zipsplit",
]

test {
  dependencies = {
    # `python3 -m zipfile` is an INDEPENDENT reader of what zip wrote: `zip -T`
    # shells out to unzip, which this tree does not have, and a program that
    # checks its own output with its own code proves less.
    "python.org"     = "*"
    # readelf, for the ELF checks (run on Linux only).
    "gnu.org/binutils" = "*"
  }

  script = [
    "test -f \"{{prefix}}/share/doc/zip/LICENSE\"",
    "test -f \"{{prefix}}/man/man1/zip.1\"",

    # ⛔ THE FEATURE SET, read from the binary's own report. BZIP2_SUPPORT is the
    # one configure can drop in silence; ZIP64 and LARGE_FILE are probes; and a
    # build date after "Compiled with" would mean the reproducibility patch did
    # not apply.
    {
      run = <<EOT
set -eu
"{{prefix}}/bin/zip" -v > v.txt
cat v.txt
grep -q '^This is Zip 3.0 ' v.txt
for want in BZIP2_SUPPORT ZIP64_SUPPORT LARGE_FILE_SUPPORT UNICODE_SUPPORT SYMLINK_SUPPORT; do
  grep -qw "$want" v.txt || { echo "zip -v does not list $want" >&2; exit 1; }
done
if grep -q '^Compiled with .* on ' v.txt; then echo "zip -v carries a build date" >&2; exit 1; fi
EOT
    },

    # ⛔ AN ARCHIVE, WRITTEN AND READ BACK BY ANOTHER IMPLEMENTATION. A tree with a
    # subdirectory (-DNO_DIR would drop it), a compressible file, once deflated
    # and once bzip2'd; python's zipfile tests every CRC, extracts, and reports
    # the compression METHOD of each entry, so "bzip2 is linked" is a fact about
    # the archive and not about a flag.
    {
      run = <<EOT
set -eu
Z="{{prefix}}/bin/zip"
mkdir -p t/d/sub
printf 'alpha\n' > t/d/a.txt
printf 'bravo\n' > t/d/sub/b.txt
head -c 200000 /dev/zero | tr '\0' 'x' > t/d/sub/big.txt
(cd t && "$Z" -q -r deflate.zip d)
(cd t && "$Z" -q -r -Z bzip2 bzip2.zip d)
"$Z" -sf t/deflate.zip > t/list.txt
for want in d/a.txt d/sub/b.txt d/sub/big.txt; do
  grep -qx "  $want" t/list.txt || { cat t/list.txt >&2; echo "zip -r lost $want" >&2; exit 1; }
done
"{{deps.python.org.prefix}}/bin/python3" - <<'PY'
import filecmp, zipfile
for name, method in (("deflate.zip", zipfile.ZIP_DEFLATED), ("bzip2.zip", zipfile.ZIP_BZIP2)):
    z = zipfile.ZipFile("t/" + name)
    assert z.testzip() is None, name
    got = {i.filename: i.compress_type for i in z.infolist() if not i.is_dir()}
    assert set(got) == {"d/a.txt", "d/sub/b.txt", "d/sub/big.txt"}, got
    # the 200000-byte file is the one a method applies to; tiny ones may be stored
    assert got["d/sub/big.txt"] == method, (name, got)
    z.extractall("t/x-" + name)
    for rel in got:
        assert filecmp.cmp("t/d/" + rel[2:], "t/x-" + name + "/" + rel, shallow=False), rel
print("zip archives read back")
PY
EOT
    },

    # The other three programs, through the archive just made.
    {
      run = <<EOT
set -eu
B="{{prefix}}/bin"
"$B/zipnote" t/deflate.zip > t/notes.txt
grep -qx '@ d/a.txt' t/notes.txt
"$B/zipcloak" -h > /dev/null
"$B/zipsplit" -h > /dev/null
EOT
    },

    # ⛔ THE COMMAND-INJECTION FIX, asserted on its property. The archive is made
    # first, with a NAME that carries a quote; `zip -T` on it, with nothing to add,
    # then runs the test command on that name. `-TT true` names the test command, so
    # no unzip is needed. The old single-quote wrapping let the name out of its
    # quotes and ran `touch pwned` (measured: the same build with this patch left
    # out creates the file).
    {
      run = <<EOT
set -eu
mkdir -p inj && cd inj
printf 'x\n' > f.txt
"{{prefix}}/bin/zip" -q "x';touch pwned;'.zip" f.txt
test -f "x';touch pwned;'.zip"
"{{prefix}}/bin/zip" -T -TT true "x';touch pwned;'.zip"
if [ -e pwned ]; then echo "an archive name ran a command" >&2; exit 1; fi
EOT
    },

    # ⛔ THE ELF PROPERTIES, Linux only. GNU_STACK must say RW and not RWE (an
    # executable stack); GNU_RELRO is there when hardening-build-fix-2 carried the
    # LDFLAGS to the link; and libbz2 must not be NEEDED, because it is linked in.
    {
      run = <<EOT
set -eu
if [ "$(uname -s)" = Linux ]; then
  for p in zip zipcloak zipnote zipsplit; do
    readelf -lW "{{prefix}}/bin/$p" > seg.txt
    grep -q 'GNU_STACK' seg.txt || { echo "$p has no GNU_STACK header" >&2; exit 1; }
    if grep 'GNU_STACK' seg.txt | grep -q 'RWE'; then echo "$p has an executable stack" >&2; exit 1; fi
    grep -q 'GNU_RELRO' seg.txt || { echo "$p has no RELRO" >&2; exit 1; }
  done
  if readelf -d "{{prefix}}/bin/zip" | grep -q 'NEEDED.*libbz2'; then echo "zip links libbz2 dynamically" >&2; exit 1; fi
fi
EOT
    },
  ]
}

provenance {
  read = [
    "unix/Makefile",       # :24-27 CC plain assignment; :40-44 prefix, BINDIR, MANDIR; :60-63 CFLAGS and LFLAGS; :122 ZIPS, four programs; :157-171 install; :179-180 `flags` runs configure with CC; :201-202 generic
    "unix/configure",      # :25 CFLAGS_OPT; :100-102 GNU C → -O3; :129-217 bzip2 detection, every branch ending in "no bzip2" without an error; :238-258 the i386 assembler; :346-488 the platform probes; :512-554 the probes gcc 14 breaks; :689-694 the `flags` file
    "INSTALL",             # :49-67 `make -f unix/Makefile generic`, which "should work on most systems"; :75-79 bzip2
    "bzip2/install.txt",   # :70-72 static link only, no shared library; :74-99 the bzip2/ directory; :142-149 verify with `zip -v`
    "LICENSE",             # :1 version 2007-Mar-4 of the Info-ZIP licence; :34-40 condition 2, binary redistributions
    "https://snapshot.debian.org/archive/debian/20260807T202035Z/pool/main/z/zip/zip_3.0-16.debian.tar.xz",   # debian/changelog 3.0-16 .. 3.0-9; the series file; the header of each of the seventeen patches
    "https://deb.debian.org/debian/pool/main/z/zip/zip_3.0-16.dsc",                                          # the signed source control file: Checksums-Sha256 of the orig tarball and of the debian tarball
  ]

  consulted = [
    # Read for FACTS only: the SourceForge URL layout, that Debian's patches are
    # wanted, and the defect that the patches are fetched with wget inside the
    # script from a 3.0-11 URL that now answers 404.
    "pkgxdev/pantry projects/info-zip.org/zip/package.yml",
  ]

  note = <<EOT
⭐ SECOND RECIPE ON `sources`: the patch set is a pinned, digest-checked source of
its own, where the pantry's recipe fetched it with `wget` and no digest, from a
file that has since left Debian's pool.

THE WARRANT FOR BOTH DIGESTS IS DEBIAN'S SIGNED .dsc, NOT UPSTREAM:

  file         https://deb.debian.org/debian/pool/main/z/zip/zip_3.0-16.dsc
  signed by    D54C3BFAFFB042DE382DA5D741CE7F0B9F1B8B32 (RSA), 2026-08-07
               Santiago Vila <sanvila@debian.org>, the package's maintainer
  key bytes    https://db.debian.org/fetchkey.cgi?fingerprint=<that fingerprint>,
               Debian's own account database, which answers only for a key it
               holds; the same key (fetched by fingerprint) is at keyserver.ubuntu.com
  checked      `gpg --verify` in an empty home: Good signature, from that key
  covers       Checksums-Sha256:
                 f0e8bb1f… 1118845 zip_3.0.orig.tar.gz
                 fa79a022… 12512   zip_3.0-16.debian.tar.xz
               — the first is byte-identical to SourceForge's zip30.tar.gz (the
               same SHA-256 from two unrelated hosts), the second is `sources`.

⚠ THE LIMITS, stated: this is NOT zpkb sourcepin's check (that verifies a detached
signature over the pinned file; a .dsc is a clearsigned control file that names
the file's hash, so the chain is "signed document → digest → bytes"). The
fingerprint was read off the signature and then confirmed to be registered at
db.debian.org, which is Debian's statement and not an independent one. Info-ZIP
signs nothing, so the tarball's upstream authenticity rests on the Debian
maintainer's statement and on SourceForge and Debian serving the same bytes.

⛔ THE PATCH DECISIONS (ten applied, seven skipped) are in the build script, each
from its own header. The two that change the artifact most are
fix-build-with-gcc-14 (without it a gcc 14 build does not compile) and
fix-command-injection (2026, Debian #1143866). The pantry's 3.0-11 set has
NEITHER, nor the two buffer overflows or the symlink fix.

⚠ MEASURED, in a gcc:14 container (14.4.0) on linux/arm64 AND linux/amd64: the
build as written (all ten patches, bzip2 1.0.8 built from sourceware.org's
tarball, the same bytes sourceware.org/bzip2 builds, LDFLAGS as in the script),
then the test block (its five `run` blocks and the two `test -f` lines), copied
into a script with the prefix substituted and python3 from the image: all pass
on both. Controls, arm64: the
build with fix-build-with-gcc-14 left out FAILS (zip.h conflicting types for
memset); the test with remove-build-date left out FAILS ("carries a build date");
with fix-command-injection left out FAILS (`zip -T` runs `touch pwned`). Also
built with Apple clang 21 on darwin/arm64 (patched, bzip2 static, `zip -v`
lists BZIP2_SUPPORT); the test was not run there. ⛔ NOT BUILT by the factory,
and not built on i386, the only target where the two assembler files are used.
The ELF block asserts GNU_STACK on the binary; it is RW on both architectures
measured with the LDFLAGS in the script, and was not measured without them.
EOT
}
