# github.com/pypa/distlib — distlib: low-level components of Python packaging
# tools.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a dependency
# of virtualenv.pypa.io (`distlib<1,>=0.4.3`, its pyproject.toml:55).

summary = "distlib: low-level components of Python packaging tools"

# PKG-INFO:8 `License: PSF-2.0`; the sdist carries LICENSE.txt, the Python
# Software Foundation license text.
license = "PSF-2.0"

versions {
  github = "pypa/distlib/tags"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/d/distlib/distlib-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/distlib/) records for the sdist.
  sha256 = {
    "0.4.4" = "ca4175b4ac7f71223cc30ed7248c45d2b38c2439d8ee6e498ab67ed63cf3508d"
  }
}

build {
  dependencies = {
    "pypa.io/setuptools" = "*"
  }

  script = [
    {
      # pyproject.toml:2-8 requires ["setuptools >= 68", "wheel"], backend
      # setuptools.build_meta. The "wheel" requirement is not needed by a
      # setuptools that builds wheels itself, so it is not supplied.
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
import importlib.metadata, distlib
assert importlib.metadata.version("distlib") == "{{version.raw}}"
print(distlib.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "distlib was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :2-8 build-system setuptools>=68, wheel, setuptools.build_meta
    "PKG-INFO",       # :8 License PSF-2.0
    "LICENSE.txt",    # the Python Software Foundation license text
  ]

  consulted = [
    "pypi.org/simple/distlib/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

The license identifier comes from the sdist's PKG-INFO (:8), which the build
regenerates; pyproject.toml's project table was not read here.
EOT
}
