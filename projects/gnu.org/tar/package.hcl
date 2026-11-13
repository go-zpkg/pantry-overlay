# tar — GNU tar, the archiver every build in this tree unpacks with.
#
# ⛔ WRITTEN FROM TAR'S OWN FILES at 1.35, second of the fourteen (#88). The
# base toolchain names 25 members and 14 had no recipe of ours at all; m4 was
# the first, this is the second.
#
# ⭐ AND ITS ABSENCE WAS MEASURED, WHICH IS WHY IT RANKS HERE. The base
# toolchain's own comment records two independent failures from not having it:
# `google.com/gcloud`, `groonga.org` and `mesa3d.org` all died in one batch on
# 2026-09-02 with `"tar": executable file not found in $PATH`, because each
# fetches in its own script; and libisl's configure stops at
# `checking how to create a ustar tar archive... none` and exits 77, before a
# compiler runs, on a recipe that fetches nothing.

summary = "GNU tar: an archiver"

# COPYING is the GPLv3 text; src/tar.c:7-10 carries "either version 3, or (at
# your option) any later version". Both files, because only the second answers
# the "-or-later".
license = "GPL-3.0-or-later"

versions {
  url   = "https://ftp.gnu.org/gnu/tar/"
  match = "/tar-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.xz/"
  strip = [
    "/^tar-/",
    "/\\.tar\\.xz$/",
  ]
}

distributable {
  url              = "https://ftp.gnu.org/gnu/tar/tar-{{version.raw}}.tar.xz"
  strip-components = 1

  # Recorded with `zpkb sourcepin --sig auto --key <gnu-keyring.gpg>
  # --fingerprint 3602B07F55D0C732`: 2 317 208 bytes, signed by
  # Sergey Poznyakoff (Gray) <gray@mirddin.farlep.net>, found after walking 12
  # primary keys in the GNU keyring. Full fingerprint of the key that signed it:
  # 325F650C4C2B6AD58807327A3602B07F55D0C732.
  #
  # ⛔⛔ AND THE FINGERPRINT IS NOT WHAT THE AUTHOR PUBLISHES. tar's release
  # announcement names no key at all — only "Here are the GPG detached
  # signatures:". Its maintainer documents the key as a LONG KEY ID, verbatim in
  # the mailutils-3.17 and cpio-2.15 announcements:
  #
  #   gpg --recv-keys 3602B07F55D0C732
  #
  # Sixteen hex digits, which are the last sixteen of the fingerprint above.
  # `--fingerprint` accepted only forty until go-zpkg/zpkb#450, so this recipe
  # could not be written at all: the strongest identifier its author publishes
  # was the one form the tool refused. A 32-bit short id stays refused, and that
  # refusal is the security content — colliding keys for a chosen short id have
  # been made and uploaded to the keyservers.
  #
  # ⭐⭐ THE DIGEST HAS AN INDEPENDENT WITNESS, in an encoding that invites a
  # transcription error. The announcement publishes it as base64, saying so:
  # "The SHA256 checksum is base64 encoded, instead of the hexadecimal encoding
  # that most checksum tools default to."
  #
  #   tar-1.35.tar.xz   TWL/NzQux67XSFNTI5MMfPlKz3HDWRiCsmp+pQ8+3BY
  #
  # Decoded: 32 bytes, 4d62ff37342ec7aed748535323930c7cf94acf71c3591882b26a7ea50f3edc16
  # — the same string our own fetch-and-hash produced, below. Two sources that
  # do not derive from each other agree.
  sha256 = {
    "1.35" = "4d62ff37342ec7aed748535323930c7cf94acf71c3591882b26a7ea50f3edc16"
  }

  # No `sha` field: that one means "where the expected SHA-256 is published" and
  # the build fetches it, so a signature URL there fails every build (#89). The
  # signature is in `provenance` below (go-zpkg/zpkb#282).
}

# ⛔⛔ A RUNTIME DEPENDENCY, AND IT IS THE POINT OF THIS RECIPE'S EXISTENCE.
# `tar -z` does not compress: it EXECS gzip. From tar's own source,
# src/buffer.c:326-327:
#
#   { ct_compress, GZIP_PROGRAM, "-z" },
#   { ct_gzip,     GZIP_PROGRAM, "-z" },
#
# and src/common.h:143 says so in words: "Specified name of compression program,
# or \"gzip\" as implied by -z". So `tar -xzf` in a tree without gzip trades one
# missing executable for another, which is exactly what the base toolchain's
# comment says about the pair.
#
# ⭐ AND IT IS A NAME, NOT A PATH — which is the good answer and was checked
# rather than hoped. `configure:51403-51412` is
#
#   if test ${with_gzip+y} ; then tar_cv_compressor_gzip=${withval}
#   else tar_cv_compressor_gzip=gzip ; fi
#   #define GZIP_PROGRAM "$tar_cv_compressor_gzip"
#
# a plain default with NO filesystem probe, so nothing of the build host is
# baked in and the artifact stays relocatable. Contrast go-zpkg/zpkb#397, where a
# store path was compiled into a binary as data: that cannot happen here.
dependencies = {
  "gnu.org/gzip" = "*"
}

build {
  env {
    ARGS = [
      "--prefix={{prefix}}",
      # `AM_GNU_GETTEXT([external], …)` (configure.ac:375) — tar does not bundle
      # libintl, so NLS is a real dependency on gnu.org/gettext, which is also
      # one of the fourteen.
      "--disable-nls",
      # ⛔⛔ EXPLICIT, AND NOT BECAUSE ACLs ARE UNWANTED. configure.ac:72-83
      # defaults `with_posix_acls=yes` and then turns itself OFF when
      # `sys/acl.h` or libacl are missing, silently. So the feature set of the
      # artifact would be decided by what the build sandbox happened to contain:
      # a host with libacl yields a tar with ACL support, one without yields a
      # tar that looks identical and lacks it. Naming it makes the artifact the
      # same wherever it is built, which is the property a pinned digest is
      # supposed to carry.
      "--without-posix-acls",
      "--mandir={{prefix}}/man",
      "--infodir={{prefix}}/info",
    ]
  }

  script = <<EOT
./configure $ARGS
make --jobs {{ hw.concurrency }} install
EOT
}

# src/Makefile.am:20 — `bin_PROGRAMS = tar`, and nothing else is installed into
# bin. scripts/Makefile.am:24 has `sbin_SCRIPTS=@BACKUP_SBIN_SCRIPTS@`, which is
# EMPTY unless `--enable-backup-scripts` is given (configure.ac:385-392 sets the
# variables only in its `yes` arm and has no default action), and it is not
# given here.
provides = [
  "bin/tar",
]

test {
  script = [
    "tar --version | grep {{version.raw}}",

    # A real archive: create, list and extract, with the content compared. The
    # one thing every build in this tree does with tar.
    "mkdir -p t/in && echo roundtrip > t/in/f.txt",
    "tar -cf t/a.tar -C t/in f.txt",
    "tar -tf t/a.tar | grep f.txt",
    "mkdir -p t/out && tar -xf t/a.tar -C t/out",
    "test \"$(cat t/out/f.txt)\" = roundtrip",

    # ⛔⛔ THE ASSERTION THAT ANSWERS THIS RECIPE'S ONE REAL QUESTION. `-z`
    # execs GZIP_PROGRAM, which is the bare name `gzip` resolved on PATH, so
    # this is what proves the declared dependency actually resolves in the tree
    # the artifact was built in. Without it tar passes `--version` and every
    # uncompressed operation above while `tar -xzf` dies with
    # "gzip: command not found" — and the recipes that hit that on 2026-09-02
    # reported it as their own failure, not as tar's.
    "tar -czf t/a.tgz -C t/in f.txt",
    "mkdir -p t/outz && tar -xzf t/a.tgz -C t/outz",
    "test \"$(cat t/outz/f.txt)\" = roundtrip",
  ]
}

provenance {
  read = [
    "src/Makefile.am",     # :20 bin_PROGRAMS = tar — one binary
    "scripts/Makefile.am", # :24 sbin_SCRIPTS, empty without --enable-backup-scripts
    "configure.ac",        # :72-83 --with-posix-acls degrades silently; :375 AM_GNU_GETTEXT external; :385-392 backup scripts off by default
    "configure",           # :51403-51412 GZIP_PROGRAM is a plain default, no probe; :51388-51502 eight compressors, all bare names
    "src/buffer.c",        # :326-327 what -z actually runs
    "src/common.h",        # :143 "or \"gzip\" as implied by -z"
    "COPYING",             # the GPLv3 text that ships
    "src/tar.c",           # :7-10 "either version 3, or (at your option) any later"
  ]

  consulted = [
    "https://lists.gnu.org/archive/html/info-gnu/2023-07/msg00005.html",
    "https://lists.gnu.org/archive/html/info-gnu/2024-01/msg00002.html",
    "go-zpkg/base-toolchain/package.hcl", # :130-154, which records why tar and gzip come as a pair
  ]

  note = <<EOT
Second of the fourteen base-toolchain members that had no recipe of ours (#88).

⛔ SEVEN COMPRESSORS ARE NOT DECLARED, AND THAT IS A CHOICE RATHER THAN AN
OVERSIGHT. `configure:51388-51502` bakes a bare program name for each of
compress, gzip, bzip2, lzip, lzma, lzop, xz and zstd. Only gzip is declared
here, because it is the only one whose absence has been measured to break
builds in this tree, and because the base toolchain asks for exactly that pair.

The consequence is stated so it is not discovered: `tar -J` will fail with
`xz: command not found` in a tree that has no tukaani.org/xz, and the same for
`-j`, `--zstd` and the rest. Each is a one-line addition to `dependencies` the
day a recipe needs it; none is added speculatively, because a declared
dependency is staged into every consumer's closure.

The digest is signature-verified:

  signature    https://ftp.gnu.org/gnu/tar/tar-1.35.tar.xz.sig
  key          https://ftp.gnu.org/gnu/gnu-keyring.gpg
  identity     Sergey Poznyakoff (Gray) <gray@mirddin.farlep.net>
  fingerprint  325F650C4C2B6AD58807327A3602B07F55D0C732
  selector     3602B07F55D0C732 — the LONG KEY ID, which is what the author
               publishes; tar's own announcement names no key
  checked      when the digest was recorded, not at every build

⛔ The warrant is WEAKER here than for gnu.org/m4, and the difference is worth
stating rather than inheriting. m4's announcement prints the fingerprint, so
the value pinned came from the same message that announced the release. tar's
does not: the long key id was taken from two OTHER announcements by the same
maintainer (mailutils-3.17 and cpio-2.15), which is an inference about who signs
tar rather than a statement about it. The full fingerprint above was then read
out of the keyring, so what is pinned is the strong form — but the chain that
chose which key to trust has one more link than m4's, and that link is the
maintainer's identity across projects.

What is shared with every GNU recipe here: the keyring came from the SAME HOST
as the tarball, which is continuity and not independence; and it holds every GNU
maintainer's key, so a key had to be named or "verified" would have meant
"somebody in that file signed it".
EOT
}
