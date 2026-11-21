# virtualenv.pypa.io — virtualenv: a tool to create isolated Python
# environments.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440), replacing a
# fragment that carried only three dependencies and no source.

summary = "virtualenv: create isolated Python environments"

# PKG-INFO:15 `License-Expression: MIT`; pyproject.toml:20; the sdist carries
# LICENSE and THIRD-PARTY-NOTICES.md.
license = "MIT"

versions {
  github = "pypa/virtualenv/tags"
}

# pyproject.toml:54-62. typing-extensions is declared only below Python 3.11
# (:61), and filelock and platformdirs need 3.11 themselves.
dependencies = {
  "python.org"                      = "^3.11"
  "github.com/pypa/distlib"         = "*"
  "github.com/tox-dev/filelock"     = "*"
  "pypa.io/packaging"               = "*"
  "github.com/tox-dev/platformdirs" = "*"
  "github.com/tox-dev/python-discovery" = "*"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/v/virtualenv/virtualenv-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/virtualenv/) records for the sdist.
  sha256 = {
    "21.15.11" = "6ad11e129f546835ae81d47a27f48ed32dcc4e2a0776014a159bab8895cdb9ac"
  }
}

build {
  dependencies = {
    "pypa.io/hatchling"                        = "*"
    "github.com/ofek/hatch-vcs"                = "*"
    "github.com/hynek/hatch-fancy-pypi-readme" = "*"
    "github.com/tox-dev/python-sbom"           = "*"
  }

  script = [
    {
      # pyproject.toml:3-9 requires hatch-fancy-pypi-readme, hatch-vcs and
      # hatchling, plus python-sbom[hatch] on Python 3.11 and later; backend
      # hatchling.build. :254-255 enable the vcs hook and the custom hook
      # hatch_build.py, which imports python_sbom.hatch on 3.11 and later. The
      # version is VCS-derived (:251) and the sdist is not a checkout, so it is
      # pinned from the resolved one. The sdist carries README.md, so no
      # stand-in is made.
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
import importlib.metadata, virtualenv
assert importlib.metadata.version("virtualenv") == "{{version.raw}}"
print(virtualenv.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "virtualenv was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 -m virtualenv --version > version.txt
grep "{{version.raw}}" version.txt >/dev/null || { echo "virtualenv --version did not report {{version.raw}}" >&2; cat version.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml",  # :3-9 build-system; :20 license MIT; :29 requires-python >=3.9; :50-62 dynamic, dependencies; :71 console script; :250-255 Hatch config
    "hatch_build.py",  # imports python_sbom.hatch on Python 3.11 and later
    "PKG-INFO",        # :3 Version; :15 License-Expression MIT
    "LICENSE",         # present in the sdist
  ]

  consulted = [
    "pypi.org/simple/virtualenv/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

The recipe this replaces was a fragment with libexpat.github.io, openssl.org and
pkgx.sh as dependencies; none of them is a dependency of the sdist's own
pyproject (:54-62), and libexpat and openssl are the interpreter's, so they are
dropped. No recipe in the tree lists virtualenv as a dependency; the only
mention is a comment in projects/pkgx.sh/package.hcl:5 saying virtualenv depends
on pkgx.sh, which is the fragment's claim and not the sdist's.

virtualenv requires Python 3.9 or later by itself (:29) but its filelock and
platformdirs dependencies need 3.11, hence `^3.11`.
EOT
}
