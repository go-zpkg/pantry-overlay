# nixos.org/patchelf — edits the dynamic linker and RPATH of ELF executables
# and libraries. One of the projects the base-toolchain closure needed and this
# tree did not carry at all (`zpkb closure -build -require-standalone
# go-zpkg/base-toolchain`, 2026-11-20).
#
# ⛔ WRITTEN FROM PATCHELF'S OWN FILES (go-zpkg/packages#431), at 0.19.3.
#
# ⭐ NOTHING HERE IS CHOSEN BY DETECTION, and that was checked rather than
# assumed. The only build-time choice is the page size, and its default `auto`
# is NOT a probe of the builder — see `build`.

summary = "Modify the dynamic linker and RPATH of ELF executables"

# README.md:128-141: "either version 3 of the License, or (at your option) any
# later version"; COPYING is the GPL version 3 text.
license = "GPL-3.0-or-later"

versions {
  # Release tags are the bare version (`0.19.3`).
  github = "NixOS/patchelf"
}

distributable {
  # The `make dist` tarball attached to the release. It carries `configure`,
  # so no autotools are needed to build. Not the tag's source archive, which
  # GitHub generates and does not carry `configure`.
  url              = "https://github.com/NixOS/patchelf/releases/download/{{version.raw}}/patchelf-{{version.raw}}.tar.gz"
  strip-components = 1

  # 492713 bytes. Recorded with `zpkb sourcepin` and confirmed by a second,
  # independent fetch-and-hash. NO SIGNATURE: see provenance.note.
  sha256 = {
    "0.19.3" = "fac76a3c0b730e8d53ea1d10cd6015322d78c9900af91736f2cca51d5837b612"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⭐ --with-page-size IS LEFT AT ITS DEFAULT, ON PURPOSE. configure.ac:21-30
      # defaults it to `auto` and only a NUMBER defines DEFAULT_PAGESIZE. With it
      # undefined, src/patchelf.cc:382-406 picks the page size for each FILE it
      # edits, from that file's e_machine (64 KiB for aarch64, ppc64, mips,
      # loongarch…, 8 KiB for sparc, 4 KiB otherwise). So `auto` reads the
      # input, not the builder, and the artifact is the same on every builder.
      # Pinning a number would be the mistake: it would apply one page size to
      # binaries of every architecture.
    ]
  }

  # configure.ac:37 `AX_CXX_COMPILE_STDCXX([17], [noext], [])` — a C++17
  # compiler is MANDATORY (an empty third argument), so a toolchain without
  # one fails at configure rather than building something else.
  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# src/Makefile.am `bin_PROGRAMS = patchelf`.
provides = [
  "bin/patchelf",
]

test {
  script = [
    "\"{{prefix}}/bin/patchelf\" --version | grep -F \"patchelf {{version}}\"",

    # The tool edits a copy of itself and reads the edit back. That exercises
    # the ELF rewrite, which is what the tool is for. patchelf only edits ELF,
    # so this runs where the artifact is an ELF file.
    {
      run = <<EOT
set -eu
case "$(uname -s)" in
Linux)
  cp "{{prefix}}/bin/patchelf" ./patchelf-copy
  "{{prefix}}/bin/patchelf" --set-rpath /zpkg/test/rpath ./patchelf-copy
  got=$("{{prefix}}/bin/patchelf" --print-rpath ./patchelf-copy)
  test "$got" = "/zpkg/test/rpath" || { echo "rpath read back as '$got'" >&2; exit 1; }
  ./patchelf-copy --version
  ;;
esac
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",    # :21-30 --with-page-size and its `auto` default; :37 C++17 mandatory
    "src/patchelf.cc", # :71-74 DEFAULT_PAGESIZE; :382-406 the page size per e_machine
    "src/Makefile.am", # bin_PROGRAMS
    "Makefile.am",     # man page, README and zsh completion installed
    "README.md",       # :86-89 the autotools build; :128-141 the licence
    "COPYING",
    "https://github.com/NixOS/patchelf/releases/tag/0.19.3", # the assets: tarballs, no signature, no checksum file
  ]

  note = <<EOT
⚠ THE RUNG IS A SINGLE HOST, STATED. The 0.19.3 release attaches a .tar.gz,
a .tar.bz2, prebuilt binaries and nothing else: no detached signature and no
checksum file (GitHub's API reports no digest for any asset). The release
commit 2b4b49d3 is "verified", but its committer is GitHub: that is GitHub's
web-flow signature on a merge made in its interface, and it vouches only for
GitHub, the same host the tarball comes from. So the digest records what
github.com served on 2026-11-20, fetched twice independently, and nothing more.

⛔ NOT BUILT. No session here can run the factory. What is established is the
inputs, each traced to a line in patchelf's own files.
EOT
}
