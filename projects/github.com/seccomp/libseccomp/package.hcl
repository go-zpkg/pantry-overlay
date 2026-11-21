# github.com/seccomp/libseccomp — libseccomp: the high-level interface to the
# Linux kernel's seccomp syscall filter, and `scmp_sys_resolver`.
#
# ⛔ WRITTEN FROM THE RELEASE TARBALL'S OWN FILES (go-zpkg/packages#431, #440),
# as a dependency of systemd (meson_options.txt:405 `seccomp`), whose
# service sandboxing (SystemCallFilter=) is built on it. Linux only: the
# library talks to a kernel interface that darwin does not have.

summary = "libseccomp: the high-level interface to the Linux kernel's seccomp filters"

# LICENSE is the LGPL-2.1 text, and the library is the LGPL; tools/ is separate
# (see the README's licence notes, not repeated here).
license = "LGPL-2.1-only"

platforms = ["linux"]

versions {
  github = "seccomp/libseccomp"
}

distributable {
  # The STORED release asset: the project uploads the tarball, its detached
  # signature (.asc) and a checksum file (.SHA256SUM, itself signed).
  url              = "https://github.com/seccomp/libseccomp/releases/download/v{{version.raw}}/libseccomp-{{version.raw}}.tar.gz"
  strip-components = 1

  # 660276 bytes, fetched with `zpkb sourcepin`. The second witness is the
  # project's own libseccomp-2.6.2.tar.gz.SHA256SUM, fetched separately: it says
  # the same digest. ⛔ The .asc signature was NOT verified (no key was
  # fetched, and a keyserver is never asked).
  sha256 = {
    "2.6.2" = "6b845d352c6d7887d8d134c43d86850d40f5dcee11ad1675c18197ae4d869d42"
  }
}

build {
  dependencies = {
    "gnu.org/gperf" = "*"
    "gnu.org/make"  = "*"
    "gnu.org/gcc"   = "*"
  }

  # The tarball carries a generated ./configure. Every switch configure.ac
  # reads is stated:
  #   --disable-python   configure.ac:111-125 `--enable-python` is opt-in, and
  #                      the cython probe at :96 only matters when it is on;
  #                      named off so no host python/cython changes the build.
  #   AX_CODE_COVERAGE   :141 defaults off (`--enable-code-coverage` is opt-in).
  #   gperf              :126-129 REQUIRED (a build dependency above).
  # LT_INIT([shared pic-only]) (:59) builds the shared library; a static
  # archive is also built by default and is left as upstream makes it.
  script = [
    "./configure --prefix={{prefix}} --disable-python",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

provides = [
  "bin/scmp_sys_resolver",
]

test {
  dependencies = {
    "gnu.org/gcc"                = "*"
    "freedesktop.org/pkg-config" = "*"
  }

  script = [
    "test -f {{prefix}}/include/seccomp.h",
    "pkg-config --exists libseccomp",
    "test \"$(pkg-config --modversion libseccomp)\" = \"{{version.raw}}\"",
    # The resolver maps a syscall name to its number for the native arch.
    "scmp_sys_resolver write",
    {
      fixture = {
        content  = <<EOT
#include <seccomp.h>
#include <stdio.h>

int main(void) {
  scmp_filter_ctx ctx = seccomp_init(SCMP_ACT_ALLOW);
  if (ctx == NULL) {
    puts("seccomp_init failed");
    return 1;
  }
  /* Building a filter and exporting it as pseudo-filter-code does not load it
     into the kernel, so it works in any sandbox. */
  if (seccomp_rule_add(ctx, SCMP_ACT_KILL, SCMP_SYS(reboot), 0) != 0) {
    puts("seccomp_rule_add failed");
    return 1;
  }
  if (seccomp_export_pfc(ctx, 1) != 0) {
    puts("seccomp_export_pfc failed");
    return 1;
  }
  seccomp_release(ctx);
  return 0;
}
EOT
        extname = "c"
      }
      run = "gcc $FIXTURE -o filter $(pkg-config --cflags --libs libseccomp)"
    },
    "./filter",
  ]
}

provenance {
  read = [
    "configure.ac", # :22 version; :59 LT_INIT shared pic-only; :96 cython probe; :111-125 --enable-python opt-in; :126-129 gperf required; :146-149 libseccomp.pc and include/seccomp.h
    "LICENSE",      # the GNU Lesser General Public License 2.1 text
  ]

  consulted = [
    "libseccomp-2.6.2.tar.gz.SHA256SUM", # the project's own checksum file: the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform (linux is the only platform).

The release carries a detached signature (.asc) and a signed checksum file; the
key was not fetched, so the signature is unverified and the project's plain
.SHA256SUM, which matches the pinned digest, is the second witness.
EOT
}
