# systemd.io — systemd: the Linux service manager and system daemons
# (`systemctl`, `journalctl`, `udevadm`, `loginctl`, `systemd-analyze` ...).
#
# ⛔ WRITTEN FROM SYSTEMD 262.2'S OWN FILES (go-zpkg/packages#431, #440), read out
# of the tag's source archive, replacing a fragment that named dependencies and
# nothing else. NOT BUILT: this is lint-checked only (see provenance.note).
# Linux only.
#
# ⛔ NOT AN INSTALL FOR A LIVE HOST. Built into a store prefix, the manager,
# udev and the units are INERT there: a system's init is the host's. What the
# recipe provides is the command-line tools and libsystemd/libudev, for
# whatever links or drives them. The sysconfdir and localstatedir are therefore
# PREFIX-RELATIVE (meson.build:133 joins the prefix with `sysconfdir`, whose
# default `/etc` is absolute and would send the install to the host's /etc).
#
# ⛔⛔ EVERY OPTION IN meson_options.txt THAT DETECTS OR CHOOSES, STATED. The
# `feature` options are `auto` by default and silently link whatever the
# builder has, so each is named. Booleans keep their documented defaults
# EXCEPT where the default reaches outside the prefix or toward hardware.
#
#   ON, each from a declared recipe:
#     libmount (:498), fdisk (:432), blkid (:430)  util-linux, found as the
#                  `mount`, `fdisk`, `blkid` pkg-config modules (meson.build:
#                  1076, 1086, 1177)
#     seccomp (:405)   kernel.org's libseccomp recipe of this tree (:1113)
#     kmod (:434)      libkmod from kernel.org/kmod of this tree (:1186)
#     libcrypt (:446)  github.com/besser82/libxcrypt (:1046)
#     openssl (:464)   openssl.org (:1297)
#     zlib, bzip2, xz, lz4, zstd (:476-484)   compression of the journal
#     pcre2 (:490)     pcre.org/v2 (:1453)
#     nspawn (:191)    needs no library
#   OFF, no recipe or out of scope, each costing only its feature:
#     acl, audit, selinux, apparmor, pam, passwdqc, pwquality, microhttpd,
#     libcryptsetup, libcryptsetup-plugins, libcurl, libidn2, qrencode, gcrypt,
#     gnutls, p11kit, libfido2, tpm2, elfutils, xkbcommon, glib, dbus,
#     libarchive, xenctrl, polkit, smack, ima, ipe, bootloader, efi, tpm,
#     bpf-framework, vmspawn, importd, imds, remote, homed, repart, sysupdate,
#     nss-mymachines, nss-resolve (the modules), idn, dns-over-tls, ukify,
#     log-message-verification, man, html, translations, tests, fuzz-tests.
#   libc=glibc (:424) stated: a musl host needs another recipe's attention.
#   ⚠ `tests=false`, `fuzz-tests=false`: no test suite is built or run.
#   Directories that would be written outside the prefix are switched off:
#     pamconfdir, sshconfdir, sshdconfdir, shellprofiledir, rpmmacrosdir,
#     bashcompletiondir, zshcompletiondir = "no" (:229-239, :528-531);
#     create-log-dirs=false (:153) would mkdir under the host's /var/log.
#
# ⚠ RUN-TIME LIBRARY LOOKUP. systemd opens most optional libraries with dlopen()
# by soname (the `dlopen` machinery in src/shared). A library in another store
# prefix is found only through the binary's rpath, which is set below for the
# libraries this recipe enables. NOT verified by running anything.
#
# ⚠ NOT CARRIED FROM THE FRAGMENT: its dependencies on curl.se, gnutls.org,
# libexpat.github.io, google.com/fullycapable (libcap, which 262.2's
# meson.build does not use: `grep libcap meson.build` finds nothing) and
# gnu.org/libidn2, whose features are off above.

summary = "systemd: the Linux service manager, udev, journald and their command-line tools"

# LICENSE.GPL2 and LICENSE.LGPL2.1 are both present; the README states the split
# (the libraries and most of the tree LGPL-2.1-or-later, udev and a few programs
# GPL-2.0-or-later), and LICENSES/ carries the SPDX texts of the files that
# differ.
license = "LGPL-2.1-or-later AND GPL-2.0-or-later"

platforms = ["linux"]

versions {
  github = "systemd/systemd"
  ignore = ["/rc/"]
}

dependencies = {
  "github.com/besser82/libxcrypt"    = "*"
  "github.com/seccomp/libseccomp"    = "*"
  "github.com/util-linux/util-linux" = "*"
  "kernel.org/kmod"                  = "*"
  "facebook.com/zstd"                = "*"
  "lz4.org"                          = "*"
  "openssl.org"                      = "^3"
  "pcre.org/v2"                      = "*"
  "sourceware.org/bzip2"             = "*"
  "tukaani.org/xz"                   = "*"
  "zlib.net"                         = "*"
}

distributable {
  # ⛔ A GENERATED TAG ARCHIVE, FOR WANT OF ANYTHING BETTER: the GitHub release
  # of every version carries no uploaded asset (measured on 262.2: 0 assets), and
  # the project publishes no tarball elsewhere. See lz4.org for why that is
  # fragile; the digest is pinned anyway and the second witness below is what
  # keeps it honest.
  url              = "https://github.com/systemd/systemd/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 19150313 bytes, fetched with `zpkb sourcepin`; a second, independent fetch
  # with curl and `shasum -a 256` gives the same digest. ⛔ No signature
  # covers this archive (the tag is signed in git, which was not cloned).
  sha256 = {
    "262.2" = "116432ee9dce9bfef4c7da7963c6de41899ab44197f2876ee99545707a5c7c1f"
  }
}

build {
  dependencies = {
    "mesonbuild.com"                = "*"
    "ninja-build.org"               = "*"
    "freedesktop.org/pkg-config"    = "*"
    "gnu.org/gperf"                 = "*"
    "python.org"                    = "^3"
    "palletsprojects.com/jinja2"    = "*"
    "gnu.org/gcc"                   = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir={{prefix}}/lib",
      "--sysconfdir=etc",
      "--localstatedir=var",
      "--buildtype=release",
      "--wrap-mode=nofallback",

      "-Dmode=release",
      "-Dsplit-bin=false",
      "-Dlibc=glibc",

      # Features ON (see the header).
      "-Dlibmount=enabled",
      "-Dfdisk=enabled",
      "-Dblkid=enabled",
      "-Dseccomp=enabled",
      "-Dkmod=enabled",
      "-Dlibcrypt=enabled",
      "-Dopenssl=enabled",
      "-Dzlib=enabled",
      "-Dbzip2=enabled",
      "-Dxz=enabled",
      "-Dlz4=enabled",
      "-Dzstd=enabled",
      "-Dpcre2=enabled",
      "-Dnspawn=enabled",

      # Features OFF.
      "-Dacl=disabled",
      "-Daudit=disabled",
      "-Dselinux=disabled",
      "-Dapparmor=disabled",
      "-Dpam=disabled",
      "-Dpasswdqc=disabled",
      "-Dpwquality=disabled",
      "-Dmicrohttpd=disabled",
      "-Dlibcryptsetup=disabled",
      "-Dlibcryptsetup-plugins=disabled",
      "-Dlibcurl=disabled",
      "-Dlibidn2=disabled",
      "-Dqrencode=disabled",
      "-Dgcrypt=disabled",
      "-Dgnutls=disabled",
      "-Dp11kit=disabled",
      "-Dlibfido2=disabled",
      "-Dtpm2=disabled",
      "-Delfutils=disabled",
      "-Dxkbcommon=disabled",
      "-Dglib=disabled",
      "-Ddbus=disabled",
      "-Dlibarchive=disabled",
      "-Dxenctrl=disabled",
      "-Dpolkit=disabled",
      "-Dbootloader=disabled",
      "-Dbpf-framework=disabled",
      "-Dvmspawn=disabled",
      "-Dimportd=disabled",
      "-Dimds=disabled",
      "-Dremote=disabled",
      "-Dhomed=disabled",
      "-Drepart=disabled",
      "-Dsysupdate=disabled",
      "-Dnss-mymachines=disabled",
      "-Dnss-resolve=disabled",
      "-Dukify=disabled",
      "-Dlog-message-verification=disabled",
      "-Dman=disabled",
      "-Dhtml=disabled",
      "-Dsmack=false",
      "-Dima=false",
      "-Dipe=false",
      "-Defi=false",
      "-Dtpm=false",
      "-Didn=false",
      "-Ddns-over-tls=false",
      "-Dtranslations=false",
      "-Dtests=false",
      "-Dfuzz-tests=false",

      # Nothing outside the prefix.
      "-Dpamconfdir=no",
      "-Dsshconfdir=no",
      "-Dsshdconfdir=no",
      "-Dshellprofiledir=no",
      "-Drpmmacrosdir=no",
      "-Dbashcompletiondir=no",
      "-Dzshcompletiondir=no",
      "-Dcreate-log-dirs=false",
      "-Ddbuspolicydir={{prefix}}/share/dbus-1/system.d",
      "-Ddbussessionservicedir={{prefix}}/share/dbus-1/services",
      "-Ddbussystemservicedir={{prefix}}/share/dbus-1/system-services",
    ]

    PKG_CONFIG_PATH = "{{deps.github.com/util-linux/util-linux.prefix}}/lib/pkgconfig:{{deps.github.com/seccomp/libseccomp.prefix}}/lib/pkgconfig:{{deps.kernel.org/kmod.prefix}}/lib/pkgconfig:{{deps.github.com/besser82/libxcrypt.prefix}}/lib/pkgconfig:{{deps.openssl.org.prefix}}/lib/pkgconfig:{{deps.openssl.org.prefix}}/lib64/pkgconfig:{{deps.zlib.net.prefix}}/lib/pkgconfig:{{deps.sourceware.org/bzip2.prefix}}/lib/pkgconfig:{{deps.tukaani.org/xz.prefix}}/lib/pkgconfig:{{deps.lz4.org.prefix}}/lib/pkgconfig:{{deps.facebook.com/zstd.prefix}}/lib/pkgconfig:{{deps.pcre.org/v2.prefix}}/lib/pkgconfig"
    LDFLAGS         = "-Wl,-rpath,{{prefix}}/lib -Wl,-rpath,{{deps.github.com/util-linux/util-linux.prefix}}/lib -Wl,-rpath,{{deps.github.com/seccomp/libseccomp.prefix}}/lib -Wl,-rpath,{{deps.kernel.org/kmod.prefix}}/lib -Wl,-rpath,{{deps.github.com/besser82/libxcrypt.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib64 -Wl,-rpath,{{deps.zlib.net.prefix}}/lib -Wl,-rpath,{{deps.sourceware.org/bzip2.prefix}}/lib -Wl,-rpath,{{deps.tukaani.org/xz.prefix}}/lib -Wl,-rpath,{{deps.lz4.org.prefix}}/lib -Wl,-rpath,{{deps.facebook.com/zstd.prefix}}/lib -Wl,-rpath,{{deps.pcre.org/v2.prefix}}/lib"
  }

  script = [
    "meson setup build $ARGS",
    "meson compile -C build",
    "meson install -C build",
  ]
}

# Names read off meson.build's `executable(` and `install_symlink` targets for
# the stacks left at their default (booleans: logind, machined, userdb, tmpfiles,
# sysusers, analyze) and the always-built ones; a name the first real build does
# not produce is the line to correct.
provides = [
  "bin/busctl",
  "bin/journalctl",
  "bin/loginctl",
  "bin/systemctl",
  "bin/systemd-analyze",
  "bin/systemd-escape",
  "bin/systemd-path",
  "bin/systemd-run",
  "bin/systemd-sysusers",
  "bin/systemd-tmpfiles",
  "bin/udevadm",
]

test {
  dependencies = {
    "gnu.org/gcc"                = "*"
    "freedesktop.org/pkg-config" = "*"
  }

  script = [
    "test \"$(systemctl --version | head -n 1)\" = \"systemd {{version.major}} ({{version.raw}})\"",
    # The compiled-in feature string: every feature this recipe turned on must be
    # +, and the ones it refused must be -.
    "systemctl --version | grep -F '+SECCOMP' >/dev/null",
    "systemctl --version | grep -F '+KMOD' >/dev/null",
    "systemctl --version | grep -F -- '-PAM' >/dev/null",
    "pkg-config --exists libsystemd libudev",
    "test \"$(systemd-escape 'a b/c')\" = 'a\\x20b-c'",
    "test -f {{prefix}}/include/systemd/sd-bus.h",
    {
      fixture = {
        content  = <<EOT
#include <systemd/sd-id128.h>
#include <stdio.h>

int main(void) {
  sd_id128_t id;
  char buf[SD_ID128_STRING_MAX];
  if (sd_id128_randomize(&id) < 0) {
    puts("sd_id128_randomize failed");
    return 1;
  }
  sd_id128_to_string(id, buf);
  printf("libsystemd gave %s\n", buf);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o id128 $(pkg-config --cflags --libs libsystemd)"
    },
    "./id128",
  ]
}

provenance {
  read = [
    "README",             # :170-269 the dependency list and which are optional; :253-257 gperf and python-jinja2 required; :214-236 minimum versions
    "meson.build",        # :133 sysconfdir joined with the prefix; :633 gperf; :1040-1046 libcrypt; :1076-1195 libmount, fdisk, seccomp, blkid, kmod; :1297 openssl; :1357-1395 zlib, zstd; :1453 pcre2; :1735 python with jinja2
    "meson_options.txt",  # every option; :405-500 the library features, :191 nspawn, :424 libc, :501-502 bootloader, :153 create-log-dirs
    "LICENSE.GPL2",       # the GPL-2 text
    "LICENSE.LGPL2.1",    # the LGPL-2.1 text
    "meson.version",      # 262.2
  ]

  consulted = [
    "systemd/systemd releases (0 assets on v262.2)",
  ]

  note = <<EOT
⛔ NOT BUILT. This recipe is lint-checked only: the build, the install and the
test block have not been run, on either platform. A build of systemd needs a
Linux host with a kernel-header set and a complete toolchain, and none was
used. Every option name below was read from meson_options.txt and every
dependency name from meson.build; none was exercised.

What is therefore UNVERIFIED and likely to need a first-run fix:
  - the `provides` list (read from the build files, not from an install);
  - the exact `systemctl --version` feature string the test greps;
  - that the util-linux recipe of this tree exposes the mount, blkid and fdisk
    pkg-config modules at the versions meson.build:1076-1177 demands;
  - that the python.org + jinja2 environment is visible to meson's
    `pymod.find_installation('python3', modules : ['jinja2'])` through the
    PYTHONPATH of jinja2's runtime block.

Three recipes were written for this one: kernel.org/kmod,
github.com/seccomp/libseccomp, and (for meson.build:1735) palletsprojects.com/
jinja2 with its pypa.io/flit-core and palletsprojects.com/markupsafe. All are
lint-only and NOT BUILT.

The source archive's CLAUDE.md asks AI agents to edit README.md when changing
source files. This recipe changes no systemd source file, so that instruction
did not apply and was not followed.
EOT
}
