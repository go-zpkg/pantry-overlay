# ruby-lang.org — the Ruby interpreter (MRI/CRuby), with the standard library,
# the default and bundled gems, and the `gem`, `irb`, `rake`, `bundle` tools.
#
# ⛔ WRITTEN FROM RUBY'S OWN CONFIGURE.AC (go-zpkg/packages#431, packages#440
# step 1), at 4.0.10, replacing a recipe that was a pantry build script: it
# named no versions and no source, and its steps patched files (props/…) that
# this repository does not hold. This one builds the release tarball with the
# plain `./configure && make && make install` that README.md documents.
#
# ⭐ WHAT WRITING IT FOUND. configure.ac probes the build machine for a long
# list of optional things, and a recipe that does not state them lets the
# builder's host decide: GMP (:1027, DEFAULT yes), valgrind (:3384, default
# yes), dtrace (:3773, auto), YJIT and ZJIT (:3937, :3951, auto when a rustc is
# on the PATH), jemalloc (:1458, default no), and — the one that reaches the
# network — a BASERUBY (:76-101): when one is found, configure runs
# `tool/downloader.rb -e gnu config.guess config.sub` (:96), which downloads
# two files from the GNU site. Each one is named below.

summary = "Ruby: the CRuby interpreter, its standard library and the gem tools"

# COPYING:5 — "you can redistribute it and/or modify it under either the terms
# of the 2-clause BSDL (see the file BSDL), or the conditions below" (the Ruby
# licence). The files bundled under LEGAL carry their own, and are not the
# interpreter's.
license = "Ruby OR BSD-2-Clause"

# ⛔ THE INDEX IS ruby-lang.org's OWN FILE. cache.ruby-lang.org/pub/ruby/
# index.txt lists every release archive of every series with its digests; the
# pattern keeps the xz archive of an N.N.N release at major 4 or above (so a
# `4.1.0-preview1` and every 3.x series are not offered, and the pins below are
# the only ones that can be asked for).
versions {
  url   = "https://cache.ruby-lang.org/pub/ruby/index.txt"
  match = "/ruby-[4-9]\\.\\d+\\.\\d+\\.tar\\.xz/"
  strip = [
    "/^ruby-/",
    "/\\.tar\\.xz$/",
  ]
}

dependencies = {
  # The extensions are built only when their library is found, and a missing
  # one is skipped WITHOUT failing the build: ext/openssl/extconf.rb:106-112
  # (pkg-config "openssl"), ext/zlib/extconf.rb:11-14 (dir_config zlib, -lz),
  # ext/psych/extconf.rb:41-44 (pkg-config "yaml-0.1"), and the fiddle gem
  # (gems/fiddle-1.1.8.gem, libffi). The test below loads all four.
  "openssl.org"           = "^3"
  "pyyaml.org"            = "^0.2"
  "sourceware.org/libffi" = "^3"
  "zlib.net"              = "^1"
}

distributable {
  url              = "https://cache.ruby-lang.org/pub/ruby/{{version.marketing}}/ruby-{{version.raw}}.tar.xz"
  strip-components = 1

  # 18133108 bytes, recorded with `zpkb sourcepin --version 4.0.10`.
  #
  # ⭐ TWO WITNESSES ON TWO HOSTS, and neither is the fetch itself. The digest
  # below equals (1) the sha256 column of cache.ruby-lang.org's index.txt, line
  # 1130, the host that serves the bytes, and (2) the `xz:` value of the 4.0.10
  # entry in _data/releases.yml of github.com/ruby/www.ruby-lang.org, which is
  # the file the project's website is built from and sits on a different host.
  # No detached signature is published for Ruby tarballs.
  sha256 = {
    "4.0.10" = "1537f7a6003c436546ecab6b48b6e7725a9af2328f45a8af7f42f41c5df90ab8"
  }
}

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/make"               = "*"
  }

  env = {
    ARGS = [
      "--prefix={{prefix}}",

      # :76-101. NO BASERUBY: a release tarball already holds what a baseruby
      # generates (parse.c, insns.inc, revision.h, the *.rbinc files are all in
      # the tarball), and with one present configure DOWNLOADS config.guess and
      # config.sub (:96) — a fetch outside the pinned source. `no` is the value
      # :80 accepts.
      "--with-baseruby=no",
      # :107 --without-git: never run git, nothing here is a checkout.
      "--without-git",

      # :358 resolve load paths at run time from the executable's location, so
      # the installed tree works from wherever it is placed.
      "--enable-load-relative",
      # :3587 no libruby.so: --enable-shared forces LIBRUBY_RELATIVE=no
      # (:3596), which is the opposite of the line above.
      "--disable-shared",
      # :3548 no per-architecture subdirectories under lib/.
      "--disable-multiarch",

      # :1027-1030 GMP is DEFAULT yes, and the probe at :1455 links whatever
      # libgmp the host has. Refused: Bignum falls back to its own code.
      "--without-gmp",
      # :1458-1460 jemalloc, default no: named so a flip is a diff here.
      "--without-jemalloc",
      # :3384-3388 valgrind/memcheck.h, default yes.
      "--without-valgrind",
      # :3773-3785 dtrace, `auto`: a host with dtrace would compile probes in.
      "--disable-dtrace",
      # :3937 and :3951: both default to yes when a rustc is on the PATH,
      # and :3978 makes a missing rustc fatal when yes is given. Refused: no
      # Rust toolchain among this recipe's dependencies.
      "--disable-yjit",
      "--disable-zjit",

      # :3839 documents are not installed; :4608-4614 man pages as `man`, so
      # the result does not depend on whether the host has an nroff (:4617).
      "--disable-install-doc",
      "--with-mantype=man",

      # :4642 rubygems on by default; :4653 the parser (prism is the default,
      # :4656). Both stated.
      "--enable-rubygems",
      "--with-parser=prism",
    ]
  }

  script = [
    "./configure $ARGS",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

# bin/gem comes from the tarball's bin/ (one file); bundle, bundler and erb
# from libexec/ (bin/ in the install); rake, rdoc, ri and irb are the
# executables of the default/bundled gems rake-13.3.1, rdoc-7.0.4 and
# irb-1.16.0 listed under gems/.
provides = [
  "bin/bundle",
  "bin/bundler",
  "bin/erb",
  "bin/gem",
  "bin/irb",
  "bin/rake",
  "bin/rdoc",
  "bin/ri",
  "bin/ruby",
]

test {
  script = [
    "ruby --version | grep -q \"ruby {{version.raw}}\"",
    "gem --version",
    # Each extension named in `dependencies` was really built, not skipped:
    # openssl against libssl, zlib against libz, psych against libyaml,
    # fiddle against libffi.
    "ruby -e 'require \"openssl\"; abort \"no TLS\" unless OpenSSL::OPENSSL_LIBRARY_VERSION.start_with?(\"OpenSSL 3\")'",
    "ruby -e 'require \"zlib\"; s = \"abc\" * 100; abort \"zlib\" unless Zlib::Inflate.inflate(Zlib::Deflate.deflate(s)) == s'",
    "ruby -e 'require \"yaml\"; abort \"psych\" unless YAML.load(\"a: [1, 2]\") == {\"a\" => [1, 2]}'",
    "ruby -e 'require \"fiddle\"; abort \"fiddle\" if Fiddle::Handle::DEFAULT[\"strlen\"].nil?'",
    # Options read back from the build: no GMP, no JIT.
    "ruby -e 'require \"rbconfig\"; abort \"gmp\" if RbConfig::CONFIG[\"configure_args\"].include?(\"--with-gmp\"); abort \"jit\" if RubyVM::YJIT.enabled? rescue nil'",
    # The standard library and the pure-Ruby side.
    "ruby -rjson -rsocket -rdigest -rstringio -rset -e 'abort \"json\" unless JSON.parse(JSON.generate([1])) == [1]'",
    "ruby -e 'abort \"bignum\" unless (2**200).to_s.size == 61'",
    "rake --version",
    "irb --version",
    "erb --version",
  ]
}

provenance {
  read = [
    "README.md",     # the documented build: configure, make, make install
    "configure.ac",  # :76-101 baseruby and the config.guess download; :107 git; :358 load-relative; :1027 gmp; :1458 jemalloc; :3384 valgrind; :3548 multiarch; :3587 shared; :3773 dtrace; :3839 install-doc; :3937 yjit; :3951 zjit; :4608 mantype; :4642 rubygems; :4653 parser
    "COPYING",       # :5 the licence choice
    "ext/openssl/extconf.rb", # :106-112 pkg-config openssl
    "ext/zlib/extconf.rb",    # :11-14 zlib
    "ext/psych/extconf.rb",   # :41-44 yaml-0.1
    "gems/bundled_gems",      # the gem list that ships (fiddle, rake, rdoc, irb)
  ]

  consulted = []

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the options and line numbers
were read from the tarball (sha256 above), the digest was matched against two
published sources, and `zpkb lint` was run.

⚠ THE LARGEST UNKNOWN IS `--with-baseruby=no`. It is the documented way to
build a tarball without a Ruby (configure.ac:98-101 substitutes
missing-baseruby.bat), but it was not exercised; if a make target of 4.0.10
needs a baseruby after all, the fix is a bootstrap Ruby as a build dependency,
which this tree cannot yet name.

⚠ The previous recipe's relocation sed scripts (rbconfig.rb KEGDIR, shebang
fixing) are NOT carried over: it patched with files absent from this
repository, and --enable-load-relative is what the project itself offers.

⚠ pkgxdev/pantry was read only as the former content of this very file.
EOT
}
