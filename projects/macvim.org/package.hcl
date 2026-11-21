# macvim.org — MacVim, Vim as a native macOS application (MacVim.app) and its
# `mvim` launcher.
#
# ⛔ WRITTEN FROM MACVIM'S OWN FILES (go-zpkg/packages#440), at release-184.
# macOS ONLY: `--enable-gui=macvim` drives `xcodebuild` (src/Makefile:3894-3895),
# so there is no Linux build and `platforms` says so. Xcode is the host's, not a
# recipe in this tree.

summary = "MacVim: Vim for macOS, as a native application with the mvim launcher"

platforms = ["darwin"]

# LICENSE:1 `VIM LICENSE`, the Vim licence text, which MacVim inherits.
license = "Vim"

versions {
  github = "macvim-dev/macvim/tags"
  strip  = ["/^release-/"]
}

dependencies = {
  # src/configure.ac:4326-4344 libsodium (for :X encryption), default "maybe",
  # found through pkg-config.
  "libsodium.org" = "*"
  # --with-tlib=ncurses, named below: the terminal library of the console half.
  "invisible-island.net/ncurses" = "*"
  # configure.ac:4998 --enable-nls; libintl is not in macOS's libc.
  "gnu.org/gettext" = "^1"
}

distributable {
  # The GitHub archive of the tag: the repository has no source release asset
  # (its assets are MacVim.dmg and delta files, binaries). src/auto/configure is
  # committed, so no autoconf is needed.
  url              = "https://github.com/macvim-dev/macvim/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 29705100 bytes, fetched with `zpkb sourcepin`; a second, independent fetch
  # (curl, then shasum -a 256) gave the same digest. 184 is the newest release
  # `zpkb versions` resolves. NOT SIGNED: the project publishes neither a
  # signature nor a checksum file for the source.
  sha256 = {
    "184" = "af1467e2d4c360bb8934815ac31259918f25f32b4787aaf9955443f14dc58bbd"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/make"               = "*"
  }

  env = {
    ARGS = [
      "--with-features=huge",
      # configure.ac:2378-2385 --enable-cscope, default YES: it only defines
      # ENABLE_CSCOPE and runs the `cscope` command when the user asks. OFF:
      # this tree has no cscope recipe, so nothing could answer :cscope.
      "--disable-cscope",
      # configure.ac:718-720 --enable-luainterp, default no. OFF, named: this
      # tree has no lua recipe (the old fragment named "lua.org", which does not
      # exist).
      "--enable-luainterp=no",
      # Each other interpreter is default no too, and named OFF: their dynamic
      # builds need the DLL path of a host install (macvim-buildtest.yaml:180-186
      # sets vi_cv_* variables for exactly that), which a prefix-relative build
      # cannot state. configure.ac:1225 perl, :1414 python2, :1658 python3,
      # :2107 tcl, :2251 ruby.
      "--enable-perlinterp=no",
      "--enable-pythoninterp=no",
      "--enable-python3interp=no",
      "--enable-tclinterp=no",
      "--enable-rubyinterp=no",
      # configure.ac:4326-4331: libsodium ON, from the dependency above.
      "--enable-libsodium=yes",
      "--enable-nls=yes",
      "--with-tlib=ncurses",
      "--enable-netbeans",
      # configure.ac:2860 the macOS GUI.
      "--enable-gui=macvim",
      # configure.ac:266-275 --disable-sparkle: no self-updating application in
      # a package manager's prefix; it also sets REMOVE_SPARKLE=1, so the
      # Sparkle framework in the tree is not bundled.
      "--disable-sparkle",
      # configure.ac:110-112: refuse a feature whose library is missing instead
      # of building without it, which is what the CI of the project passes.
      "--enable-fail-if-missing",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{hw.concurrency}}",
    {
      # The app bundle is the product (src/Makefile:3894 `macvim:` target, built
      # to src/MacVim/build/Release, macvim-buildtest.yaml:54-55). `mvim` is the
      # launcher in its Contents/bin: it dereferences its own symlink and takes
      # ../MacOS/Vim (src/MacVim/mvim:14-22), so a link into the bundle works.
      run = <<EOT
set -eu
mkdir -p "{{prefix}}/bin"
cp -R src/MacVim/build/Release/MacVim.app "{{prefix}}/MacVim.app"
ln -s ../MacVim.app/Contents/bin/mvim "{{prefix}}/bin/mvim"
EOT
    },
  ]
}

provides = [
  "bin/mvim",
]

test {
  script = [
    # The Vim binary inside the bundle, run without a terminal (the project's
    # own smoke test, macvim-buildtest.yaml:296-297).
    "test -x {{prefix}}/MacVim.app/Contents/MacOS/Vim",
    "mvim -v --version",
    "mvim -v -u NONE -i NONE --not-a-term -esNX -c 'call writefile([\"ok\"], \"out.txt\")' -c quit",
    "test \"$(cat out.txt)\" = ok",
  ]
}

provenance {
  read = [
    "src/configure.ac",                          # :110 fail-if-missing; :266-275 sparkle; :718 lua; :1225 perl; :1414 python2; :1658 python3; :2107 tcl; :2251 ruby; :2378-2385 cscope; :2860 gui; :4326-4344 libsodium; :4998 nls
    "src/Makefile",                              # :3875 RUNTIME_FOLDER_LIST; :3894-3895 the `macvim:` target, xcodebuild
    "src/MacVim/mvim",                           # :14-22 locates ../MacOS/Vim through symlinks
    ".github/workflows/macvim-buildtest.yaml",   # :54-55 the product path; :212-220 the project's own configure flags; :292 make; :296 smoke test
    "LICENSE",                                   # :1 VIM LICENSE
    "README.md",                                 # :59-63 mvim command; build guide on the wiki
  ]

  consulted = [
    "pkgxdev/pantry projects/macvim.org/package.yml",
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the test
block has been run. It needs Xcode (xcodebuild) on the host, and was never
tried against a recipe-built toolchain.

⛔ THE OLD FRAGMENT'S INTERPRETERS ARE OFF, ALL NAMED. lua.org and cscope have no
recipe in this tree, so --enable-luainterp=no and --disable-cscope. Ruby and
Python (both exist here) are off too: the project's own release build loads
them dynamically from host paths (macvim-buildtest.yaml:165-186), which has no
prefix-relative equivalent. Turning them on is a separate, measured change.

The release assets are binaries (MacVim.dmg), so the tag archive is the source.
The version string is the tag's number: release-184 is version 184.
EOT
}
