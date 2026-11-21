# kernel.org/kmod — kmod: the tools and libkmod for loading and inspecting
# Linux kernel modules (`kmod`, `depmod`, `insmod`, `lsmod`, `modinfo`,
# `modprobe`, `rmmod`).
#
# ⛔ WRITTEN FROM KMOD 34.3'S OWN FILES (go-zpkg/packages#431, #440), read out of
# the published source tarball, as a dependency of systemd (meson_options.txt:434
# `kmod`, "support for loadable modules"). Linux only: the kernel interface does
# not exist elsewhere.
#
# ⛔⛔ EVERY OPTION IN meson_options.txt, STATED:
#   zstd, xz, zlib  enabled (:34-57 and meson.build:294-325): libzstd >= 1.4.4,
#                   liblzma >= 4.99, zlib, each from a declared recipe, found
#                   through PKG_CONFIG_PATH. NOT dlopen'ed (`dlopen=[]` is the
#                   default; stated).
#   openssl         enabled (:60-64, meson.build:331-339): libcrypto >= 1.1.0
#                   for PKCS7 module signatures, from openssl.org.
#   tools           true: the seven programs below.
#   logging         true (the default, stated). debug-messages false.
#   build-tests     false: the test suite is not built.
#   manpages        false: it needs scdoc (meson.build:557-558), which no recipe
#                   of this tree provides. COST: no man pages.
#   docs            false (gtk-doc).
#   bash/fish/zshcompletiondir  "no": without it meson.build:247-248 probes for
#                   bash-completion/fish on the builder and installs into
#                   whichever it finds.
#   moduledir       /lib/modules, and distconfdir <prefix>/lib: the defaults
#                   (meson.build:205-206), stated rather than taken. The kernel
#                   modules and the system's modprobe.d belong to the HOST, so
#                   the first one is deliberately absolute.
#   sbindir         bin: meson.build:512-519 installs the six tool names as
#                   symlinks to `kmod` into sbindir; one directory keeps them
#                   all on PATH.

summary = "kmod: the tools and libkmod for loading and inspecting Linux kernel modules"

# meson.build:5 license : ['LGPLv2.1', 'GPL-2.0-or-later']; COPYING is the LGPL
# 2.1 text and tools/COPYING the GPL's: the library is LGPL, the tools are GPL.
license = "LGPL-2.1-or-later AND GPL-2.0-or-later"

platforms = ["linux"]

versions {
  url   = "https://mirrors.edge.kernel.org/pub/linux/utils/kernel/kmod/"
  match = "/kmod-\\d+(\\.\\d+)*\\.tar\\.xz/"
  strip = [
    "/^kmod-/",
    "/\\.tar\\.xz/",
  ]
}

dependencies = {
  "facebook.com/zstd"   = "*"
  "tukaani.org/xz"      = "*"
  "zlib.net"            = "*"
  "openssl.org"         = "^3"
}

distributable {
  url              = "https://mirrors.edge.kernel.org/pub/linux/utils/kernel/kmod/kmod-{{version.raw}}.tar.xz"
  strip-components = 1

  # 444648 bytes, fetched with `zpkb sourcepin`. The second witness is the
  # directory's own sha256sums.asc, fetched separately: its line for
  # kmod-34.3.tar.xz is the same digest. ⛔ The clear-signed file's signature and
  # the .tar.sign were NOT verified (no key was fetched, and a keyserver is
  # never asked).
  sha256 = {
    "34.3" = "985554de49c21a58abd68c6cda2251384e1e5bb08b3b14c7f02b51f4c90c2958"
  }
}

build {
  dependencies = {
    "mesonbuild.com"             = "*"
    "ninja-build.org"            = "*"
    "freedesktop.org/pkg-config" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir={{prefix}}/lib",
      "--sbindir=bin",
      "--buildtype=release",
      "--wrap-mode=nofallback",
      "-Dmoduledir=/lib/modules",
      "-Ddistconfdir={{prefix}}/lib",
      "-Dzstd=enabled",
      "-Dxz=enabled",
      "-Dzlib=enabled",
      "-Dopenssl=enabled",
      "-Ddlopen=",
      "-Dtools=true",
      "-Dlogging=true",
      "-Ddebug-messages=false",
      "-Dbuild-tests=false",
      "-Dmanpages=false",
      "-Ddocs=false",
      "-Dbashcompletiondir=no",
      "-Dfishcompletiondir=no",
      "-Dzshcompletiondir=no",
    ]

    PKG_CONFIG_PATH = "{{deps.facebook.com/zstd.prefix}}/lib/pkgconfig:{{deps.tukaani.org/xz.prefix}}/lib/pkgconfig:{{deps.zlib.net.prefix}}/lib/pkgconfig:{{deps.openssl.org.prefix}}/lib/pkgconfig:{{deps.openssl.org.prefix}}/lib64/pkgconfig"
    LDFLAGS         = "-Wl,-rpath,{{prefix}}/lib -Wl,-rpath,{{deps.facebook.com/zstd.prefix}}/lib -Wl,-rpath,{{deps.tukaani.org/xz.prefix}}/lib -Wl,-rpath,{{deps.zlib.net.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib -Wl,-rpath,{{deps.openssl.org.prefix}}/lib64"
  }

  script = [
    "meson setup build $ARGS",
    "meson compile -C build",
    "meson install -C build",
  ]
}

# meson.build:503-510 `_tools`, plus the `kmod` multicall binary itself.
provides = [
  "bin/depmod",
  "bin/insmod",
  "bin/kmod",
  "bin/lsmod",
  "bin/modinfo",
  "bin/modprobe",
  "bin/rmmod",
]

test {
  dependencies = {
    "gnu.org/gcc"                = "*"
    "freedesktop.org/pkg-config" = "*"
  }

  script = [
    "test \"$(kmod --version | head -n 1)\" = \"kmod version {{version.raw}}\"",
    "test -x {{prefix}}/bin/modprobe",
    "pkg-config --exists libkmod",
    "test \"$(pkg-config --modversion libkmod)\" = \"{{version.raw}}\"",
    # `kmod --version` also prints the compiled-in features: every one this
    # recipe turned on must be there.
    "kmod --version | grep -F '+ZSTD +XZ +ZLIB +OPENSSL' >/dev/null",
    {
      fixture = {
        content  = <<EOT
#include <libkmod.h>
#include <stdio.h>

int main(void) {
  struct kmod_ctx *ctx = kmod_new(NULL, NULL);
  if (ctx == NULL) {
    puts("kmod_new failed");
    return 1;
  }
  printf("libkmod context for %s\n", kmod_get_dirname(ctx));
  kmod_unref(ctx);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o ctx $(pkg-config --cflags --libs libkmod)"
    },
    "./ctx",
  ]
}

provenance {
  read = [
    "meson_options.txt", # every option, :1-:107; zstd/xz/zlib/openssl at :34-64; tools, dlopen, logging, manpages, docs below
    "meson.build",       # :4-6 version and licence; :194-206 dir defaults; :234-288 completions; :294-339 compression and openssl; :503-520 tools and sbindir symlinks; :557-558 manpages need scdoc
    "COPYING",           # the GNU Lesser General Public License 2.1 text
    "tools/COPYING",     # the tools' GPL
  ]

  consulted = [
    "sha256sums.asc beside the tarball", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform (linux is the only platform).

Two build systems ship in 34.3 (configure and meson.build); meson is used
because it is the one the upstream's own README and CI drive. The test's
feature string (`+ZSTD +XZ +ZLIB +OPENSSL`) is what tools/kmod.h:30-34 prints
(`puts(KMOD_FEATURES)`, the join of meson.build:323 and :341), read from the
source and not from a run: if the first run prints it differently, that line is
the one to fix.
EOT
}
