# github.com/python/typing_extensions — typing_extensions: backports and
# experimental additions to the standard `typing` module.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a dependency
# of setuptools-scm / vcs-versioning (python < 3.11 only) and of virtualenv
# (python < 3.11 only), so a 3.11+ interpreter never imports it from them.

summary = "typing_extensions: backported and experimental Python type hints"

# pyproject.toml:13 `license = "PSF-2.0"`, :14 license-files LICENSE.
license = "PSF-2.0"

versions {
  github = "python/typing_extensions/tags"
}

dependencies = {
  "python.org" = "^3"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/t/typing_extensions/typing_extensions-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/typing-extensions/) records for the sdist.
  sha256 = {
    "4.16.0" = "dc983d19a509c94dba722ee6abd33940f7c05a89e243c47e907eb4db6f1a43e5"
  }
}

build {
  dependencies = {
    "pypa.io/flit-core" = "*"
  }

  script = [
    {
      # pyproject.toml:3-4 requires ["flit_core >=3.11,<4"], backend
      # flit_core.buildapi; the project declares no dependencies.
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
import importlib.metadata, typing_extensions
assert importlib.metadata.version("typing_extensions") == "{{version.raw}}"
print(typing_extensions.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "typing_extensions was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :3-4 build-system flit_core >=3.11,<4; :12 requires-python >=3.9; :13-14 license PSF-2.0, license-files
    "LICENSE",        # the PSF license text
  ]

  consulted = [
    "pypi.org/simple/typing-extensions/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.
EOT
}
