# github.com/ofek/hatch-vcs — hatch-vcs: the Hatch plugin that takes the version
# from the VCS.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a build
# dependency of virtualenv.pypa.io (`requires = ["hatch-vcs>=0.5", ...]`).

summary = "hatch-vcs: Hatch plugin for versioning with your preferred VCS"

# pyproject.toml:10 `license = "MIT"`; the sdist carries LICENSE.txt.
license = "MIT"

versions {
  github = "ofek/hatch-vcs/tags"
  strip  = "/^v/"
}

dependencies = {
  "python.org"             = "^3"
  "pypa.io/hatchling"      = "*"
  "pypa.io/setuptools-scm" = "*"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/h/hatch-vcs/hatch_vcs-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/hatch-vcs/) records for the sdist.
  sha256 = {
    "0.5.0" = "0395fa126940340215090c344a2bf4e2a77bcbe7daab16f41b37b98c95809ff9"
  }
}

build {
  dependencies = {
    "pypa.io/hatchling"      = "*"
    "pypa.io/setuptools-scm" = "*"
  }

  script = [
    {
      # pyproject.toml:1-3 requires ["hatchling>=1.1.0"], backend
      # hatchling.build. The version is dynamic (pyproject.toml:7) and the sdist
      # is not a git checkout, so the version is pinned for the build from the
      # one the recipe resolved.
      run = <<EOT
set -eu
SETUPTOOLS_SCM_PRETEND_VERSION="{{version.raw}}" python3 -m pip install --no-build-isolation --no-index --no-deps --no-compile --prefix "{{prefix}}" .
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
import importlib.metadata, hatch_vcs
assert importlib.metadata.version("hatch-vcs") == "{{version.raw}}"
print(hatch_vcs.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "hatch_vcs was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :1-3 build-system hatchling>=1.1.0, hatchling.build; :7 dynamic version; :10 license MIT; :11 requires-python >=3.9; :35-38 dependencies
    "LICENSE.txt",    # the MIT text
  ]

  consulted = [
    "pypi.org/simple/hatch-vcs/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

SETUPTOOLS_SCM_PRETEND_VERSION is set inline on the build command because the
sdist is not a git checkout; whether hatch-vcs's own version source honours it
or falls back to PKG-INFO has not been measured.
EOT
}
