# tcl-lang.org/expect — Expect, Don Libes's tool for scripting interactive
# programs through a pty (`spawn`, `expect`, `send`), as a Tcl 8.6 extension and
# a `expect` interpreter. One of the packages of the tcl-lang.org monolith
# (go-zpkg/recipes#122 step 5); it was `tcl.tk/expect`'s sibling and named
# `tcl.tk/tcl ^8`, which is now `tcl-lang.org ^8`.
#
# ⛔ WRITTEN FROM EXPECT 5.45.4'S OWN FILES (go-zpkg/packages#431), read out of
# the release tarball, and BUILT, INSTALLED and RUN in a scratch directory on
# darwin/arm64 against Tcl 8.6.18 built from the core recipe (not by the
# factory, not on linux).
#
# ⭐ WHAT READING IT FOUND:
#
#   1. THE SHIPPED configure CANNOT RUN HERE. It is generated from 2003-era
#      autoconf with a config.sub that does not know darwin 27 ("config.sub
#      -apple-darwin27.2.0 failed", measured), so the recipe runs
#      `autoreconf --force --install` first, as the pantry's does.
#   2. ITS FEATURE TESTS ARE K&R C. configure.in:715-721, :740-745, :757-767 and
#      the TCGETS probe at :779 compile `main()` with no return type and call
#      `exit` undeclared. Clang 16+ and GCC 14 reject implicit int, the probes
#      all "fail", and the failure is SILENT until `could not find source file
#      'pty_.c'` (measured: every pty probe answered no). `-Wno-implicit-int
#      -Wno-implicit-function-declaration` is therefore passed on BOTH
#      platforms; the pantry passed the second only on darwin.
#   3. THE PTY DRIVER IS PICKED BY THOSE PROBES (configure.in:1013 compiles
#      `pty_${PTY_TYPE}.c`), so a wrong answer is a build that either stops or
#      links a driver for another system. The test spawns a real process on a
#      pty and reads what it printed.
#   4. THE LIBRARY LANDS IN lib/expect5.45.4/ BUT THE BINARY LOOKS IN lib/. TEA
#      installs libexpect into `$(libdir)/expect5.45.4` (Makefile pkglibdir),
#      while the binary's rpath is `$(exec_prefix)/lib` (LIB_RUNTIME_DIR) and,
#      on darwin, its reference to the dylib is the BARE name
#      `libexpect5.45.4.dylib` (no install_name is set; measured with otool:
#      "Library not loaded: libexpect5.45.4.dylib"). So the script moves the
#      library and pkgIndex.tcl up into lib/, as the pantry does, and on darwin
#      rewrites the dylib's id and the binary's reference to the absolute path.
#
# ⛔ NOT DONE, WITH THE REASON: Expect's Tk scripts (`tkpasswd`, `tknewsbiff`:
# `package require Tk` under `tclsh`, example/tkpasswd:6-7) need a Tk that
# loads into Tcl 8.6. tcl-lang.org/tk pins 9.0.4 only (Tk 9's pkgIndex refuses
# Tcl 8), so those two scripts cannot start. The `expect` binary and the other
# twenty programs do not use Tk. A gap, to close by pinning Tk 8.6.18 in
# tcl-lang.org/tk, not a decision that they are unwanted.

summary = "Expect: scripting of interactive programs through a pty, as a Tcl 8.6 extension"

# license.terms: "Therefore it is public domain. However, the author and NIST
# would appreciate credit" — no SPDX identifier fits.
license = "LicenseRef-Expect-public-domain"

platforms = ["linux", "darwin"]

dependencies = {
  # configure.in's TEA macros read tclConfig.sh; the extension loads into 8.6
  # (lib/pkgIndex.tcl:1 `vsatisfies [package provide Tcl] 8.6`).
  "tcl-lang.org" = "^8"
}

# The project's own release area on SourceForge, as the pantry listed it.
versions {
  match = "/Expect\\/\\d+(\\.\\d+)+\\//"
  strip = [
    "/^Expect\\//",
    "/\\/$/",
  ]
  url = "https://sourceforge.net/projects/expect/files/Expect/"
}

distributable {
  url              = "https://downloads.sourceforge.net/project/expect/Expect/{{version.raw}}/expect{{version.raw}}.tar.gz"
  strip-components = 1

  # 632363 bytes. Recorded with `zpkb sourcepin --version 5.45.4 <url>` (zpkb
  # v0.90.0) and confirmed by a second, independent fetch-and-hash (curl +
  # shasum). The release area carries no signature and no checksum file.
  sha256 = {
    "5.45.4" = "49a7da83b0bdd9f46d04a04deec19c7767bb9a323e40c4781f89caf760b92c34"
  }
}

build {
  dependencies = {
    "gnu.org/autoconf" = "*"
    "gnu.org/automake" = "*"
    "gnu.org/make"     = "*"
  }

  env = {
    # finding 2, on both platforms.
    CFLAGS = "-Wno-implicit-int -Wno-implicit-function-declaration"

    ARGS = [
      "--prefix={{prefix}}",
      "--exec-prefix={{prefix}}",
      "--with-tcl={{deps.tcl-lang.org.prefix}}/lib",
      "--with-tclinclude={{deps.tcl-lang.org.prefix}}/include",

      # ⛔ THE SWITCHES `./configure --help` LISTS, EACH NAMED OR REFUSED (5.45.4):
      #   --enable-shared     default on; the `expect` binary links libexpect.
      "--enable-shared",
      #   --enable-threads    left at what the TEA macros choose; the scratch
      #                       build compiled with -DTCL_THREADS=1 against the
      #                       threaded 8.6 (tclConfig.sh).
      #   --enable-64bit      REFUSED for the reason given in tcl-lang.org: a
      #                       platform-case selector that is a no-op on 64-bit
      #                       linux and darwin. --enable-64bit-vis (Sparc) and
      #                       --enable-wince / --with-celib (Windows CE): not
      #                       our targets.
      #   --disable-rpath     default on; kept (finding 4).
      #   --enable-symbols    default off.
      #   --with-tcl, --with-tclinclude: passed above. There is no --with-tk:
      #                       "With Tk request ignored - use package require Tk
      #                       & Expect" (configure.in:29).
      # No library probe in configure.in is optional: openpty/-lutil
      # (configure.in:212-214) is the only extra library, from libc or libutil.
    ]
  }

  script = [
    # finding 1.
    "autoreconf --force --install --verbose",
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",

    # finding 4.
    {
      run = <<EOT
set -eu
cd "{{prefix}}/lib"
mv expect{{version.raw}}/* .
rmdir expect{{version.raw}}
if [ "$(uname -s)" = Darwin ]; then
  lib="{{prefix}}/lib/libexpect{{version.raw}}.dylib"
  install_name_tool -id "$lib" "$lib"
  install_name_tool -change "libexpect{{version.raw}}.dylib" "$lib" "{{prefix}}/bin/expect"
  codesign --force -s - "$lib" "{{prefix}}/bin/expect"
fi
EOT
    },
  ]
}

# Makefile.in install-bin-binaries plus the example scripts it installs
# (read off the scratch install: twenty-two files in bin/).
provides = [
  "bin/autoexpect",
  "bin/autopasswd",
  "bin/cryptdir",
  "bin/decryptdir",
  "bin/dislocate",
  "bin/expect",
  "bin/ftp-rfc",
  "bin/kibitz",
  "bin/lpunlock",
  "bin/mkpasswd",
  "bin/multixterm",
  "bin/passmass",
  "bin/rftp",
  "bin/rlogin-cwd",
  "bin/timed-read",
  "bin/timed-run",
  "bin/tknewsbiff",
  "bin/tkpasswd",
  "bin/unbuffer",
  "bin/weather",
  "bin/xkibitz",
  "bin/xpstat",
]

runtime {
  env = {
    # A Tcl list, chained: see github.com/andreas-kupries/critcl.
    TCLLIBPATH = "{{prefix}}/lib $TCLLIBPATH"
  }
}

test {
  script = [
    "test -x \"{{prefix}}/bin/expect\"",
    "test -f \"{{prefix}}/lib/pkgIndex.tcl\"",
    "! test -d \"{{prefix}}/lib/expect{{version.raw}}\"",
    {
      run = <<EOT
set -eu
# The binary must find its own library by an absolute reference or its rpath.
case "$(uname -s)" in
  Darwin) otool -L "{{prefix}}/bin/expect" > deps.txt
          grep -q -e "{{prefix}}/lib/libexpect{{version.raw}}.dylib" deps.txt ;;
esac
# finding 3: a real process on a real pty, and the package from tclsh 8.6.
cat > "$PWD/expcheck.exp" <<'EXP'
spawn echo hello-from-pty
expect {
  "hello-from-pty" { }
  timeout { puts stderr "no output through the pty"; exit 1 }
}
expect eof
if {[package require Expect] ne "{{version.raw}}"} { puts stderr "wrong Expect"; exit 1 }
if {![string match "8.6.*" [info patchlevel]]} { puts stderr "not Tcl 8.6"; exit 1 }
puts "Expect [package present Expect] on Tcl [info patchlevel]"
EXP
TCLLIBPATH="{{prefix}}/lib" "{{prefix}}/bin/expect" "$PWD/expcheck.exp"
# The example scripts `exec tclsh` (example/timed-read:4): the 8.6 one.
test "$(echo 'Hello, World!' | PATH="{{deps.tcl-lang.org.prefix}}/bin:$PATH" TCLLIBPATH="{{prefix}}/lib" "{{prefix}}/bin/timed-read" 1)" = 'Hello, World!'
EOT
    },
  ]
}

provenance {
  read = [
    "configure.in",   # :26-29 no --with-tk; :115-135 headers; :203-214 openpty; :706-775 the K&R probes that choose the pty type; :779 the TCGETS probe; :1013 pty_${PTY_TYPE}.c
    "configure --help",
    "Makefile.in",    # :225-231 install targets; :526 install-lib-binaries; :571 install-bin-binaries
    "license.terms",  # public domain, credit appreciated
    "example/tkpasswd",
    "example/tknewsbiff",
    "https://sourceforge.net/projects/expect/files/Expect/",
  ]

  consulted = [
    # Facts only: autoreconf's need, the mv out of expect<version>/, the darwin
    # flag. The linux flag is widened and the darwin id rewrite is new.
    "pkgxdev/pantry projects/tcl-lang.org/expect/package.yml",
  ]

  note = <<EOT
⛔ BUILT AND RUN HERE ON DARWIN/ARM64 ONLY, against Tcl 8.6.18 built from the
core recipe; NOT by the factory and NOT on linux. Measured: the shipped
configure failed on config.sub (run there with a current config.sub copied in
for lack of autoreconf on this host, which is what `autoreconf --install`
installs); with the two -Wno flags the pty probes answered and configure
finished; `make install` put the library in lib/expect5.45.4; after the move
and the id rewrite, `expect` ran a script that spawned `echo` on a pty, matched
its output, and `package require Expect` answered 5.45.4 on Tcl 8.6.18. NOT RUN:
`autoreconf` itself, linux, the factory, the Tk scripts, and the recipe text as
the factory executes it.

⚠ No signature and no checksum exist for the release; the digest is two
independent fetches.
EOT
}
