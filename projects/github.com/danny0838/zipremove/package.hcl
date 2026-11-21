# github.com/danny0838/zipremove — zipremove: remove-related capabilities for
# Python's zipfile.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a dependency
# of python-sbom (`zipremove>=0.10`, its pyproject.toml:9 and :60).

summary = "zipremove: extend zipfile with remove-related capabilities"

# pyproject.toml:12-15 declares the license dynamic, provided by setup.py:4
# `license='MIT'`; the sdist carries LICENSE.txt.
license = "MIT"

versions {
  github = "danny0838/zipremove/tags"
  strip  = "/^v/"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/z/zipremove/zipremove-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/zipremove/) records for the sdist.
  sha256 = {
    "0.10.0" = "3c5957c115447b54299d3a23128764b59c4558fc98c4b878ff2dbc5db8a62021"
  }
}

build {
  dependencies = {
    "pypa.io/setuptools" = "*"
  }

  script = [
    {
      # pyproject.toml:1-3 requires ["setuptools>=61.0", "wheel"], backend
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
import importlib.metadata, zipremove
assert importlib.metadata.version("zipremove") == "{{version.raw}}"
print(zipremove.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "zipremove was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :1-3 build-system setuptools>=61.0, wheel, setuptools.build_meta; :7 version; :8 requires-python ~=3.7; :12-15 dynamic license
    "setup.py",       # :4 license='MIT'
    "LICENSE.txt",    # opens "MIT License"
  ]

  consulted = [
    "pypi.org/simple/zipremove/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

The license is `license='MIT'` at setup.py:4, and LICENSE.txt opens with "MIT
License".
EOT
}
