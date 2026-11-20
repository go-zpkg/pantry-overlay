# tcl-lang.org/tcllib — Tcllib, the standard Tcl library of pure-Tcl modules
# (md5, sha256, json, ...), with the C accelerators ("tcllibc") built with
# critcl. One of the six packages of the tcl-lang.org monolith (go-zpkg/
# recipes#122 step 4).
#
# ⛔ WRITTEN FROM TCLLIB 2.0'S OWN FILES (go-zpkg/packages#431), read out of the
# release tarball, and BUILT, INSTALLED and EXERCISED in a scratch directory on
# darwin/arm64 against Tcl 9.0.4 and critcl 3.3.1 (not by the factory).
#
# ⭐ WHAT READING IT FOUND:
#
#   1. configure takes ONE option of its own: `--with-tclsh=FILE`. Left alone it
#      searches PATH for a tclsh, so the interpreter that runs the installer
#      would depend on the builder. It is passed.
#   2. The accelerators are NOT part of `make install`: Makefile.in:103-104
#      `critcl:` runs `sak.tcl critcl`, which looks for a critcl next to the
#      running tclsh and otherwise on PATH, and a miss is `error: cannot find a
#      critcl to run.` (sak.tcl:1591). The pantry ran `make critcl` and copied
#      the result by hand; this recipe declares critcl as a build dependency,
#      puts it on PATH, and the test asserts `package require tcllibc` loaded.
#      Skipping the accelerators would be a silent loss of speed, not an error.
#   3. installer.tcl:12 already reads `package require Tcl 8.5 9`; the pantry's
#      `sed` over installer.tcl is not carried.

summary = "Tcllib: the standard library of Tcl modules, with C accelerators"

# license.terms: "This software is copyrighted by Ajuba Solutions and other
# parties … the same terms as Tcl/Tk": SPDX `TCL`.
license = "TCL"

dependencies = {
  "tcl-lang.org" = "*"
}

# SourceForge lists the releases (2.0 is the newest; 1.21 the previous).
versions {
  url   = "https://sourceforge.net/projects/tcllib/files/tcllib/"
  match = "/tcllib\\/\\d+(\\.\\d+)+\\//"
  strip = [
    "/^tcllib\\//",
    "/\\/$/",
  ]
}

distributable {
  # A stored release tarball (not a generated archive), so the pin is stable.
  # 14872556 bytes, fetched twice by independent means that agree: the
  # builder's own fetcher (`zpkb sourcepin --version 2.0 <url>`, zpkb v0.89.0)
  # and curl + shasum. Unsigned: SourceForge publishes none for this release.
  url              = "https://downloads.sourceforge.net/project/tcllib/tcllib/{{version.raw}}/tcllib-{{version.raw}}.tar.xz"
  strip-components = 1

  sha256 = {
    "2.0" = "642c2c679c9017ab6fded03324e4ce9b5f4292473b62520e82aacebb63c0ce20"
  }
}

build {
  dependencies = {
    "gnu.org/make"                      = "*"
    "github.com/andreas-kupries/critcl" = "*"
  }

  # (Each line is its own shell, as in the gcc recipe.)
  script = [
    "./configure --prefix=\"{{prefix}}\" --with-tclsh=\"{{deps.tcl-lang.org.prefix}}/bin/tclsh\"",
    "make install",
    "PATH=\"{{deps.github.com/andreas-kupries/critcl.prefix}}/bin:{{deps.tcl-lang.org.prefix}}/bin:$PATH\" make critcl",
    "cp -r modules/tcllibc \"{{prefix}}/lib/\"",
  ]
}

runtime {
  env = {
    # A Tcl list, chained: see github.com/andreas-kupries/critcl.
    TCLLIBPATH = "{{prefix}}/lib $TCLLIBPATH"
  }
}

# Makefile.in's install puts these scripts in bin/ (read off the scratch
# install): the documentation and tooling programs of the library.
provides = [
  "bin/dtplite",
  "bin/mkdoc",
  "bin/nns",
  "bin/nnsd",
  "bin/nnslog",
  "bin/page",
  "bin/pt",
  "bin/tcldocstrip",
]

test {
  script = [
    "test -d \"{{prefix}}/lib/tcllib{{version.raw}}\"",

    # The accelerators, asserted: loaded, not merely present on disk.
    {
      run = <<EOT
set -eu
cat > "$PWD/tcllibcheck.tcl" <<'TCL'
package require sha256
package require json
package require tcllibc
set d [::json::json2dict "{\"a\": \[1, 2, 3\]}"]
if {[dict get $d a] ne "1 2 3"} { puts stderr "json: $d"; exit 1 }
if {[::sha2::sha256 -hex abc] ne "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"} { puts stderr sha256; exit 1 }
set found 0
foreach l [info loaded] { if {[string match *tcllibc* [lindex $l 0]]} { set found 1 } }
if {!$found} { puts stderr "tcllibc accelerators not loaded: [info loaded]"; exit 1 }
puts "tcllib ok, accelerators loaded"
TCL
TCLLIBPATH="{{prefix}}/lib" "{{deps.tcl-lang.org.prefix}}/bin/tclsh" "$PWD/tcllibcheck.tcl"
EOT
    },
  ]
}

provenance {
  read = [
    "configure --help",  # the only own option: --with-tclsh=FILE
    "Makefile.in",       # :64 and :103-104 the `critcl` target
    "sak.tcl",           # :1540-1602 how it finds critcl; :1591 the miss
    "installer.tcl",     # :12 package require Tcl 8.5 9
    "license.terms",
    "https://sourceforge.net/projects/tcllib/files/tcllib/",
  ]

  consulted = [
    "pkgxdev/pantry projects/tcl-lang.org/package.yml", # facts only: `make critcl` and the copy of modules/tcllibc; the installer.tcl sed is dead
  ]

  note = <<EOT
⛔ BUILT AND RUN HERE IN SCRATCH: configure, `make install`, `make critcl` (with
critcl 3.3.1 on PATH) and the copy of modules/tcllibc, on darwin/arm64 against
Tcl 9.0.4; the check script above loaded the accelerators (info loaded lists
tcllibc) and passed. Not run: linux, the factory, an 8.6 Tcl.

⚠ A C compiler is needed at build time for the accelerators (not declarable).
⚠ Unsigned; the digest is a stored release tarball, confirmed by two fetches.
EOT
}
