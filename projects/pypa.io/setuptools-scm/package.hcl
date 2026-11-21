# pypa.io/setuptools-scm — setuptools-scm: the setuptools plugin that manages
# package versions from SCM tags.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), as a build
# dependency of pluggy and hatch-vcs (virtualenv's build backend plugin), and
# of the 2.x series of borgbackup, borgstore and borghash.

summary = "setuptools-scm: manage Python package versions from SCM metadata"

# pyproject.toml:15 `license = {text = "MIT"}`; the sdist carries LICENSE.
license = "MIT"

versions {
  # The repository tags two packages: `setuptools-scm-v10.3.4` and
  # `vcs-versioning-v2.6.0`. Keep this one's, and drop the other's.
  github = "pypa/setuptools-scm/tags"
  strip  = "/^setuptools-scm-v/"
  ignore = ["/^vcs-versioning-/", "/^v\\d/"]
}

dependencies = {
  "python.org"             = "^3"
  "pypa.io/packaging"      = "*"
  "pypa.io/setuptools"     = "*"
  "pypa.io/vcs-versioning" = "*"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/s/setuptools-scm/setuptools_scm-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/setuptools-scm/) records for the sdist.
  sha256 = {
    "10.3.4" = "a69f28bfc245608781205e912faae437c2b2165773afa4e7b979d77447a69dd2"
  }
}

build {
  dependencies = {
    "pypa.io/setuptools"     = "*"
    "pypa.io/vcs-versioning" = "*"
    "pypa.io/packaging"      = "*"
  }

  script = [
    {
      # pyproject.toml:2-10 requires setuptools>=45 and vcs-versioning
      # (>=2.5.0.dev0,<3), backend setuptools.build_meta. setup.py:15-16 imports
      # setuptools_scm and vcs_versioning from the build environment, which is
      # why vcs-versioning is a build dependency. The version comes from the
      # sdist's PKG-INFO (setup.py:39 fallback_root=".").
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
import importlib.metadata, setuptools_scm
assert importlib.metadata.version("setuptools-scm") == "{{version.raw}}"
print(setuptools_scm.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "setuptools_scm was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :2-10 build-system setuptools>=45, vcs-versioning>=2.5.0.dev0,<3; :15 license MIT; :19 requires-python >=3.8; :40-52 dependencies
    "setup.py",       # :15-16 imports setuptools_scm and vcs_versioning; :39 fallback_root="."; :44 dist_name
    "LICENSE",        # the MIT text
  ]

  consulted = [
    "pypi.org/simple/setuptools-scm/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

tomli and typing-extensions are declared only below Python 3.11 (pyproject.toml
:50-51), so they are not dependencies of an interpreter this tree ships.
EOT
}
