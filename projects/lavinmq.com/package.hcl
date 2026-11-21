# lavinmq.com — LavinMQ, an AMQP 0-9-1 and MQTT 3.1.1 message broker in Crystal.
#
# ⛔ WRITTEN FROM LAVINMQ'S OWN Makefile, shard.yml AND shard.lock at v2.11.1
# (go-zpkg/packages#440 step 1), replacing a recipe that named no source, ran
# `sed -i` on the Makefile and set CRYSTAL_FLAGS=-Dbake_static.
#
# ⭐ NOTHING IS FETCHED BY THE BUILD. The Makefile itself downloads, with curl,
# four JavaScript/CSS assets from two npm tarballs (lines 58-78) and runs
# `shards install --production` (line 56), which clones five shards from git.
# Each is pinned below in `distributable`/`sources` with a digest, fetched by
# the builder, so the build script holds no network call. `lib` (a make target
# depending on shard.yml and shard.lock) is `touch`ed so make does not run
# shards.
#
# Why CRYSTAL_FLAGS is NOT set: the old recipe passed -Dbake_static, which
# REPLACES the Makefile's default `--release` (line 12). In release mode the
# static files are baked in anyway (src/lavinmq/http/controller/static.cr:54),
# so the default is left alone.
#
# ⚠ The pins are for 2.11.1, the newest tag `zpkb versions` resolves. The
# shard versions come from shard.lock and the assets from the Makefile; a new
# lavinmq release moves them (2.9.5 used chart.js and luxon, 2.11.1 uPlot), and
# the build script's digest checks say so.

summary = "LavinMQ: a fast, advanced AMQP 0-9-1 and MQTT 3.1.1 message queue server"

# shard.yml: license: Apache-2.0.
license = "Apache-2.0"

# Release tags are v-prefixed (v2.11.1).
versions {
  github = "cloudamqp/lavinmq"
}

# The libraries the binaries link: gc, event and pcre2 (the Crystal runtime,
# which links every program against them), ssl and crypto (the OpenSSL stdlib
# module, used by the HTTP and AMQPS servers), and lz4, which the lz4 shard
# declares as `@[Link("lz4")]` (src/lz4/lib.cr line 2). The old recipe listed
# lz4 as a build dependency only; a dynamic link needs it at run time too.
dependencies = {
  "hboehm.info/gc" = "^8"
  "libevent.org"   = "^2"
  "lz4.org"        = "^1"
  "openssl.org"    = "^3"
  "pcre.org/v2"    = "^10"
}

distributable {
  url              = "https://github.com/cloudamqp/lavinmq/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 1718361 bytes. Second witness: independent curl and shasum -a 256 gave the
  # same digest as `zpkb sourcepin --version 2.11.1`.
  sha256 = {
    "2.11.1" = "b81aee386d797c06d2c9aad62e526e6d8458eb1873bb8c3928cfe45d0c7a8ae3"
  }
}

# Production shards only (shard.lock; ameba is a development dependency and is
# not built). Each lands in lib/<name>, where shards would have put it and
# where CRYSTAL_PATH ./lib looks. Every digest is from `zpkb sourcepin` and
# agrees with an independent curl and shasum -a 256.
sources = [
  {
    url                = "https://github.com/cloudamqp/amq-protocol.cr/archive/refs/tags/v1.3.2.tar.gz"
    sha256             = "8b5431837eccf6242c45a641fb7592677ebc7dc87a3a75b83d14815451511571"
    dest               = "lib/amq-protocol"
    "strip-components" = 1
  },
  {
    url                = "https://github.com/cloudamqp/amqp-client.cr/archive/refs/tags/v1.3.3.tar.gz"
    sha256             = "388a451e94e97a0e45a554a49787e65ebee15ed89552babcab407506f1fa6b24"
    dest               = "lib/amqp-client"
    "strip-components" = 1
  },
  {
    url                = "https://github.com/84codes/mqtt-protocol.cr/archive/refs/tags/v0.3.1.tar.gz"
    sha256             = "74ab6a9a506e2df3db236a9367cbf0c1c7bc5186cceb8e61535d7718b13d5598"
    dest               = "lib/mqtt-protocol"
    "strip-components" = 1
  },
  {
    url                = "https://github.com/84codes/systemd.cr/archive/refs/tags/v3.0.1.tar.gz"
    sha256             = "b1a3a6bec0c3af48d5f7abb0b013fb5b77a8febd5d8a02aeaba597ca3cb9c472"
    dest               = "lib/systemd"
    "strip-components" = 1
  },

  # A commit, not a tag: shard.lock pins lz4 at 0015e74e (version 1.0.0).
  {
    url                = "https://github.com/84codes/lz4.cr/archive/0015e74e0ed0f6bb15de9c25c25034ad4bc7f636.tar.gz"
    sha256             = "154a447ba927eeca1bcb413662e4df82ed692690c79fd843c47efe545261cf58"
    dest               = "lib/lz4"
    "strip-components" = 1
  },

  # The two npm tarballs of Makefile lines 58-78 (registry.npmjs.org, the very
  # URLs the Makefile curls). Their members are checked below against the
  # Makefile's own digests (lines 62, 67, 72, 77).
  {
    url                = "https://registry.npmjs.org/uplot/-/uplot-1.6.32.tgz"
    sha256             = "4b8a8191e425658e3ea8c8c1314b0fc679c861ee3a1af2b20c7b16ba50b5133d"
    dest               = ".assets/uplot"
    "strip-components" = 1
  },
  {
    url                = "https://registry.npmjs.org/@stoplight/elements/-/elements-8.2.0.tgz"
    sha256             = "e967b11a72104199e9e4c178951330ab5156927173c121490d04ab89704f5d7b"
    dest               = ".assets/elements"
    "strip-components" = 1
  },
]

build {
  dependencies = {
    "crystal-lang.org"  = "^1"
    "gnu.org/coreutils" = "*"
    "gnu.org/help2man"  = "*"
    "gnu.org/make"      = "*"
    "openssl.org"       = "^3"
  }

  env = {
    ARGS = [
      "PREFIX={{prefix}}",
      "SYSCONFDIR={{prefix}}/etc",
      "SHAREDSTATEDIR={{prefix}}/var",
      "UNITDIR={{prefix}}/etc",
      "SYSUSERSDIR={{prefix}}/share/sysusers.d",

      # DOCS= empty: the openapi/docs target is not part of the binary.
      "DOCS=",
    ]

    # shard.yml: crystal 1.21.0. The shards are in ./lib.
    CRYSTAL_PATH = "./lib:$CRYSTAL_PATH"
  }

  script = [
    # The Makefile's JS list (line 8) names these four files; its rules would
    # curl them. Each is copied from the unpacked tarball and checked against
    # the Makefile's own digest (lines 62, 67, 72, 77).
    "mkdir -p static/js/lib",
    "cp .assets/uplot/dist/uPlot.esm.js static/js/lib/uplot.esm.js",
    "cp .assets/uplot/dist/uPlot.min.css static/js/lib/uplot.css",
    "cp .assets/elements/web-components.min.js static/js/lib/elements-8.2.0.js",
    "cp .assets/elements/styles.min.css static/js/lib/elements-8.2.0.css",
    "[ \"5dd9b3281aa64b461b42d9945f6adb2649d346502b12281a9ae0d46599a80eba *static/js/lib/uplot.esm.js\" = \"$(openssl dgst -sha256 -r static/js/lib/uplot.esm.js)\" ]",
    "[ \"df630c6a8d6f8eeaff264b50f73ce5b114f646ffd9a0bb74f049b0a00135fa04 *static/js/lib/uplot.css\" = \"$(openssl dgst -sha256 -r static/js/lib/uplot.css)\" ]",
    "[ \"598862da6d551769ebad9d61d4e3037535de573a13d3e0bd1ded4c5fc65c5885 *static/js/lib/elements-8.2.0.js\" = \"$(openssl dgst -sha256 -r static/js/lib/elements-8.2.0.js)\" ]",
    "[ \"119784e23ffc39b6fa3fdb3df93f391f8250e8af141b78dfc3b6bed86079f93b *static/js/lib/elements-8.2.0.css\" = \"$(openssl dgst -sha256 -r static/js/lib/elements-8.2.0.css)\" ]",

    # `lib` is a make target (line 55) that runs `shards install`; it is
    # already populated, so mark it up to date.
    "touch lib",

    # `crystal` is on PATH (the Makefile calls it bare, lines 20-37).
    "make install $ARGS",
  ]
}

provides = [
  "bin/lavinmq",
  "bin/lavinmqctl",
  "bin/lavinmqperf",
]

test {
  script = [
    "lavinmq --version | grep -q \"{{version.raw}}\"",
    "lavinmqctl --help",
    "lavinmqperf --help",
  ]
}

provenance {
  read = [
    "Makefile",   # line 8: JS; 12-13: CRYSTAL_FLAGS; 55-56: lib; 58-78: assets; 77-88: man pages; install target
    "shard.yml",  # crystal 1.21.0; license
    "shard.lock", # the shard versions
    "src/lavinmq/http/controller/static.cr", # line 54: --release bakes the static files
  ]

  consulted = []

  note = <<EOT
⛔ NOT BUILT. No session here can run the factory; the Makefile contract was
read, the sources and their digests were fetched twice.

⚠ UNKNOWNS: (1) how the builder lays out a .tgz source: assumed unpacked into
`dest` after strip-components 1; the script's `cp` lines depend on it, and a
wrong guess fails at the first `cp` (the digest checks would also refuse a
wrong file). (2) the Makefile's `install` uses GNU `install -D -t` (coreutils is
a build dependency). (3) the Makefile's VERSION variable is gone in 2.11.1, so
`lavinmq --version` comes from shard.yml; the test asserts it. (4) the
crystal-lang.org recipe is itself NOT BUILT and needs zpkb >= v0.95.0; this one
only needs it to resolve. (5) only lz4.cr was searched for `@[Link]`; the
other four shards were not. (6) the old recipe's etcd.io and perl.org build
dependencies were dropped: nothing in the Makefile calls either.

⚠ pkgxdev/pantry was read only as the former content of this very file.
EOT
}
