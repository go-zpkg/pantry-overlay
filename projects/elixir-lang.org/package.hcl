# elixir-lang.org — Elixir: a dynamic, functional language for scalable and
# maintainable applications on the Erlang VM. New in go-zpkg/packages#440:
# rabbitmq.com's CLI tools are Elixir and no recipe existed.
#
# ⛔ WRITTEN FROM ELIXIR'S OWN FILES, at 1.20.5.
#
# ⭐ THE PROJECT PUBLISHES NO SOURCE ASSET. Its releases carry only PRECOMPILED
# archives (elixir-otp-27.zip, -28, -29, one per Erlang major, each built against
# that major) and a Windows installer, so a recipe that pinned one of them would
# pin a binary tied to one OTP. This recipe builds the tag's source archive with
# the Makefile instead, against whichever Erlang the tree provides.

summary = "Elixir: a dynamic, functional language for building scalable and maintainable applications on the Erlang VM"

# LICENSE:1-3 is the Apache License, Version 2.0 text.
license = "Apache-2.0"

versions {
  # Tags are v1.20.5; rolling tags such as v1.20-latest are not versions, and
  # prereleases (v1.20.0-rc.N) are left to zpkb's own ordering. Measured with
  # `zpkb versions`; see the provenance note for the result.
  github = "elixir-lang/elixir"
  strip  = "/^v/"
}

dependencies = {
  # lib/elixir/pages/references/compatibility-and-deprecations.md:51 lists
  # Erlang/OTP 27 - 29 for Elixir 1.20, and lib/elixir/src/elixir.erl:143
  # refuses anything below 27 at startup. (elixir.erl:134-136 warns that
  # OTP 28.0 specifically is to be avoided in favour of 28.1+ or 27.)
  "erlang.org" = ">=27"
}

distributable {
  # THE GENERATED TAG ARCHIVE, because no source asset exists (see above). Its
  # bytes are produced by GitHub, not uploaded by the project, so the digest is
  # only as stable as GitHub's archive generation; the second witness is an
  # independent fetch from the other host, codeload.github.com, which gave the
  # same digest. 3687776 bytes.
  url              = "https://github.com/elixir-lang/elixir/archive/refs/tags/v{{version}}.tar.gz"
  strip-components = 1

  sha256 = {
    "1.20.5" = "3d99f2e129418800817e0e5a3ce4812c34537a32d50e37578189e90c79de7062"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env = {
    # Elixir's tools refuse to start under a non-UTF-8 locale on some systems.
    LC_ALL = "C.UTF-8"
  }

  script = [
    # Makefile:85 compile = erlang + elixir; :129-140 install puts the tree
    # under $(PREFIX)/lib/elixir and symlinks bin/* to $(PREFIX)/bin.
    "make --jobs {{ hw.concurrency }} compile",
    "make PREFIX=\"{{prefix}}\" install",
  ]
}

provides = [
  "bin/elixir",
  "bin/elixirc",
  "bin/iex",
  "bin/mix",
]

test {
  script = [
    "test -x \"{{prefix}}/bin/elixir\"",
    "test -x \"{{prefix}}/bin/mix\"",
    {
      run = <<EOT
set -eu
out=$("{{prefix}}/bin/elixir" -e 'IO.puts(System.version())')
if test "$out" != "{{version}}"; then
  echo "elixir reports $out, expected {{version}}" >&2
  exit 1
fi
EOT
    },
    "test \"$(\"{{prefix}}/bin/elixir\" -e 'IO.puts(Enum.sum(1..10))')\" = 55",
    "\"{{prefix}}/bin/mix\" --version",
  ]
}

provenance {
  read = [
    "Makefile",   # :5 PREFIX ?= /usr/local; :85 compile; :129-140 install; :344-349 install_man
    "LICENSE",    # :1-3 Apache License 2.0
    "VERSION",    # 1.20.5
    "lib/elixir/pages/references/compatibility-and-deprecations.md",  # :51 Elixir 1.20 runs on Erlang/OTP 27 - 29
    "lib/elixir/src/elixir.erl",  # :127-143 parse_otp_release: OTP 28.0 warning, below 27 is an error
    "https://github.com/elixir-lang/elixir/releases/expanded_assets/v1.20.5",  # the asset list: precompiled zips, Docs.zip, .sha256sum and .sigstore beside each, no source archive
  ]

  note = <<EOT
NOT BUILT. NOT RUN. Written from the project's own files; the make and the test
block have not been run on either platform.

Open points, stated rather than hidden:
  - The archive is GitHub's generated tag archive; the project's own checksum
    files (*.sha256sum) cover only the precompiled assets and the Docs, not it.
  - `"erlang.org" = ">=27"` has no upper bound: the compatibility table lists
    27 - 29 only, and a newer Erlang is untested by the project.
  - LC_ALL=C.UTF-8 is a precaution; whether the builder's libc provides that
    locale name was not checked.
  - The man pages (install_man) are not built or installed.
EOT
}
