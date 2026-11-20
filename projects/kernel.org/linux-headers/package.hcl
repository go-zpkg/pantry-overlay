# kernel.org/linux-headers — the sanitised UAPI headers that glibc and every
# other libc compile against, and the floor a FROM-scratch tree stands on.
#
# ⛔ WRITTEN FROM THE KERNEL'S OWN FILES (go-zpkg/packages#431), at 7.2.15.
# Named by go-zpkg/recipes#88 as one of the two that come before the rest
# of the fourteen, because nothing else in the set can be built correctly
# without it. Measured against this overlay alone on 2026-11-16 with
# zpkb v0.81.0, the gap #88 opened at fourteen now stands at NINE:
#
#   closure: 9 project(s) asked for and not read: freedesktop.org/pkg-config
#   gnu.org/autoconf gnu.org/automake gnu.org/bison gnu.org/gcc/libstdcxx
#   gnu.org/glibc gnu.org/libtool gnu.org/texinfo kernel.org/linux-headers
#
# ⚠ go-zpkg/base-toolchain already pins `kernel.org/linux-headers = "~7.2"`, so
# 7.2.x is the line this recipe has to satisfy, and 7.2.15 is its newest.

summary = "Sanitised Linux kernel UAPI headers: linux/*, asm/*, asm-generic/*"

# ⛔ READ FROM COPYING, WHICH NAMES THE EXCEPTION AND NOT ONLY THE LICENCE:
#
#   SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note
#
# and "Being under the terms of the GNU General Public License version 2 ONLY".
# Written here as `GPL-2.0-only` because SPDX deprecated the bare `GPL-2.0` in
# favour of the explicit -only/-or-later pair, and COPYING says which of the two
# this is.
#
# ⭐ AND FOR A HEADERS-ONLY PACKAGE THAT EXCEPTION IS NOT BOILERPLATE — it is
# the whole reason the package may be linked into non-GPL userspace, and it is
# ENFORCED by the project's own installer. scripts/headers_install.sh refuses
# any header whose SPDX line names a GPL variant without it:
#
#   if [ -n "$(sed -n -e "/SPDX-License-Identifier:.*GPL-/{/WITH Linux-syscall-note/!p}" $INFILE)" ]; then
#     echo "error: $INFILE: missing \"WITH Linux-syscall-note\" ..." >&2
#
# So the licence of what this package actually ships is checked file by file by
# the build that produces it, which is a stronger warrant than COPYING alone.
license = "GPL-2.0-only WITH Linux-syscall-note"

# Kernel headers describe a Linux kernel's own ABI; there is no darwin or
# windows artifact to build. Stated rather than left to fail at build time.
platforms = ["linux"]

# ⛔⛔ THREE SOURCES AND NOT ONE, BECAUSE THE PROJECT PUBLISHES ONE INDEX PER
# MAJOR. kernel.org serves /pub/linux/kernel/v5.x/, v6.x/ and v7.x/ as separate
# directory listings; there is no single page that lists them all, so a single
# `url` could only ever enumerate one major. The schema takes an array of
# sources for exactly this (`versions` oneOf → array of versionSource), so the
# three are named instead of one being chosen and the rest silently missing.
#
# ⚠ These are the three majors kernel.org's own releases.json still lists
# supported lines in, read 2026-11-16: 5.10 and 5.15, 6.1/6.6/6.12/6.18, and
# 7.2/7.3. A fourth major needs a line added here — which is a real maintenance
# cost and is preferred to a pattern that pretends to cover directories that do
# not exist yet.
#
# ⭐ NO `-rc` FILTER IS NEEDED, AND THAT IS MEASURED RATHER THAN ASSUMED: the
# release directories hold no release-candidate tarballs at all — the v7.x index
# greps to ZERO occurrences of "rc" — because kernel.org serves candidates from
# git.kernel.org/torvalds/t/ instead, which releases.json confirms by giving
# mainline 7.4-rc3 a git.kernel.org source and every stable line a cdn one. A
# filter written for tags would have been inert here, which is the shape
# go-zpkg/recipes#123 and #125 each found twice.
#
# ⚠ The `.tar.xz` in `match` is load-bearing: each version appears in the index
# three times, as `.tar.gz`, `.tar.sign` and `.tar.xz`.
versions = [
  {
    url   = "https://cdn.kernel.org/pub/linux/kernel/v7.x/"
    match = "/linux-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
    strip = ["/^linux-/", "/\\.tar\\.xz$/"]
  },
  {
    url   = "https://cdn.kernel.org/pub/linux/kernel/v6.x/"
    match = "/linux-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
    strip = ["/^linux-/", "/\\.tar\\.xz$/"]
  },
  {
    url   = "https://cdn.kernel.org/pub/linux/kernel/v5.x/"
    match = "/linux-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
    strip = ["/^linux-/", "/\\.tar\\.xz$/"]
  },
]

distributable {
  # `{{version.major}}` is what makes one url serve all three majors, and it is
  # the same number the directory is named after.
  url              = "https://cdn.kernel.org/pub/linux/kernel/v{{version.major}}.x/linux-{{version.raw}}.tar.xz"
  strip-components = 1

  # Each recorded with the builder's own fetcher —
  #
  #   zpkb sourcepin --version <v> --sig auto --sig-covers decompressed \
  #     --key <gregkh> --fingerprint "647F 2865 …" \
  #     https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-<v>.tar.xz
  #
  # — and each confirmed by a second, independent fetch-and-hash (`curl --fail`
  # + `shasum -a 256`): two paths, one answer, twice. Re-run against zpkb
  # v0.85.0 on 2026-11-19, which is the first release that can verify these
  # signatures at all, and both digests came out unchanged.
  #
  # ⭐ TWO PINS AND NOT ONE, FOR A REASON THE FIRST DRAFT GOT WRONG. 7.2.15 is
  # what go-zpkg/base-toolchain's `~7.2` needs, and pinning only that would have
  # left the recipe BROKEN for everyone else: `versions` resolves 1960 versions
  # across the three majors, so a consumer asking `*` gets the newest — 7.3.4 —
  # and an unpinned version is refused by design (`sha256` makes a recipe
  # fail-closed, which is the structural answer go-zpkg/recipes#123
  # reached). Measured, not assumed: `zpkb versions` lists 7.3.4 first and
  # 7.2.15 sixth. So the newest resolvable version is pinned as well as the one
  # the set asks for, and both are signature-verified below.
  #
  # 7.3.5 added 2026-11-20 (go-zpkg/recipes#208): 7.3.4 was the newest when
  # this was written, and three days later it was not — the default build was
  # a refusal. Verified the same way; the measurement is in provenance.
  sha256 = {
    "7.3.5"  = "8f293f83d54f0b7b9be56863ebc5e4ea79d73e530b4ae55c572be97ef39f0990"
    "7.3.4"  = "b11b6df8295e8e991ff040b71aaa4994a8b55caa23b6b092907f195b5840fd1f"
    "7.2.15" = "d0f6b1d7324c937ccaeb5c4ca7084bfcf71db2edb3e2d3a31f0ad83a681809ab"
  }

  # ⭐⭐ BOTH DIGESTS ARE SIGNATURE-VERIFIED BY THE TOOL, with
  # `--sig-covers decompressed`, because kernel.org signs the UNCOMPRESSED tar.
  # The whole measurement is in `provenance.note` below — both digests, the A/B
  # one flag apart, and the signing instant per version. This comment used to
  # read "THE SIGNATURE IS GOOD AND `zpkb sourcepin --sig` CANNOT SEE IT": that
  # was go-zpkg/zpkb#492, fixed in go-zpkg/zpkb#507, released as v0.85.0.
  #
  # ⚠ ANYTHING OLDER THAN v0.85.0 STILL REFUSES THESE SIGNATURES, and refuses
  # them as `RSA verification failure` — which reads as a bad key rather than as
  # a missing flag. Check what is installed before concluding the archive moved.
}

build {
  dependencies = {
    "gnu.org/make" = "*"

    # ⛔⛔ rsync IS A REAL BUILD DEPENDENCY AND IT IS NOT IN THE BASE TOOLCHAIN.
    # The top-level Makefile:1497-1500 is where headers_install actually copies:
    #
    #   cmd_headers_install = \
    #     mkdir -p $(INSTALL_HDR_PATH); \
    #     rsync -mrl --include='*/' --include='*\.h' --exclude='*' \
    #     usr/include $(INSTALL_HDR_PATH)
    #
    # unqualified on PATH, so it is found or the install fails. Declared because
    # go-zpkg/base-toolchain's 25 members do not include it — checked name by
    # name — which makes this the first base-toolchain member whose own build
    # needs a tool the set does not carry.
    #
    # ⭐ THE ALTERNATIVE WAS CONSIDERED AND REJECTED ON THE EVIDENCE: `make
    # headers` alone leaves the tree in usr/include and one could copy it with
    # coreutils instead. But Makefile.headersinst drives each header through
    # `if_changed`, which writes a `.<name>.h.cmd` file beside it and then
    # `-include`s them — so usr/include holds kbuild bookkeeping as well as
    # headers, and that filter (`--include='*\.h' --exclude='*'`) is precisely
    # what keeps it out of the artifact. Hand-rolling the filter to drop one
    # dependency would put the correctness of the package in a line of this
    # recipe rather than in the project's own target.
    "rsync.samba.org" = "*"
  }

  # ⛔⛔ THE TARGET ARCHITECTURE, STATED, BECAUSE ITS DEFAULT IS THE BUILDER'S.
  #
  # Documentation/kbuild/headers_install.rst: "ARCH indicates which
  # architecture to produce headers for, and defaults to the current
  # architecture." The mechanism is Makefile:407 `ARCH ?= $(SUBARCH)` with
  # SUBARCH from scripts/subarch.include:
  #
  #   SUBARCH := $(shell uname -m | sed -e s/i.86/x86/ -e s/x86_64/x86/ … \
  #                -e s/s390x/s390/ … -e s/aarch64.*/arm64/ …)
  #
  # — literally `uname -m` ON THE MACHINE RUNNING MAKE. The exported
  # linux/asm directory is platform-specific (headers_install.rst says so), so
  # left to default, a build of the linux/x86-64 artifact on a darwin/aarch64
  # builder would install ARM64 headers and succeed. That is the artifact's
  # CONTENTS decided by what the builder happens to be, which is the same defect
  # class as a dependency decided by what happened to be staged.
  #
  # ⚠ KARCH and not ARCH on purpose: naming it ARCH would put the value in the
  # build's environment, where the kernel Makefile would pick it up IMPLICITLY
  # and an empty one would silently fall back to SUBARCH. KARCH is inert to the
  # Makefile, is passed on the command line (which overrides both the
  # environment and the file), and is gated below.
  #
  # The three values are the kernel's own ARCH names, taken from arch/ in the
  # tree. Makefile:411-419 then maps `x86_64` to SRCARCH `x86`; `arm64` and
  # `s390` are directories in arch/ and so are their own SRCARCH.
  env = {
    "linux/x86-64"  = { KARCH = "x86_64" }
    "linux/aarch64" = { KARCH = "arm64" }
    "linux/s390x"   = { KARCH = "s390" }
  }

  script = [
    # ⛔ A GATE AND NOT A COMMENT. A platform this recipe has no KARCH for must
    # FAIL here, not inherit the builder's uname: the wrong answer is a package
    # that builds, installs and is wrong about every ioctl number.
    {
      run = <<EOT
if test -z "$KARCH"; then
  echo "linux-headers: no KARCH for {{hw.platform}}/{{hw.arch}}." >&2
  echo "  Add it to build.env rather than letting Makefile:407 ARCH ?= \$(SUBARCH)" >&2
  echo "  take this BUILDER's uname -m: the asm/ headers would be the wrong arch." >&2
  exit 1
fi
EOT
    },

    # ⭐ NO `make defconfig` AND NO .config, WHICH IS MEASURED: Makefile:297
    # lists `headers headers_% archheaders archscripts` in
    # `no-dot-config-targets`, and :313-317 clears `need-config` when every
    # goal is in that list. `headers_install` matches `headers_%`, so an
    # unconfigured tree is the supported input.
    #
    # INSTALL_HDR_PATH is the prefix itself, not <prefix>/usr:
    # headers_install.rst — "An 'include' directory is automatically created
    # inside INSTALL_HDR_PATH and headers are installed in
    # 'INSTALL_HDR_PATH/include'" — so this lands them in {{prefix}}/include,
    # which is where a consumer's -I expects them.
    "make headers_install ARCH=\"$KARCH\" INSTALL_HDR_PATH=\"{{prefix}}\"",
  ]
}

test {
  script = [
    # The package ships headers and nothing executable, so the test asserts
    # what was installed rather than running it.
    "test -f \"{{prefix}}/include/linux/fs.h\"",
    "test -f \"{{prefix}}/include/asm-generic/errno.h\"",

    # ⛔⛔ AND THE ONE ASSERTION THAT WOULD HAVE CAUGHT THE DEFAULT-ARCH DEFECT.
    # A header that exists under exactly ONE arch's uapi/asm proves the asm/
    # directory in this artifact is the TARGET's and not the builder's. Chosen
    # by checking BOTH directions in the kernel tree on 2026-11-16, because a
    # witness that is present everywhere witnesses nothing:
    #
    #   arch/x86/include/uapi/asm/vm86.h           present     arm64: 404
    #   arch/arm64/include/uapi/asm/sve_context.h  present     x86:   404
    #   arch/s390/include/uapi/asm/dasd.h          present     x86:   404
    #
    # Without the cross-checks this would be the shape of
    # a-break-check-that-did-not-break: three files that exist, asserted to
    # mean something they do not.
    {
      if  = "linux/x86-64"
      run = "test -f \"{{prefix}}/include/asm/vm86.h\""
    },
    {
      if  = "linux/aarch64"
      run = "test -f \"{{prefix}}/include/asm/sve_context.h\""
    },
    {
      if  = "linux/s390x"
      run = "test -f \"{{prefix}}/include/asm/dasd.h\""
    },

    # ⚠ The kbuild bookkeeping the rsync filter exists to exclude must not be
    # in the artifact. Asserted as an absence, since this is the one thing a
    # hand-rolled copy would have got wrong.
    {
      run = <<EOT
if find "{{prefix}}/include" -name '.*.cmd' -print -quit | grep -q .; then
  echo "linux-headers: kbuild .cmd bookkeeping leaked into the artifact" >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "COPYING",                                  # the SPDX line, and "version 2 only"
    "Makefile",                                 # :297 no-dot-config-targets, :313-317 need-config, :407 ARCH ?= $(SUBARCH), :411-419 SRCARCH, :1494-1504 cmd_headers_install and its rsync
    "scripts/subarch.include",                  # SUBARCH := $(shell uname -m | sed …) — the default this recipe refuses
    "scripts/Makefile.headersinst",             # cmd_install runs headers_install.sh; if_changed writes the .cmd files
    "scripts/headers_install.sh",               # the tool census: sed -E, scripts/unifdef; and the Linux-syscall-note check
    "Documentation/kbuild/headers_install.rst", # the two arguments, their defaults, and "the linux/asm directory … is platform-specific"
    "arch/",                                    # the ARCH names, and the three single-arch witness headers with their cross-checks
    # Not a build file, and listed here because it is still the PROJECT's own
    # statement about its releases: it is where "the signature is made against
    # the uncompressed version of the archive" comes from, which is the whole
    # reason this recipe passes --sig-covers decompressed, and it carries the
    # signing fingerprint this recipe names. Read directly on 2026-11-19.
    "https://www.kernel.org/signature.html",
  ]

  consulted = [
    # Read for ONE fact only: that rsync's project name in the pantry is
    # `rsync.samba.org` and not `samba.org/rsync`. The directory listing was
    # read, not the recipe — `projects/samba.org/rsync` answers 404 and
    # `projects/rsync.samba.org` holds a package.yml.
    "pkgxdev/pantry projects/rsync.samba.org (directory listing, for the project name)",
  ]

  note = <<EOT
⭐⭐ BOTH DIGESTS ARE NOW VERIFIED BY `zpkb sourcepin` ITSELF, which they were
not when this recipe was written. The note below used to open "THE SIGNATURE IS
GOOD, AND OUR OWN VERIFIER CANNOT CHECK IT"; the gap it described is
go-zpkg/zpkb#492, fixed in go-zpkg/zpkb#507 and released as **v0.85.0**. The
explanation is kept because it is still why the flag has to be passed.

kernel.org signs the UNCOMPRESSED tar. Its own signature.html says why — "the
signature is made against the uncompressed version of the archive … so there is
only one signature required for .gz and .xz compressed versions of the release"
— and every .sign file repeats it in its armor header, together with the exact
command that produced the signed bytes:

  Comment: This signature is for the .tar version of the archive
  Comment: git archive --format tar --prefix=linux-7.2.15/ v7.2.15

A recipe's `distributable.url` names the .tar.xz, so `--sig-covers decompressed`
is what says that the warrant is over the other stream while the digest pinned
stays the compressed file's — which is what a build downloads.

Re-run on 2026-11-19 against v0.85.0, once per pinned version:

  $ zpkb sourcepin --version 7.2.15 --sig auto --sig-covers decompressed \
      --key <gregkh> --fingerprint "647F 2865 …" \
      https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.15.tar.xz

  archive    linux-7.2.15.tar.xz   160461468 bytes
    sha256   d0f6b1d7324c937ccaeb5c4ca7084bfcf71db2edb3e2d3a31f0ad83a681809ab   <- what this recipe PINS, reproduced by the tool
  tar        (decompressed)       1693143040 bytes
    sha256   1ade1a3b4ce88b0cd8e09f8818714916a89fc377e0b433fa1f3a2083fae9d9cb   <- what the SIGNATURE covers
  signature  GOOD, signed at 2026-11-01T12:45:29Z
    signer   647F28654894E3BD457199BE38DBBDC86092693E

  archive    linux-7.3.4.tar.xz    162439264 bytes
    sha256   b11b6df8295e8e991ff040b71aaa4994a8b55caa23b6b092907f195b5840fd1f   <- what this recipe PINS, reproduced by the tool
  tar        (decompressed)       1718958080 bytes
    sha256   8f61e30c134e2e862c394728456dabd6530bf819184f7709bb63cb7866c92760   <- what the SIGNATURE covers
  signature  GOOD, signed at 2026-11-10T18:11:52Z
    signer   647F28654894E3BD457199BE38DBBDC86092693E

Both pins, same signer, and both digests came out of the tool equal to what was
already written here — so the earlier measurement and this one agree, which is
the only reason to trust either.

Added 2026-11-20 (go-zpkg/recipes#208), same command, key from
https://github.com/gregkh.gpg (1 key read, selected by the fingerprint):

  archive    linux-7.3.5.tar.xz    162459524 bytes
    sha256   8f293f83d54f0b7b9be56863ebc5e4ea79d73e530b4ae55c572be97ef39f0990   <- what this recipe PINS
  signature  GOOD over the decompressed tar (linux-7.3.5.tar.sign),
             signed at 2026-11-17T10:18:09Z
    signer   647F28654894E3BD457199BE38DBBDC86092693E

⭐ AND THE A/B IS WHAT MAKES IT A MEASUREMENT RATHER THAN A HOPE. The same
command without the flag, same key, same signature URL, same archive:

  --sig-covers served        openpgp: invalid signature: RSA verification failure
  --sig-covers decompressed  GOOD

One flag apart. The refusal is still correct for the bytes it was given.

⭐⭐ THE KEY IS PUBLISHED ON TWO INDEPENDENT HOSTS, which retires the weaker of
the two limits this note used to record. It said "same host as the tarball, so
this is CONTINUITY and not independence" — true of kernel.org's Web Key
Directory. Measured 2026-11-19, both sides checked here rather than relayed:

  - https://github.com/gregkh.gpg — GitHub's ACCOUNT endpoint, which binds the
    key to the account rather than to a keyserver, 75381 bytes. `sourcepin`
    selected a key from it with `--fingerprint` and reported the full
    fingerprint back, so that file demonstrably holds it. This is the same trick
    that finished rsync.samba.org (go-zpkg/recipes#166).
  - https://www.kernel.org/signature.html — carries
    `647F 2865 4894 E3BD 4571  99BE 38DB BDC8 6092 693E` in its "Important
    fingerprints" table, read directly today (19073 bytes, the string present
    twice).

Two organisations, two hosts, one fingerprint. Not a key obtained out of band
from a person, which remains the only stronger rung, but no longer a single
publisher vouching for itself.

⚠ ONE LIMIT STANDS, in a better form than before: `--sig auto` now DOES find
this signature, because in `decompressed` mode it strips the compression suffix
first and tries <base>.sign before .asc and .sig — <base>.sign being the name
kernel.org publishes. Measured 2026-11-16 and unchanged: linux-7.2.15.tar.xz.asc,
.tar.xz.sig and .tar.xz.sign all answer 404 while linux-7.2.15.tar.sign answers
200. A signature is published under the name of the bytes it COVERS, which is
why appending to the compressed URL could never have worked.

⛔ AND ONE THING THIS RECIPE DOES NOT CLAIM: it has not been built. No session
here can run the factory, so what is established is the recipe's inputs — every
argument, dependency, arch name and installed path traced to a line in the
kernel's own files, cited above — and not that the build succeeds. The test
block is written to fail loudly on the two things most likely to be wrong (the
wrong arch's asm/, and kbuild bookkeeping in the artifact) rather than to pass
quietly.
EOT
}
