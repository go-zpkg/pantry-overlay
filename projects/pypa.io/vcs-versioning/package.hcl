# pypa.io/vcs-versioning — vcs-versioning: the VCS-metadata version engine that
# setuptools-scm is built on.
#
# ⛔ WRITTEN FROM THE SDIST'S OWN FILES (go-zpkg/packages#440). setuptools-scm
# 10.x declares `vcs-versioning>=2.5.0.dev0,<3` in [build-system] and in
# [project] dependencies (its pyproject.toml:5, :46), so it cannot be built
# without this package; pluggy, hatch-vcs and hatchling's chain need
# setuptools-scm.

summary = "vcs-versioning: derive Python package versions from VCS metadata"

# pyproject.toml:20 `license = {text = "MIT"}`; the sdist carries LICENSE.txt.
license = "MIT"

versions {
  # The setuptools-scm repository tags two packages: `setuptools-scm-v10.3.4`
  # and `vcs-versioning-v2.6.0`. Keep this one's, and drop the other's.
  github = "pypa/setuptools-scm/tags"
  strip  = "/^vcs-versioning-v/"
  ignore = ["/^setuptools-scm-/", "/^v\\d/"]
}

dependencies = {
  "python.org"        = "^3"
  "pypa.io/packaging" = "*"
}

distributable {
  url              = "https://files.pythonhosted.org/packages/source/v/vcs-versioning/vcs_versioning-{{version.raw}}.tar.gz"
  strip-components = 1

  # Fetched with `zpkb sourcepin`, and byte-identical to the sha256 PyPI's simple
  # index (pypi.org/simple/vcs-versioning/) records for the sdist.
  sha256 = {
    "2.6.0" = "22e9159288e2d8bca2fa6f6c31c34c9c66aec157f60e9e526f5d160d2516d60f"
  }
}

build {
  dependencies = {
    "pypa.io/setuptools" = "*"
    "pypa.io/packaging"  = "*"
  }

  script = [
    {
      # pyproject.toml:8-12 requires setuptools>=45 and packaging>=26.2 (and
      # typing-extensions only below Python 3.11), backend setuptools.build_meta.
      # setup.py:32,45 reads the version from the sdist's PKG-INFO first
      # (`parse_pkginfo`), so no git checkout is needed.
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
import importlib.metadata, vcs_versioning
assert importlib.metadata.version("vcs-versioning") == "{{version.raw}}"
print(vcs_versioning.__file__)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 probe.py > where.txt
grep "{{prefix}}" where.txt >/dev/null || { echo "vcs_versioning was not imported from this prefix" >&2; cat where.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "pyproject.toml", # :6-12 build-system setuptools>=45, packaging>=26.2; :20 license MIT; :24 requires-python >=3.8; :40-44 dependencies
    "setup.py",       # :32 parse_pkginfo is tried first; :73-82 get_version(fallback_root=".", dist_name="vcs-versioning")
    "LICENSE.txt",    # the MIT text
  ]

  consulted = [
    "pypi.org/simple/vcs-versioning/", # the second witness for the digest
  ]

  note = <<EOT
NOT BUILT. Written from the project's own files; neither the build nor the
test block has been run, on either platform.

⛔ NOT SIGNED. The digest is witnessed by PyPI's simple index and by the bytes
`zpkb sourcepin` fetched, which agree.

The `versions` strip/ignore pair targets the tag shape `vcs-versioning-v2.6.0`;
`zpkb versions` was run against it and lists 2.6.0 first.
EOT
}
