# pypa.io/wheel — wheel: the reference implementation of the wheel packaging
# format, and the `wheel` command.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a build
# dependency of distlib and (in the project's own build-system tables) of
# borgbackup and borghash.

summary = "wheel: the Python wheel packaging format and its command-line tool"

# pyproject.toml:9 `license = "MIT"`; the sdist carries LICENSE.txt.
license = "MIT"

versions {
  github = "pypa/wheel/tags"
}

dependencies = {
  "python.org"        = "^3"
  "pypa.io/packaging" = "*"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/w/wheel/wheel-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/wheel/) records for the sdist.
  sha256 = {
    "0.48.0" = "94800765601e9171bf5d58d066e640662842bcedcbab982b2c90787a2c987322"
  }
}

build {
  dependencies = {
    "pypa.io/flit-core" = "*"
    "pypa.io/packaging" = "*"
  }

  script = [
    {
      # pyproject.toml:1-3 requires ["flit_core >=3.11,<5"], backend
      # flit_core.buildapi, from the build dependency above. :27-29 declares
      # `packaging >= 24.0`, which is the run-time dependency above.
      run = <<EOT
set -eu
python3 -m pip install --no-build-isolation --no-index --no-deps --no-compile --prefix "{{prefix}}" .
EOT
    },
  ]
}

runtime {
  env = {
    PYTHONPATH = "{{prefix}}/lib/python{{deps.python.org.version.major}}.{{deps.python.org.version.minor}}/site-packages:$PYTHONPATH"
  }
}

test {
  script = [
    {
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
cat > probe.py <<'PYEOF'
import importlib.metadata, wheel
assert importlib.metadata.version("wheel") == "{{version.raw}}"
print(wheel.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "wheel was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :1-3 build-system flit_core >=3.11,<5; :9 license MIT; :26 requires-python >=3.9; :27-29 dependencies packaging >= 24.0
    "LICENSE.txt",    # the MIT text
  ]

  consulted = [
    "pypi.org/simple/wheel/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.
EOT
}
