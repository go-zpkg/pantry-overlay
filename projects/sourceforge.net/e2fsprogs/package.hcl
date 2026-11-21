# e2fsprogs — the ext2, ext3 and ext4 filesystem utilities: mke2fs, e2fsck,
# tune2fs, resize2fs, debugfs, dumpe2fs and their companions.
#
# ⛔ WRITTEN FROM THE 1.47.4 TARBALL'S OWN FILES (go-zpkg/packages#440), not
# converted. It was a nine-line fragment of two dependencies, with no build
# decision in it.
#
# ⭐⭐ WHAT READING THE SOURCE FOUND:
#
#   1. THE util-linux DEPENDENCY (LINUX ONLY) WAS A PROBE, AND IS GONE.
#      configure.ac:476-526 and :539-591: without a flag, libuuid and libblkid
#      are looked up with pkg-config and the SYSTEM ones are used when found
#      ("Using system uuid by default", :509; "Using system blkid library by
#      default", :573), the private ones in lib/uuid and lib/blkid otherwise.
#      So the fragment's `util-linux` made the build link util-linux's libraries
#      on linux and its own on darwin: two different programs from one recipe.
#      `--enable-libuuid --enable-libblkid` (:491-499, :554-563) build the
#      private ones everywhere, and nothing here needs util-linux.
#   2. THREE INSTALL DIRECTORIES ARE FOUND ON THE HOST AND LIE OUTSIDE THE
#      PREFIX. `--with-udev-rules-dir` (:1882-1914) defaults to udev's own
#      directory, `--with-crond-dir` (:1919-1948) to /etc/cron.d when it exists,
#      `--with-systemd-unit-dir` (:1953-1986) to systemd's. A build run on a
#      machine that has them writes rules, a crontab and units into the system
#      from `make install`. All three are `no`.
#   3. FOUR OPTIONAL PROBES LINK WHATEVER THEY FIND: fuse2fs (:1375-1429,
#      libfuse3 or osxfuse or libfuse, and linux headers), libarchive
#      (:1311-1363, dlopen on linux, a direct link on darwin), the uuid daemon
#      (:804-825, on by default with the private libuuid) and the fsck wrapper.
#      fuse2fs, libarchive and uuidd are named OFF: nothing here declares fuse
#      or libarchive, and uuidd wants a runtime directory and a user.
#   4. NO SHARED LIBRARY IS BUILT. `--enable-elf-shlibs` and `--enable-bsd-shlibs`
#      are both unset (:264-324, "Disabling ELF shared libraries by default"),
#      and the top Makefile's `install` (Makefile.in:74-77) installs the programs
#      and not the libraries (`install-libs` is a separate target, :83). The
#      libraries and headers are therefore not installed. A recipe that wanted
#      libext2fs for another package would have to ask.
#   5. THE PREFIX IS THE ROOT PREFIX. root_prefix is the prefix unless the
#      builder gives neither (:1742-1746; :1719-1726 sets it to '' only when no
#      --prefix is given), so e2fsck, mke2fs, tune2fs, debugfs and resize2fs land
#      in <prefix>/sbin (e2fsck/Makefile.in:199-206 and the other three).

summary = "e2fsprogs: the ext2, ext3 and ext4 filesystem utilities"

# NOTICE:1-9: GPL version 2 for the programs, LGPL version 2 for lib/ext2fs and
# lib/e2p, a BSD-style licence for lib/uuid (lib/uuid/COPYING:1-12, the
# three-clause text), an MIT-style one for lib/et and lib/ss. The tarball has no
# COPYING; the licence texts are the rest of NOTICE.
license = "GPL-2.0-only AND LGPL-2.0-only AND BSD-3-Clause AND MIT"

versions {
  url   = "https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/"
  match = "/v\\d+\\.\\d+\\.\\d+\\//"
  strip = [
    "/^v/",
    "/\\/$/",
  ]
}

# gettext is a runtime dependency on darwin only: libc has no gettext there, and
# `AM_GNU_GETTEXT([external])` (configure.ac:940) links libintl.
dependencies = {
  darwin = {
    "gnu.org/gettext" = "^1"
  }
}

distributable {
  # kernel.org's copy, the path the project's own page points to
  # (e2fsprogs.sourceforge.net: "or kernel.org"). 1.47.4 is the newest `versions`
  # resolves.
  url              = "https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v{{version}}/e2fsprogs-{{version}}.tar.gz"
  strip-components = 1

  # Recorded with `zpkb sourcepin`.
  #
  # ⚠ THE SIGNATURE IS NOT A WITNESS HERE, and that is stated rather than glossed.
  # The directory has e2fsprogs-1.47.4.tar.sign, a signature over the
  # UNCOMPRESSED .tar, so it does not cover this .tar.gz, and sha256sums.asc, a
  # clear-signed list that does name this file. But the project publishes no
  # public key: not on e2fsprogs.sourceforge.net, not in README, and the tarball
  # has none. No keyserver was asked, by rule. The witnesses are these:
  #   - the digest below is the very one written in sha256sums.asc (a signed
  #     text, unverified, agreeing with the fetched bytes);
  #   - sourceforge's copy is a differently compressed file (a different gzip
  #     digest, 2cec05f3…) whose DECOMPRESSED tar is identical (0aa08dd4…).
  sha256 = {
    "1.47.4" = "da274408bebbfd13a5a2fc3cfc66e3ffff17c48534673aa67f88d49b99123b96"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",
      "--disable-dependency-tracking",

      # Finding 1.
      "--enable-libuuid",
      "--enable-libblkid",

      # Finding 2: a path outside the prefix is state of the host.
      "--with-udev-rules-dir=no",
      "--with-crond-dir=no",
      "--with-systemd-unit-dir=no",

      # Finding 3.
      "--disable-fuse2fs",
      "--without-libarchive",
      "--disable-uuidd",
    ]

    darwin {
      # `AM_GNU_GETTEXT([external])` takes the library from the usual places and
      # from this prefix.
      ARGS = "$ARGS --with-libintl-prefix={{deps.gnu.org/gettext.prefix}}"
    }
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# misc/Makefile.in:39 SPROGS (mke2fs, tune2fs, dumpe2fs…, installed in
# $(root_sbindir), :566-567), e2fsck/Makefile.in:15 and :205-206,
# resize/Makefile.in:15 and :72-73, debugfs/Makefile.in:15 and :135-136.
provides = [
  "sbin/debugfs",
  "sbin/dumpe2fs",
  "sbin/e2fsck",
  "sbin/mke2fs",
  "sbin/resize2fs",
  "sbin/tune2fs",
]

test {
  script = [
    # Each tool prints "<name> <version> (<date>)" on stderr for -V.
    "{{prefix}}/sbin/mke2fs -V 2>&1 | grep {{version}}",
    "{{prefix}}/sbin/e2fsck -V 2>&1 | grep {{version}}",

    # End to end on a regular file: mke2fs creates it when a size is given,
    # e2fsck -f -n must find it clean (exit 0), and dumpe2fs reads it back.
    "{{prefix}}/sbin/mke2fs -q -F -t ext4 -L zpkg img.ext4 8M",
    "{{prefix}}/sbin/e2fsck -f -n img.ext4",
    "{{prefix}}/sbin/dumpe2fs -h img.ext4 2>&1 | grep 'Filesystem volume name:.*zpkg'",
  ]
}

provenance {
  read = [
    "configure.ac",       # :140-143 root-prefix; :264-324 shlibs; :476-591 libuuid and libblkid; :707-727 fsck; :804-825 uuidd; :940 gettext; :1311-1363 libarchive; :1375-1429 fuse2fs; :1696-1726 linux and root_prefix; :1742-1756 root dirs; :1882-1986 udev, cron, systemd
    "Makefile.in",        # :74-83 install and install-libs
    "misc/Makefile.in",   # :39-50 the program lists; :557-584 install
    "e2fsck/Makefile.in", # :15, :199-210
    "resize/Makefile.in", # :15, :66-73
    "debugfs/Makefile.in", # :15, :129-136
    "NOTICE",             # :1-9 the licences
    "lib/uuid/COPYING",   # :1-12 the BSD-style text
  ]

  consulted = [
    "http://e2fsprogs.sourceforge.net/",                                                                            # the page: the two download locations, no key
    "https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/",                                     # the release directories
    "https://mirrors.edge.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v1.47.4/sha256sums.asc",               # the signed digest list, key not verified
    "https://git.kernel.org/pub/scm/fs/ext2/e2fsprogs.git/plain/README",                                            # read for a key: none
    "pkgxdev/pantry projects/sourceforge.net/e2fsprogs/package.yml",                                                # facts only: the fragment this recipe replaces
  ]

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the options are read from the
files above, the digest is measured, and the test block is written from the
tools' documented behaviour, not from a run.

⚠ THE SIGNATURE IS UNVERIFIED, for want of a published key: see the comment on
the digest.

⚠ UNMEASURED, and the first thing to look at if the build fails:
  - darwin: whether the tree builds there at all. configure.ac has darwin
    branches (the libintl workaround at :1821-1829, Makefile.darwin-lib,
    libarchive's direct link) but nothing here was run on it. The recipe does
    not restrict `platforms`; if a program fails on darwin, that is the
    remedy and not a patch;
  - linux: gettext is NOT declared, as in the fragment. AM_GNU_GETTEXT looks for
    msgfmt on the host; whether a host without it builds is not known;
  - `mke2fs … img.ext4 8M` creating the file, and the `Filesystem volume name`
    label format, are from the documentation, not from a run.

The libraries and headers (libext2fs, libe2p, libcom_err, libss, libuuid,
libblkid) are NOT installed: finding 4.
EOT
}
