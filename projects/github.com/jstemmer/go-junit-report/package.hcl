# github.com/jstemmer/go-junit-report — converts `go test -v` output into
# JUnit XML. A whole recipe, written from the project's own files at v2.1.0
# (go-zpkg/packages#440 step 1). Built as github.com/fatih/gomodifytags is
# (go.sum as the pin under -mod=readonly, GOPROXY without `,direct`,
# GOTOOLCHAIN=local, -trimpath, -buildvcs=false, CGO_ENABLED=0).
#
# Per project: the module root IS the command (main.go sits beside go.mod), so
# the package is `.`. The module path carries /v2 (go.mod:1) but the binary is
# go-junit-report, named by `-o`. Makefile:9 stamps main.Version, main.Revision
# and main.BuildTime from `git describe`; this recipe stamps main.Version only
# (main.go:19 `Version = "v2.1.0-dev"` is the default it replaces) and leaves
# Revision "HEAD" and BuildTime empty, as there is no repository to ask.

summary = "Convert go test output to JUnit XML"

# LICENSE:1 "Copyright (c) 2012 Joel Stemmer", the MIT text ("Permission is
# hereby granted, free of charge"). The module's one requirement (go.mod:5
# github.com/google/go-cmp v0.5.8) is not compiled in: `go list -deps .` lists
# no module, so the binary is the standard library alone.
license = "MIT"

versions {
  github = "jstemmer/go-junit-report"
}

distributable {
  # GitHub's archive of the tag: the release's assets are prebuilt binaries.
  url              = "https://github.com/jstemmer/go-junit-report/archive/refs/tags/v{{version.raw}}.tar.gz"
  strip-components = 1

  # 42192 bytes. ⚠ NOT SIGNED by anything this session verified; fetched from
  # github.com/…/archive and from codeload.github.com, and the two digests
  # agree.
  sha256 = {
    "2.1.0" = "6320a11a2a8c564f5a92a44eeae40950246ae5c70b3c679a1e702e128d6e900b"
  }
}

provides = [
  "bin/go-junit-report",
]

build {
  dependencies = {
    "go.dev" = "^1.27"
  }

  env = {
    CGO_ENABLED = "0"
    GOTOOLCHAIN = "local"
    GOFLAGS     = "-mod=readonly -modcacherw -trimpath -buildvcs=false"
    GOPROXY     = "https://proxy.golang.org"
  }

  script = [
    {
      run = <<EOT
set -eu
export GOCACHE="$PWD/.gocache" GOMODCACHE="$PWD/.gomodcache"
mkdir -p "{{prefix}}/bin"
go build -ldflags "-s -w -X main.Version=v{{version.raw}}" -o "{{prefix}}/bin/go-junit-report" .
EOT
    },
  ]
}

test {
  script = [
    {
      run = <<EOT
set -eu
printf '=== RUN   TestX\n--- PASS: TestX (0.00s)\nPASS\nok  \tm\t0.001s\n' > go.txt
go-junit-report < go.txt > out.xml
grep -q '<testcase name="TestX" classname="m"' out.xml
grep -q 'failures="0"' out.xml
go-junit-report -version | grep -q '^go-junit-report v2\.1\.0 '
EOT
    },
  ]
}

provenance {
  read = [
    "go.mod",         # :1 module github.com/jstemmer/go-junit-report/v2, :3 go 1.13, :5 go-cmp (tests only)
    "go.sum",         # the pin under -mod=readonly
    "LICENSE",        # :1 Copyright (c) 2012 Joel Stemmer, MIT text
    "main.go",        # :19-21 Version / Revision / BuildTime, :52 the -version line
    "Makefile",       # :1 VERSION from git describe, :9 the -ldflags with the three -X
  ]

  note = <<EOT
pkgxdev/pantry was not consulted. The fragment this replaces said only
`provides`.

⚠ THE SOURCE RUNG, STATED: an unsigned tag's generated archive, confirmed by a
second fetch of the same bytes from codeload.github.com.

⛔ NOT BUILT BY THE FACTORY. What WAS run: the build line on darwin/arm64 with
go1.27.4 against a clone of the v2.1.0 tag, and the test script's commands: a
passing `go test -v` transcript produced a testcase TestX with failures="0",
and `-version` printed "go-junit-report v2.1.0  (HEAD)". The linux arms were
not run.
EOT
}
