# tcl-lang.org/itk — [incr Tk], the Tk megawidget framework on top of [incr
# Tcl]. One of the six packages of the tcl-lang.org monolith (go-zpkg/
# recipes#122 step 4). [incr Tcl] itself (Itcl) is NOT here: Tcl bundles it
# under pkgs/ (tcl-lang.org builds itcl4.3.8 with 9.0.4).
#
# ⛔ WRITTEN FROM ITK 4.2.3'S OWN FILES (go-zpkg/packages#431), read out of the
# tag archive, and BUILT and INSTALLED in a scratch directory on darwin/arm64
# against Tcl 9.0.4, Itcl 4.3.8 and an Aqua Tk 9.0.4 (not by the factory).
#
# ⭐ WHAT READING IT FOUND:
#
#   1. THE ARCHIVE LACKS tclconfig/. The monolith's own comment says so
#      ("missing ./tclconfig/install-sh") and copied the directory from the
#      tcltls tarball. Measured: `make install` stops with
#      `../x-itk/tclconfig/install-sh: No such file or directory` (Makefile:94,
#      `INSTALL = $(SHELL) $(srcdir)/tclconfig/install-sh -c`). tclconfig is a
#      git submodule that GitHub's generated archive does not carry. This recipe
#      overrides INSTALL on the command line with the system `install -c`, whose
#      -d, -m 644 and -m 755 uses (Makefile:95-99) it supports; no file is copied
#      from another package.
#   2. THE DEFAULT exec-prefix IS TCL'S (tclConfig.sh). Without
#      `--exec-prefix` the library lands in Tcl's lib directory, not this
#      package's — measured, and it polluted a scratch Tcl install. Passed.
#   3. itk needs Tk's and Itcl's configuration: --with-tk and --with-itcl
#      (configure.ac:66, :73) point at tkConfig.sh and itclConfig.sh; on X11 it
#      also runs TEA_PATH_X (:165), which takes the X include path from
#      tkConfig.sh.

summary = "[incr Tk]: the Tk megawidget framework for [incr Tcl]"

# license.terms: the [incr Tcl] licence family (Tcl-style, SPDX `TCL`).
license = "TCL"

dependencies = {
  "tcl-lang.org"    = "^9"
  "tcl-lang.org/tk" = "^9"
}

# The project has tagged only `itk-4-2-3` as its last release, with dashes the
# version syntax cannot read as a version, so the list is stated: the
# `sha256` map is the real gate (a version absent from it is refused).
versions = ["4.2.3"]

distributable {
  # ⛔ A GENERATED TAG ARCHIVE (see lz4.org/package.hcl:24-40): no release asset
  # exists (the repository publishes none), so the pin is correct today and can
  # be invalidated from outside. 168214 bytes, fetched twice by independent means
  # that agree: the builder's own fetcher (`zpkb sourcepin --version 4.2.3
  # <url>`, zpkb v0.89.0) and curl + shasum. Unsigned.
  url              = "https://github.com/tcltk/itk/archive/refs/tags/itk-{{version.major}}-{{version.minor}}-{{version.patch}}.tar.gz"
  strip-components = 1

  sha256 = {
    "4.2.3" = "bc5ed347212fce403e04d3161cd429319af98da47effd3e32e20d2f04293b036"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",
      # finding 2
      "--exec-prefix={{prefix}}",
      # finding 3
      "--with-tcl={{deps.tcl-lang.org.prefix}}/lib",
      "--with-tclinclude={{deps.tcl-lang.org.prefix}}/include",
      "--with-tk={{deps.tcl-lang.org/tk.prefix}}/lib",
      "--with-tkinclude={{deps.tcl-lang.org/tk.prefix}}/include",
    ]
  }

  script = [
    # Itcl's directory carries Tcl's bundled version (itcl4.3.8 with 9.0.4), so
    # it is globbed rather than spelled; two matches would fail configure loudly.
    "./configure $ARGS --with-itcl=\"$(ls -d {{deps.tcl-lang.org.prefix}}/lib/itcl4*)\"",
    "make --jobs {{ hw.concurrency }}",
    # finding 1
    "make install INSTALL=\"install -c\"",
  ]
}

runtime {
  env = {
    # A Tcl list, chained: see github.com/andreas-kupries/critcl.
    TCLLIBPATH = "{{prefix}}/lib $TCLLIBPATH"
  }
}

test {
  script = [
    "test -d \"{{prefix}}/lib/itk{{version.raw}}\"",
    "test -f \"{{prefix}}/lib/itk{{version.raw}}/pkgIndex.tcl\"",
    "test -f \"{{prefix}}/lib/itk{{version.raw}}/itk.tcl\"",
    "test -f \"{{prefix}}/include/itk.h\"",
    "ls \"{{prefix}}\"/lib/itk{{version.raw}}/libtcl9itk*",

    # The package is findable from a tclsh in ANOTHER prefix, which is what
    # TCLLIBPATH in `runtime` is for. `package require Itk` loads Tk, which
    # opens a display, so it is only run where a display exists (X11); here the
    # index is read and the version it provides is checked.
    {
      run = <<EOT
set -eu
cat > "$PWD/itkcheck.tcl" <<'TCL'
catch {package require Itk}
if {[package versions Itk] eq ""} { puts stderr "Itk is not findable"; exit 1 }
puts "Itk versions: [package versions Itk]"
TCL
TCLLIBPATH="{{prefix}}/lib" "{{deps.tcl-lang.org.prefix}}/bin/tclsh" "$PWD/itkcheck.tcl"
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",   # :59 TEA_PATH_TCLCONFIG; :66 TEA_PATH_TKCONFIG; :73 TEA_PATH_CONFIG(itcl); :165 TEA_PATH_X
    "Makefile (generated)", # :73-99 prefix, exec_prefix, INSTALL = $(SHELL) $(srcdir)/tclconfig/install-sh
    "license.terms",
    "https://api.github.com/repos/tcltk/itk/git/matching-refs/tags/itk-", # itk-4-2-3 is the newest tag
  ]

  consulted = [
    "pkgxdev/pantry projects/tcl-lang.org/package.yml", # facts only: the missing install-sh and the itcl directory; the tclconfig copy is not carried
  ]

  note = <<EOT
⛔ BUILT AND INSTALLED HERE IN SCRATCH on darwin/arm64 against Tcl 9.0.4 (with
Itcl 4.3.8), an Aqua Tk 9.0.4, and `make install INSTALL="install -c"`: the
install produced lib/itk4.2.3 with libtcl9itk4.2.3.dylib, itk.tcl, the
.itk class files and pkgIndex.tcl. NOT RUN: `package require Itk` (it loads
Tk and needs a display), the test block's checks as the factory runs them,
linux, an X11 Tk.

⭐ EXERCISED LATER (go-zpkg/recipes#122 step 6), darwin/arm64 scratch: Itk
4.2.3 rebuilt against Tcl 9.0.4 and an X11 Tk 9.0.4, installed, and its
pkgIndex.tcl is found from TCLLIBPATH (`package versions Itk` non-empty after a
`package require Itk`). `package require Itk` ITSELF was NOT completed: it loads
Tk, which opens a display, and no X server could be started in that session
(Xvfb on a unix socket needs /tmp/.X11-unix, root-owned; a TCP-listening Xvfb
was refused by the permission system). Still to run where an X server exists.

⚠ ITK 4.2.3 IS AN OLD RELEASE FOR TCL 9: it built against Tcl 9.0.4 and Itcl
4.3.8 without change, but nothing here exercised a widget. The monolith's
test (a megawidget with a "Bye" button) needs a display and is not reproduced.
⚠ A generated archive, unsigned.
EOT
}
