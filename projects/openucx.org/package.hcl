dependencies = {
  "github.com/linux-rdma/rdma-core" = "*"
  "linux/x86-64" = {
    "github.com/ROCm/ROCR-Runtime" = "*"
  }
  "zlib.net" = "^1.3"
}
platforms = [
  "linux",
]
provides = [
  "bin/ucx_info",
  "bin/ucx_perftest",
  "bin/ucx_read_profile",
]

build {
  dependencies = {
    "freedesktop.org/pkg-config" = "^0.29"
    "gnu.org/autoconf" = "*"
    "gnu.org/automake" = "*"
    "gnu.org/libtool" = "*"
    "gnu.org/m4" = "*"
  }
  env = {
    ARGS = [
      "--prefix={{prefix}}",
      "--libdir={{prefix}}/lib",
      "--disable-dependency-tracking",
      "--disable-silent-rules",
      "--disable-logging",
      "--disable-debug",
      "--disable-assertions",
      "--disable-params-check",
      "--without-java",
      "--without-go",
      "--without-cuda",
      "--with-verbs={{deps.github.com/linux-rdma/rdma-core.prefix}}",
    ]
    "linux/aarch64" = {
      ARGS = [
        "--without-rocm",
      ]
    }
    "linux/x86-64" = {
      ARGS = [
        "--with-rocm={{deps.github.com/ROCm/ROCR-Runtime.prefix}}",
      ]
    }
  }
  script = [
    "sed -i 's/-Wall -Werror/-Wall/' configure",
    "sed -i 's|^SUBDIRS = profiling iodemo$|SUBDIRS = profiling|' test/apps/Makefile.in",
    "./configure $ARGS",
    "make --jobs {{hw.concurrency}}",
    "make install",
  ]
}

distributable {
  strip-components = 1
  url = "https://github.com/openucx/ucx/releases/download/v{{version}}/ucx-{{version}}.tar.gz"
}

test {
  script = [
    "ucx_info -v | grep -q \"Library version\"",
    # ⛔ THESE TWO WERE ONE-KEY MAPS, NOT COMMANDS, AND THE RENDERER REFUSED
    # THE WHOLE TEST. In yaml, `- ucx_info -d | grep -q "Transport: posix"` is
    # a MAPPING: the `: ` inside the quotes splits the item into the key
    # `ucx_info -d | grep -q "Transport` and the value `posix"`. The HCL
    # conversion carried that structure faithfully, so the defect predates it.
    # buildscript.scriptItem then calls renderRun(m["run"]) on a map with no
    # `run` key and returns "script step needs a `run` string or list" —
    # measured with the builder's own renderer, which refuses the entire
    # `test` block rather than skipping two lines.
    "ucx_info -d | grep -q \"Transport: posix\"",
    "ucx_info -d | grep -q \"Transport: sysv\"",
    "test -f {{prefix}}/lib/ucx/libuct_ib.so",
    <<EOT
case "$(uname -m)" in
  x86_64) test -f {{prefix}}/lib/ucx/libuct_rocm.so ;;
  *) echo "no rocm transport on $(uname -m): ROCr is x86-64 only" ;;
esac
EOT
,
  ]
}

versions {
  github = "openucx/ucx"
}

provenance {
  read = [
    "buildlib/tools/check_tls.sh", # upstream's own transport check: grep -q "Transport: $i" over tcp self sysv posix
  ]

  note = <<EOT
⭐ THE TEST THIS RECIPE MEANT TO WRITE IS THE TEST UPSTREAM ITSELF RUNS, and
that is how the two broken lines above were recovered rather than invented.
`buildlib/tools/check_tls.sh` does:

    for i in tcp self sysv posix $@; do
        if `echo $output | grep -q "Transport: $i"`; then

So `Transport: posix` and `Transport: sysv` are the real spelling of
`ucx_info -d` output, confirmed in the project's own file and not reconstructed
from the broken key-value pair alone — though the pair happened to determine it
uniquely, since its key ended at `"Transport` and its value began with `posix"`.

⛔ AND THE DEFECT WAS NOT COSMETIC. Measured with `buildscript.Generate` on
this recipe's `test.script`: it returns "buildscript: script step needs a `run`
string or list". `scriptItem` sees a map, finds no `if` and no `run`, and
`renderRun(nil)` falls to its default arm — so the ENTIRE test block was
unrenderable, not two assertions quietly lost. `zpkb test openucx.org` could
not run at all, and nothing in the lane says so because the overlay's CI lints
recipes and does not build them.

What is still NOT recorded here, stated so the next reader does not think it
is: the rest of this recipe's twelve `--disable-`/`--without-` flags, the two
`sed` lines that patch `configure` and `test/apps/Makefile.in`, and the
`--with-rocm`/`--without-rocm` split by architecture. Those need ucx's own
`configure.ac` and `test/apps/Makefile.am` read, which this pass did not do.
The provenance is honest about its scope rather than complete.
EOT
}
