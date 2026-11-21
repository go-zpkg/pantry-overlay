# pypa.io/flit-core — flit_core: the PEP 517 build backend of the Flit project,
# which builds pure-Python packages (Jinja2 among them) without setuptools.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#431, #440), as a
# build dependency of Jinja2, which systemd's meson.build:1735 requires.
#
# ⛔⛔ HELD BELOW 4.0 ON PURPOSE. Jinja2 3.1.6 declares
# `requires = ["flit_core<4"]` (its pyproject.toml, [build-system]), so a
# flit_core 4.x in the build environment is refused by the package that needs
# it. `versions` therefore ignores the 4.x series; the newest pinned is the
# newest it resolves. Lift the ignore when Jinja2 lifts its bound.

summary = "flit_core: the Flit PEP 517 build backend for pure-Python packages"

# pyproject.toml:15 `license = "BSD-3-Clause"`; :16 license-files also names
# flit_core/vendor/**/LICENSE*, the vendored tomli (MIT) among them.
license = "BSD-3-Clause AND MIT"

versions {
  github = "pypa/flit/tags"
  ignore = ["/^4\\./"]
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/f/flit_core/flit_core-{{version.raw}}.tar.gz"
  strip-components = 1

  # 53690 bytes, fetched with `zpkb sourcepin`, and byte-identical to the sha256
  # PyPI's JSON API (pypi.org/pypi/flit_core/3.12.0/json) records for the sdist.
  sha256 = {
    "3.12.0" = "18f63100d6f94385c6ed57a72073443e1a71a4acb4339491615d0f16d6ff01b2"
  }
}

build {
  script = [
    {
      # pyproject.toml:1-4 `requires = []` and `backend-path = ["."]`: flit_core
      # builds itself from the tree, so --no-build-isolation is complete.
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
import flit_core, flit_core.buildapi
assert flit_core.__version__ == "{{version.raw}}", flit_core.__version__
print(flit_core.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "flit_core was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
    {
      # A one-module project built to a wheel with this backend.
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
mkdir -p proj && cd proj
cat > pyproject.toml <<'TOMLEOF'
[build-system]
requires = ["flit_core<4"]
build-backend = "flit_core.buildapi"

[project]
name = "zprobe"
version = "1.2.3"
description = "probe"
TOMLEOF
echo 'VALUE = 42' > zprobe.py
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 -m pip wheel --no-build-isolation --no-index --no-deps -w dist .
test -s dist/zprobe-1.2.3-py3-none-any.whl
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :1-4 requires [] and backend-path ["."]; :13 requires-python >=3.6; :15-16 license BSD-3-Clause and license files
    "LICENSE",        # "Copyright (c) 2015, Thomas Kluyver and contributors", BSD-3-Clause text
  ]

  consulted = [
    "pypi.org/pypi/flit_core/3.12.0/json", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform. The install command is the one
pypa.io/setuptools and mesonbuild.com use, which is the shape measured there.

⛔ NOT SIGNED. The digest is witnessed by PyPI's JSON API and by the bytes
`zpkb sourcepin` fetched, which agree; the `versions` list comes from the
GitHub tags of pypa/flit, whose tags are the sdist's versions.

Jinja2 3.1.6's own bound (`flit_core<4`) is why the 4.x series is ignored; see
the header.
EOT
}
