# util-linux — the portable half of the standard system utilities: uuidgen,
# getopt, hexdump, column, namei, whereis, logger and, on linux, a great many
# more (mount, lsblk, fdisk, losetup…).
#
# ⛔ WRITTEN FROM THE 2.42.4 TARBALL'S OWN FILES (go-zpkg/packages#440), not
# converted. It was a four-line fragment of two dependencies, with no build
# decision in it.
#
# ⭐⭐ WHAT READING THE SOURCE FOUND:
#
#   1. `make install` AS A NORMAL USER FAILS BY DEFAULT. Three switches default
#      to yes (configure.ac:3015-3033) and the install rules then run
#      `chown root:root` and `chmod 4755` on su, mount, umount and the like
#      (Makefile.in:19592-19612), `chgrp tty` and `chmod g+s` on wall and write
#      (:19578-19584). A factory build is not root, and a setuid file in a
#      content-addressed prefix is not wanted anyway. All three are off.
#   2. EIGHT OPTIONAL LIBRARIES ARE PROBED ON THE HOST AND LINKED WHATEVER THEY
#      ARE, and none is declared: udev (:1105, `auto`), ncursesw, ncurses and
#      tinfo (:1121-1237, `auto`), readline (:1258, `auto`), libcap-ng (:1669,
#      `auto`), zlib (:1741, `auto`, an AC_CHECK_LIB so it takes whatever is on
#      the default link path), libmagic (:1749, `auto`), libuser (:2422,
#      `check`), btrfs (:2690, `check`), systemd (:2709, `check`), libeconf
#      (:2821, `check`) and the python bindings (:2877, `check`). Two builds on
#      two machines gave two different set of programs (cfdisk needs ncurses,
#      script needs utempter, the cramfs tools need zlib…). All are named off.
#      The fragment's sqlite dependency was for liblastlog2 alone
#      (:1318-1330, `UL_REQUIRES_HAVE([liblastlog2], [sqlite3]…)`), a linux
#      thing (lastlog.h) that also builds a PAM module; sqlite.org has no
#      recipe in this tree, so liblastlog2 and its PAM module are named off
#      instead of depending on something that cannot be built.
#   3. THREE INSTALL DIRECTORIES COME FROM THE HOST'S PKG-CONFIG, and lie
#      outside the prefix. systemdsystemunitdir, tmpfilesdir and sysusersdir
#      (:2763-2801) are asked of systemd's .pc, bash completions
#      (:2863-2871) of bash-completion's. The first three are `no`, the last is
#      set INTO the prefix, so the completions are installed and stay inside.
#   4. DARWIN IS A DESIGNED TARGET, NOT AN ACCIDENT. configure.ac sets
#      darwin_os (:270) and defines _DARWIN_C_SOURCE (:281-283), and the
#      programs that need linux say so: UL_REQUIRES_LINUX turns them OFF with
#      a warning on any other OS under the default `check` state
#      (m4/ul.m4:157-175), ipcs, ipcmk and ipcrm are excluded on darwin
#      (:2122-2138). So the recipe does not restrict `platforms` and does not
#      patch: what configure keeps is what is built.
#   5. THE BINARIES ARE IN `bin`. usrbin_execdir is ${exec_prefix}/bin
#      (:110), and uuidgen, getopt, hexdump, column, namei, whereis and logger
#      are all in usrbin_exec_PROGRAMS (Makefile.in:109, :1403-1456), none of them
#      UL_REQUIRES_LINUX (configure.ac:1554, :2290-2311, :1949, :1970).

summary = "util-linux: the standard system utilities (uuidgen, getopt, hexdump, column, mount, lsblk…)"

# Documentation/licenses/: one file per licence in use, and README.licensing
# says each source file carries its own SPDX identifier; the programs are
# mostly GPL-2.0-or-later, the libraries LGPL-2.1-or-later.
license = "GPL-2.0-only AND GPL-2.0-or-later AND GPL-3.0-or-later AND LGPL-2.1-or-later AND BSD-2-Clause AND BSD-3-Clause AND BSD-4-Clause-UC AND EUPL-1.2 AND ISC AND MIT"

versions {
  github = "util-linux/util-linux"
  strip  = ["/^v/"]
  ignore = ["/rc|alpha|beta/"]
}

dependencies = {
  "gnu.org/gettext" = "^1"
}

distributable {
  # The project's own host: a real release tarball, which kernel.org signs.
  # The directory is the MARKETING version, v2.42 for 2.42.4 (the listing of
  # https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.42/ has
  # util-linux-2.42.4.tar.gz).
  url              = "https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v{{version.marketing}}/util-linux-{{version.raw}}.tar.gz"
  strip-components = 1

  # Recorded with `zpkb sourcepin`.
  #
  # ⚠ THE SIGNATURE IS NOT A WITNESS HERE, as for e2fsprogs. util-linux-2.42.4.tar.sign
  # covers the UNCOMPRESSED .tar, so not this .tar.gz, and no public key is on
  # the project's pages or in the tarball (README, README.licensing,
  # Documentation/). No keyserver was asked, by rule. The digest below is the
  # one in the directory's sha256sums.asc, a signed text read but not
  # verified, and it agrees with the fetched bytes.
  sha256 = {
    "2.42.4" = "af3241e7776964dcb6bb9a811ca7b0d93000b563e2ae2a8df8f80a7cd6e04d56"
  }
}

build {
  dependencies = {
    "gnu.org/make"                = "*"
    "freedesktop.org/pkg-config"  = "*"
  }

  env {
    ARGS = [
      "--prefix={{prefix}}",
      "--disable-dependency-tracking",

      # Finding 1.
      "--disable-makeinstall-chown",
      "--disable-makeinstall-setuid",
      "--disable-makeinstall-tty-setgid",

      # Finding 2.
      "--without-udev",
      "--without-ncursesw",
      "--without-ncurses",
      "--without-tinfo",
      "--without-readline",
      "--without-cap-ng",
      "--without-libz",
      "--without-libmagic",
      "--without-user",
      "--without-btrfs",
      "--without-systemd",
      "--without-econf",
      "--without-python",
      "--disable-pylibmount",
      "--disable-liblastlog2",
      "--disable-pam-lastlog2",

      # Finding 3.
      "--with-systemdsystemunitdir=no",
      "--with-tmpfilesdir=no",
      "--with-sysusersdir=no",
      "--with-bashcompletiondir={{prefix}}/share/bash-completion/completions",
    ]

    darwin {
      # `AM_GNU_GETTEXT([external])` (configure.ac:304) links libintl, which
      # libc has on linux and not on darwin.
      ARGS = "$ARGS --with-libintl-prefix={{deps.gnu.org/gettext.prefix}}"
    }
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# Finding 5.
provides = [
  "bin/column",
  "bin/getopt",
  "bin/hexdump",
  "bin/logger",
  "bin/namei",
  "bin/uuidgen",
  "bin/whereis",
]

test {
  script = [
    # Each prints "<name> from util-linux <version>".
    "{{prefix}}/bin/uuidgen --version | grep {{version.raw}}",
    "{{prefix}}/bin/getopt --version | grep {{version.raw}}",
    "{{prefix}}/bin/hexdump --version | grep {{version.raw}}",

    # A version 4 UUID has its version nibble at 4 and 36 characters in all.
    "{{prefix}}/bin/uuidgen -r | grep -E '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'",
    "printf 'a b\\nc d\\n' | {{prefix}}/bin/column -t | grep 'c  *d'",
  ]
}

provenance {
  read = [
    "configure.ac",                # :110-119 directories; :264-283 the OS; :303-304 gettext; :870-906 programs; :1105-1330 probed libraries and lastlog2; :1554 uuidgen; :1741-1761 zlib, libmagic; :2122-2138 darwin exclusions; :2290-2311 :1949 :1970 portable programs; :2422-2880 user, btrfs, systemd, econf, directories, python; :3015-3033 install switches
    "m4/ul.m4",                    # :149-175 UL_REQUIRES_LINUX; :178-195 UL_EXCLUDE_ARCH
    "Makefile.in",                 # :109-143 program lists; :19578-19612 chown and setuid rules
    "README.licensing",
    "Documentation/licenses/",     # the ten licence files
  ]

  consulted = [
    "https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/",                                  # the release directories
    "https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.42/",                            # the 2.42.x tarballs, .sign files and sha256sums.asc
    "https://mirrors.edge.kernel.org/pub/linux/utils/util-linux/v2.42/sha256sums.asc",              # the signed digest list, key not verified
    "pkgxdev/pantry projects/github.com/util-linux/util-linux/package.yml",                         # facts only: the fragment this recipe replaces
  ]

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the options are read from the
files above, the digest is measured, and the test block is written from the
tools' documented behaviour, not from a run.

⚠ THE SIGNATURE IS UNVERIFIED, for want of a published key: see the comment on
the digest.

⚠ UNMEASURED, and the first thing to look at if the build fails:
  - darwin: whether what configure keeps there compiles. The project supports
    the OS in configure.ac (finding 4) but nothing here was run on it;
  - `--without-libz` and the other `--without-*` spellings are those of the
    AC_ARG_WITH blocks quoted above, and `--disable-liblastlog2` and
    `--disable-pam-lastlog2` those of :1318 and :1344; an unknown --enable or
    --disable only warns in autoconf, so a misspelling would not stop configure;
  - the test line for `column -t` and the UUID pattern are from the manual
    pages, not from a run.

LIBLASTLOG2 AND ITS PAM MODULE ARE OFF, which the fragment's sqlite dependency
wanted: sqlite.org has no recipe in this tree (not merged), and it is linux-only
code. Adding it back is the dependency plus dropping the two disables.

Headers and libraries (libuuid, libblkid, libmount, libsmartcols, libfdisk) ARE
installed here, unlike e2fsprogs: the top Makefile installs them.
EOT
}
