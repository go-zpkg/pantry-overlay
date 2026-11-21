# pypa.io/installer — installer: a low-level library for installing a wheel.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a dependency
# of python-sbom (`installer>=1.1`, its pyproject.toml:7 and :57), which the
# tox-dev packages' Hatch build hook imports.

summary = "installer: low-level library for installing a Python wheel"

# pyproject.toml:14 `license = "MIT"`; the sdist carries LICENSE.
license = "MIT"

versions {
  github = "pypa/installer/tags"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/i/installer/installer-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/installer/) records for the sdist.
  sha256 = {
    "1.1.0" = "5adc0c01ce62d809989e246987cd68944fe5df8af562d0358f65b2ab15cb5de7"
  }
}

build {
  dependencies = {
    "pypa.io/flit-core" = "*"
  }

  script = [
    {
      # pyproject.toml:2-5 requires ["flit_core<5,>=3.11"], backend
      # flit_core.buildapi. The version is dynamic (pyproject.toml:24-27) and
      # flit reads it from the module's own __version__.
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
import importlib.metadata, installer
assert importlib.metadata.version("installer") == "{{version.raw}}"
print(installer.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "installer was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :2-5 build-system flit_core<5,>=3.11; :9 readme; :13 requires-python >=3.10; :14 license MIT; :24-27 dynamic description, version
    "LICENSE",        # the MIT text
  ]

  consulted = [
    "pypi.org/simple/installer/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

pypa.io/flit-core is held below 4 by its own recipe, which satisfies the
"<5,>=3.11" requirement only if that recipe's version is 3.11 or later; the
lint does not check that range.
EOT
}
