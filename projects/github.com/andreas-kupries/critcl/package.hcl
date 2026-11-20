# github.com/andreas-kupries/critcl — CriTcl, "C Runtime In Tcl": a compiler
# front end that turns C embedded in a Tcl script into a loadable extension.
# tcllib's C accelerators are built with it. Split out of the tcl-lang.org
# monolith (go-zpkg/recipes#122) and given the project's OWN name: critcl is not
# a Tcl release, the monolith filed it under `tcl-lang.org/` for convenience.
#
# ⛔ WRITTEN FROM CRITCL 3.3.1'S OWN FILES (go-zpkg/packages#431), read out of
# the tag archive, and BUILT, INSTALLED and EXERCISED in a scratch directory on
# darwin/arm64 against Tcl 9.0.4 (not by the factory).
#
# ⭐ WHAT READING IT FOUND:
#
#   1. The pantry's `sed -i "s|package require Tcl 8.6.9$|…|" build.tcl` is
#      DEAD for this version: build.tcl:4 already reads
#      `package require Tcl 8.6 9`, so it accepts Tcl 8.6 and 9 as shipped. Not
#      carried.
#   2. build.tcl installs under `--prefix` (:234-241), defaulting to the
#      directory two levels above the tclsh that runs it (:187-192): without the
#      flag a build of this package would install INTO TCL'S PREFIX, which is
#      the next recipe's directory. The flag is passed.
#   3. critcl compiles C at INSTALL time (critcl::md5c and critcl::callback are
#      built by `install`, build.tcl log) and at USE time, so it needs a C
#      compiler on the consumer's machine. That is not a dependency this tree
#      can declare (the compiler is the host's), and it is named in the test.

summary = "CriTcl: embed C in Tcl scripts and build loadable extensions"

# license.terms: the Tcl/Tk-style licence the Tcl community uses, SPDX `TCL`.
license = "TCL"

dependencies = {
  # build.tcl:4 `package require Tcl 8.6 9`.
  "tcl-lang.org" = "*"
}

# The project tags plain `3.3.1`, with non-version tags among them
# (`scalar-basic-limits`, `nmhm`, `kinetcl-match-…`): only dotted numbers.
versions {
  github = "andreas-kupries/critcl/tags"
  ignore = ["/^[^0-9]/"]
}

distributable {
  # ⛔ A GENERATED TAG ARCHIVE, NOT A STORED ASSET, AND THAT IS A STATED WEAKNESS
  # (see lz4.org/package.hcl:24-40): GitHub builds this tarball on request and
  # its bytes have changed before. critcl publishes no release asset (the
  # repository has no releases), and the project's fossil mirror serves
  # generated tarballs too, so no byte-stable source exists. The pin is correct
  # today and can be invalidated from outside; a stored copy under our own
  # mirror is the fix, not made here.
  url              = "https://github.com/andreas-kupries/critcl/archive/refs/tags/{{version.raw}}.tar.gz"
  strip-components = 1

  # 1668937 bytes. Fetched twice by independent means that agree: the builder's
  # own fetcher (`zpkb sourcepin --version 3.3.1 <url>`, zpkb v0.89.0) and
  # curl + shasum. Unsigned: no signature is published.
  sha256 = {
    "3.3.1" = "d970a06ae1cdee7854ca1bc571e8b5fe7189788dc5a806bce67e24bbadbe7ae2"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  script = [
    "\"{{deps.tcl-lang.org.prefix}}/bin/tclsh\" build.tcl install --prefix \"{{prefix}}\"",
  ]
}

runtime {
  env = {
    TCLLIBPATH = "{{prefix}}/lib"
  }
}

provides = [
  "bin/critcl",
]

test {
  script = [
    "test -x \"{{prefix}}/bin/critcl\"",
    "test \"$(\"{{prefix}}/bin/critcl\" -v)\" = \"{{version.raw}}\"",

    # The whole point: critcl compiles C and the result runs. Needs a C
    # compiler on the builder (finding 3).
    {
      run = <<EOT
set -eu
cat > "$PWD/critclcheck.tcl" <<'TCL'
package require critcl
critcl::cproc add {int a int b} int { return a + b; }
if {[add 40 2] != 42} { puts stderr "critcl cproc"; exit 1 }
puts "critcl [package present critcl] compiled and ran C"
TCL
TCLLIBPATH="{{prefix}}/lib" "{{deps.tcl-lang.org.prefix}}/bin/tclsh" "$PWD/critclcheck.tcl"
EOT
    },
  ]
}

provenance {
  read = [
    "build.tcl",   # :4 package require Tcl 8.6 9; :187-241 the --prefix default and options; install log shows the C packages built at install
    "license.terms",
    "README.md",
    "https://api.github.com/repos/andreas-kupries/critcl/releases", # empty: no release asset exists
  ]

  consulted = [
    "pkgxdev/pantry projects/tcl-lang.org/package.yml", # facts only: the version and the dead sed
  ]

  note = <<EOT
⛔ BUILT AND RUN HERE IN SCRATCH: `tclsh9.0 build.tcl install --prefix P` on
darwin/arm64 against Tcl 9.0.4 installed the application and eighteen packages,
built critcl::md5c and critcl::callback, and `critcl -v` printed 3.3.1; a script
doing `critcl::cproc add` compiled C and returned 42. Not run: linux, the factory.

⚠ UNSIGNED, AND ONLY A GENERATED ARCHIVE EXISTS: see the distributable block.

⚠ TCLLIBPATH in `runtime` is how a separately installed extension is found by
a tclsh that lives in another prefix. The `runtime` schema key is validated by
`zpkb lint`; how the resolver merges the value across several extensions is not
exercised here.
EOT
}
