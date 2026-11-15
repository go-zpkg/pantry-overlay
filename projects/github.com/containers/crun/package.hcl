dependencies = {
  "github.com/json-c/json-c" = "^0.14"
  "github.com/seccomp/libseccomp" = "*"
  "kernel.org/libcap" = "*"
}
platforms = [
  "linux",
]
provides = [
  "bin/crun",
]

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "*"
    "python.org" = "^3"
  }
  script = [
    "./configure $ARGS",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]

  env {
    ARGS = [
      "--prefix={{prefix}}",
      "--disable-systemd",
      "--disable-criu",
    ]
  }
}

distributable {
  strip-components = 1
  url = "https://github.com/containers/crun/releases/download/{{version}}/crun-{{version}}.tar.gz"
}

test {
  script = [
    "crun --version | grep {{version}}",
    "crun features | grep -q '\"seccomp\"'",
    "crun features | grep -q '\"apparmor\"'",
  ]
}

versions {
  github = "containers/crun"
  ignore = [
    "/^v?0\\./",
  ]
}

provenance {
  read = [
    "configure.ac", # :100 json-c >= 0.14; :200-209 seccomp; :212-218 systemd; :303-307 criu
    "src/exec.c",   # apparmor is a struct field and an OPTION_APPARMOR, with no configure switch
  ]

  note = <<EOT
Read at 1.31, the tag this recipe builds. ⛔ BOTH `--disable-` FLAGS ARE
REQUIRED, NOT PREFERENCES, and configure.ac says so in its own words.

  - `:212-218` — unless `--disable-systemd`, configure does
    `AC_CHECK_HEADERS([systemd/sd-bus.h], [], [AC_MSG_ERROR([*** Missing
    libsystemd headers])])`. This recipe declares NO libsystemd dependency, so
    without that flag the build does not degrade, it FAILS.
  - `:303-307` — criu is `default: autodetect`. Unless `--disable-criu`,
    `PKG_CHECK_MODULES([CRIU], [criu >= 3.15])` falls through to
    `AC_MSG_NOTICE([CRIU headers not found, building without CRIU support])`
    and the build CONTINUES. ⭐ That is the reproducibility argument, not a
    taste: the same source would produce a binary with or without
    checkpoint/restore depending on what happened to be installed on the
    builder. The flag makes the answer the same on every host.

Where the dependency constraints come from, rather than being chosen:

  - `:100` is `PKG_CHECK_MODULES([JSON_C], [json-c >= 0.14])`, unconditional,
    and `"github.com/json-c/json-c" = "^0.14"` above is that line read off.
  - `:200-209` makes libseccomp mandatory the same way systemd is — it errors
    on missing headers unless `--disable-seccomp` — and defines `HAVE_SECCOMP`,
    which is what puts "seccomp" in `crun features`.

⛔ SO THE TWO TEST LINES ARE NOT EQUAL, and only one of them is evidence.
`crun features | grep '"seccomp"'` genuinely proves libseccomp was found and
linked, because HAVE_SECCOMP is conditional. `crun features | grep
'"apparmor"'` proves NOTHING about the configuration: `apparmor` appears
nowhere in configure.ac at this tag — it is a `char *apparmor` field and an
`OPTION_APPARMOR` in `src/exec.c`, compiled unconditionally, because crun
PASSES an AppArmor label rather than linking libapparmor. The line is harmless
and it is not a check. Kept, with this written down, so the next reader does
not mistake it for one.
EOT
}
