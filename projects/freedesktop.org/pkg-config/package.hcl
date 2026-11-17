# freedesktop.org/pkg-config — the compile/link-flag broker that ~100 recipes in
# this tree invoke, and the second-to-last member of
# go-zpkg/recipes#88's campaign.
#
# ⛔ WRITTEN FROM PKG-CONFIG'S OWN FILES (go-zpkg/packages#431), at 0.29.2.
# Eighth of today's eight: #126 through #132 took #88's measured gap from 9 to 2;
# this takes it to 1.
#
# ⛔⛔ AND IT CARRIES A FINDING THAT IS BIGGER THAN THE RECIPE: as packaged with
# upstream's defaults, pkg-config in THIS pantry cannot find any other package's
# `.pc` files, and nothing in the builder compensates. The whole measurement is
# in `provenance.note`; the short form is that the compiled-in default search
# path is pkg-config's OWN prefix, the two environment variables that would
# override it are set by nothing, and the failure is a silent "package not
# found" rather than an error anyone can trace.
#
# ⚠ One standing caveat about this project, stated because a reader will wonder:
# 0.29.2 is from 2017 and is the newest release — the upstream has published
# nothing since, and the wider world has largely moved to `pkgconf`. That is a
# question about what `go-zpkg/base-toolchain` should NAME, not about this
# recipe, which writes the member the set actually asks for.

summary = "pkg-config: the compile and link flag broker for libraries that ship .pc files"

# ⛔ READ FROM BOTH: COPYING is the GPL version 2 text, and main.c:6-7 is
# "either version 2 of the License, or (at your option) any later version".
license = "GPL-2.0-or-later"

versions {
  url   = "https://pkgconfig.freedesktop.org/releases/"
  match = "/pkg-config-\\d+\\.\\d+(\\.\\d+)?\\.tar\\.gz/"
  strip = [
    "/^pkg-config-/",
    "/\\.tar\\.gz$/",
  ]
}

distributable {
  # ⚠ `.tar.gz` and not `.tar.xz`: this project publishes only gzip, measured
  # from the release index. Every other recipe written today takes an xz.
  url              = "https://pkgconfig.freedesktop.org/releases/pkg-config-{{version.raw}}.tar.gz"
  strip-components = 1

  # 2016830 bytes. Two independent hash paths, one answer: the builder's own
  # fetcher and an independent `curl --fail` + `shasum -a 256`.
  #
  # ⚠⚠ THE SIGNATURE IS PUBLISHED AND COULD NOT BE CHECKED HERE, for a reason
  # that is new among today's recipes and is written out in `provenance.note`:
  # the signature predates the issuer-fingerprint subpacket, so it identifies
  # its key by a 64-BIT KEY ID ONLY, and the key material is not obtainable by
  # any route this fleet permits. The full fingerprint IS independently
  # published and does match that key id — which is identification, not
  # verification.
  sha256 = {
    "0.29.2" = "6fc69c01688c9458a57eb9a1664c9aba372ccda420a02bf4429fe610e7e7d591"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }
  # ⚠ NO glib DEPENDENCY, and that is the point of `--with-internal-glib` below
  # rather than an omission. ⚠ NO RUNTIME DEPENDENCIES EITHER: pkg-config is a
  # self-contained C program that reads text files, so there is no top-level
  # `dependencies` block at all.

  # ⛔ THE SWITCH CENSUS: eight, and unusually for this campaign every one of
  # them is substantive — there are no developer or test switches to pass over.
  #
  #   :58   --with-pc-path                 the compiled-in .pc search path
  #   :78   --with-system-include-path     paths whose -I flags are suppressed
  #   :90   --with-system-library-path     paths whose -L flags are suppressed
  #   :118  --enable-indirect-deps         list private deps on this platform
  #   :182  --enable-define_prefix         rewrite ${prefix} in .pc files
  #   :200  --with-internal-glib           use the bundled glib
  #   :226  --with-gcov                    coverage build
  #   :248  --enable-host-tool             install a $host- prefixed link
  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # ⛔⛔ REQUIRED, NOT PREFERRED, and the project's own error message is the
      # citation. configure.ac:203 defaults `with_internal_glib=no`, and the
      # `no` branch at :214-218 is a HARD ERROR whose text names the
      # circularity:
      #
      #   Either a previously installed pkg-config or "glib-2.0" could not be
      #   found. Please set GLIB_CFLAGS and GLIB_LIBS to the correct values or
      #   pass --with-internal-glib to configure to use the bundled copy.
      #
      # "a previously installed pkg-config" — finding external glib needs the
      # very tool being built. In a sovereign tree with no glib at all (it is
      # among the projects this overlay does not carry), configure simply fails.
      # The bundled copy is upstream's documented way out, and it also keeps
      # `gnome.org/glib` from becoming a fourth absent leaf after
      # rsync.samba.org, gnu.org/gettext and invisible-island.net/ncurses.
      "--with-internal-glib",

      # ⛔⛔ TWO HOST CONVENTIONS, STATED RATHER THAN INHERITED. These are the
      # paths whose `-I` and `-L` flags pkg-config SUPPRESSES, on the theory
      # that the compiler finds them anyway. Upstream's defaults are the
      # filesystem of a traditional distribution:
      #
      #   configure.ac:82   system_include_path="/usr/include"
      #   configure.ac:94-103  system_library_path derived from $libdir by sed,
      #                        giving "/usr/lib:/lib" or a multilib variant
      #
      # In a store-based tree those directories are not "the system" — they are
      # either absent (a from-scratch image) or they belong to the HOST, in
      # which case suppressing their flags hides exactly the paths a sovereign
      # build must not silently rely on. Set to the empty string so nothing is
      # suppressed and every flag a `.pc` file asks for is passed through.
      #
      # ⭐ Overridable at run time, which is why empty is safe rather than
      # brittle: pkg.c:771-775 and :851-855 read
      # `PKG_CONFIG_SYSTEM_INCLUDE_PATH` / `PKG_CONFIG_SYSTEM_LIBRARY_PATH` from
      # the environment and fall back to the compiled-in value only when unset.
      # Same shape as the `@M4@` default in go-zpkg/recipes#128.
      "--with-system-include-path=",
      "--with-system-library-path=",

      # ⛔ THE HOST-TRIPLET LINK, DISABLED, AND THE REASON IS `provides`.
      # configure.ac:248-252 defaults this to YES, and Makefile.am:35's
      # `if HOST_TOOL` then installs a second name prefixed with the autoconf
      # `$host` triplet — `x86_64-pc-linux-gnu-pkg-config` and friends. That
      # name differs per platform and per triplet spelling, and `provides` is a
      # static list: no recipe in this tree templates one, and
      # `build.ProvidedCommands` reduces by platform without expanding
      # moustache. Shipping a file this recipe cannot name is the same defect
      # go-zpkg/recipes#130 avoided by writing automake's APIVERSION
      # names out in full — except a triplet cannot be written out in full,
      # because it is not one value.
      #
      # ⚠ COST, STATED: a cross-build looking for `<triplet>-pkg-config` will
      # not find it. Nothing in this tree does today; the switch is one line to
      # flip if something starts to.
      "--disable-host-tool",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{ hw.concurrency }}",
    "make install",
  ]
}

# Read from Makefile.am:30, `bin_PROGRAMS = pkg-config`, and that is the whole
# list because `--disable-host-tool` above removes the only other installed
# name.
provides = [
  "bin/pkg-config",
]

test {
  script = [
    "\"{{prefix}}/bin/pkg-config\" --version",

    # ⛔⛔ THE ASSERTION THAT MAKES THE FINDING VISIBLE INSTEAD OF LATENT.
    # `--variable=pc_path` prints the compiled-in default search path
    # (pkg.c:197 inserts `pc_path` into the variable table). This step does not
    # FAIL on it — the value is upstream's default and this recipe deliberately
    # does not invent a store layout — but it PRINTS it, so the first real build
    # log carries the evidence rather than requiring someone to rediscover it.
    #
    # ⚠ Written as a print-and-check-non-empty rather than a comparison: pinning
    # the expected string here would be asserting a layout nobody has decided.
    {
      run = <<EOT
pc=$("{{prefix}}/bin/pkg-config" --variable=pc_path pkg-config)
echo "pkg-config compiled-in pc_path: $pc"
test -n "$pc"
EOT
    },

    # ⭐ AND THE ONE END-TO-END CHECK THAT IS POSSIBLE WITHOUT ANY OTHER
    # PACKAGE: pkg-config installs its own `pkg-config.pc`, so it can be asked
    # about itself. That exercises the parser, the variable table and the search
    # path together, which `--version` does not.
    {
      run = <<EOT
export PKG_CONFIG_LIBDIR="{{prefix}}/lib/pkgconfig:{{prefix}}/share/pkgconfig"
"{{prefix}}/bin/pkg-config" --exists pkg-config
v=$("{{prefix}}/bin/pkg-config" --modversion pkg-config)
echo "pkg-config knows itself as: $v"
test -n "$v"
EOT
    },

    # ⛔ THE REGRESSION WITNESS for the two emptied system paths. If a future
    # edit drops them, the binary goes back to carrying /usr/include and
    # /usr/lib, and a sovereign build would silently stop seeing flags it needs.
    {
      run = <<EOT
inc=$("{{prefix}}/bin/pkg-config" --variable=pc_system_includedirs pkg-config 2>/dev/null || true)
if printf '%s' "$inc" | grep -q '/usr/include'; then
  echo "pkg-config: /usr/include is back in the suppressed-include path" >&2
  echo "  configure.ac:82 defaults it; restore --with-system-include-path= in build.env." >&2
  exit 1
fi
EOT
    },
  ]
}

provenance {
  read = [
    "configure.ac",  # the eight-switch census; :58-70 the pc_path default; :78-84 and :90-106 the two host conventions; :200-218 internal-glib and its circular error; :248-254 host-tool defaulting to yes
    "Makefile.am",   # :16-22 how the system paths become -D defines; :30 bin_PROGRAMS; :35 the HOST_TOOL conditional
    "main.c",        # :6-7 GPL-2.0-or-later; :308-314 pc_path assembly; :511-531 PKG_CONFIG_PATH prepends, PKG_CONFIG_LIBDIR REPLACES, and the compiled-in default is used only when LIBDIR is unset
    "pkg.c",         # :197 pc_path in the variable table; :771-775 and :851-855 the env overrides for the two system paths
    "COPYING",       # the GPL version 2 text that ships
  ]

  consulted = [
    # Read for the signing key, and for the one thing it could settle.
    "archlinux/packaging/packages/pkg-config PKGBUILD (validpgpkeys, source, md5sums, depends)",
  ]

  note = <<EOT
⛔⛔ THE FINDING, AND IT IS LARGER THAN THIS RECIPE: AS PACKAGED, pkg-config IN
THIS PANTRY CANNOT FIND ANY OTHER PACKAGE'S .pc FILES, AND NOTHING COMPENSATES.

Three measurements, in the order they settle the question.

1. THE COMPILED-IN DEFAULT IS pkg-config's OWN PREFIX. configure.ac:62-70:

       if test "$${prefix}" = "NONE"; then
         pc_path='$${libdir}/pkgconfig:$${datadir}/pkgconfig:/usr/lib/pkgconfig:…'
       else
         pc_path='$${libdir}/pkgconfig:$${datadir}/pkgconfig'
       fi

   A recipe always passes `--prefix`, so the second branch applies and the
   baked path is `<this package's store entry>/lib/pkgconfig` plus its
   share/. Every other package's `.pc` files live in THEIR store entries.
   Upstream even flags the shape in a comment at :63-64: "This is slightly
   wrong, but hopefully causes less confusion…" — true on a distribution where
   one prefix holds everything, and false in a store.

2. THE TWO OVERRIDES THAT WOULD FIX IT ARE SET BY NOTHING. main.c:511-531:

       search_path = getenv ("PKG_CONFIG_PATH");          /* PREPENDS */
       …
       if (getenv("PKG_CONFIG_LIBDIR") != NULL)
           add_search_dirs(getenv("PKG_CONFIG_LIBDIR"), …);  /* REPLACES */
       else
           add_search_dirs(pkg_config_pc_path, …);           /* the baked one */

   So `PKG_CONFIG_LIBDIR` replaces the baked path outright and
   `PKG_CONFIG_PATH` prepends to it. Measured: `git grep PKG_CONFIG` over the
   whole of go-zpkg/zpkb returns NOTHING, and over all 229 recipes in this
   overlay returns NOTHING. Neither the builder nor any recipe sets either one.

3. THE FAILURE IS SILENT. pkg-config's answer to an unfindable module is
   "Package 'x' was not found in the pkg-config search path", which a configure
   script reports as the LIBRARY being missing. Nothing in that chain names
   pkg-config's search path as the cause.

⚠ WHAT THIS RECIPE DOES NOT DO: invent a store layout. Setting `--with-pc-path`
to some aggregate directory, or exporting `PKG_CONFIG_LIBDIR` from this recipe,
would be deciding a convention for the whole pantry from inside one package —
and 100-odd recipes already call pkg-config, so the convention is theirs, not
this file's. Upstream's default stays, the test block PRINTS the compiled-in
value so the first real build log carries the evidence, and the question is
reported where it belongs rather than answered here.

⛔ THE SIGNATURE: PUBLISHED, IDENTIFIED, NOT VERIFIED — a shape none of today's
other seven recipes had.

`pkg-config-0.29.2.tar.gz.asc` exists (HTTP 200; the `.sig` spelling is 404, so
`-sig auto` finds it on its first try). Reading it:

    public-key algorithm  RSA
    hash algorithm        SHA-256
    created               2017-03-20
    issuer key id         023a4420c7ec6914
    issuer fingerprint    ABSENT

⚠ A 2017 signature predates the issuer-fingerprint subpacket being routine, so
it names its key by a 64-BIT KEY ID. That is not a safe identifier — a 64-bit
collision is constructible — so the key id alone cannot be used to fetch a key
and call the result verified.

⭐ What resolves the identity is an independent publisher: Arch's pkg-config
PKGBUILD carries

    validpgpkeys=('6B99CE97F17F48C27F722D71023A4420C7EC6914')  # Dan Nicholson

whose low eight bytes are exactly `023A4420C7EC6914`, and whose `source=` is
this same tarball with the same `.asc`. So the full fingerprint is known from
somewhere that is neither the signature nor the host serving it.

⛔ The key MATERIAL is still missing. It is not in ftp.gnu.org's keyring —
checked, ABSENT among all 613 primary and 767 subkeys, since this is a
freedesktop project rather than a GNU one — and this fleet asks no keyserver.
So the digest rests on its two independent hash paths, as
kernel.org/linux-headers (go-zpkg/recipes#126) and gnu.org/libtool
(#131) do, and what is claimed is identification rather than verification.

⚠ Arch publishes `md5sums` rather than sha256 for this package, so unlike
go-zpkg/recipes#129 and #132 there is no third digest path either.

⛔ NOT BUILT. No session here can run the factory, so what is established is
this recipe's INPUTS — all eight switches with every default stated and three of
them overridden for reasons traced to the project's own files, the single
installed name, both licence files, and the full env-override semantics of the
three baked paths, each cited in `read`. The test block prints the compiled-in
`pc_path` rather than asserting a value nobody has chosen, asks pkg-config about
its own `.pc` file (the only end-to-end check possible with no other package
present), and fails if `/usr/include` returns to the suppressed-include path.
EOT
}
