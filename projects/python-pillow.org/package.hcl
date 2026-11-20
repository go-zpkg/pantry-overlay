# python-pillow.org — Pillow, the Python imaging library (`import PIL`), with
# every image library it can use either REQUIRED (the build fails if it is
# missing) or REFUSED (named off, with the reason). go-zpkg/recipes#122 step 5.
#
# ⛔ WRITTEN FROM PILLOW'S OWN FILES (go-zpkg/packages#431), at 13.0.0.
#
# ⭐⭐ PILLOW SKIPS A MISSING LIBRARY IN SILENCE, AND NAMES THE ONE MECHANISM
# THAT STOPS IT. setup.py:311-327 lists eleven features; `required` starts as
# {jpeg, zlib} (:327), and every other feature that is not found is left out of
# the build with a line in a summary (:1054-1061) while pip exits 0. The way to
# make one fatal is `-C <feature>=enable` (pip's --config-settings): the backend
# turns it into `--pillow-configuration=<feature>=<enable>`
# (_custom_build/backend.py:13-18), finalize_options adds it to `required`
# (setup.py:421-423), and the check after the probes raises DependencyException
# "requested by the option flag '-C <feature>=enable'" (:899-903, :1122-1129).
# The pantry recipe this one replaces named FIVE (tiff, freetype, lcms, webp,
# xcb) and so built a Pillow without JPEG 2000 whenever openjpeg was not found.
#
# ⭐ WHAT IS REQUIRED HERE, AND WHAT IS REFUSED:
#
#   required   zlib jpeg tiff freetype lcms webp jpeg2000 xcb   (-C x=enable)
#   refused    raqm avif imagequant                              (-C x=disable)
#
# Each refusal has a reason below, and the test asserts both halves with
# `PIL.features.check`: eight true, three false.

summary = "Pillow: the Python imaging library, with JPEG, JPEG 2000, PNG, TIFF, WebP, FreeType, Little CMS and XCB required"

# pyproject.toml:18 `license = "MIT-CMU"`, license-files LICENSE.
license = "MIT-CMU"

versions {
  github = "python-pillow/Pillow/tags"
  ignore = ["/(a|b|rc)\\d+$/"]
}

dependencies = {
  "python.org"                = "^3"
  "libjpeg-turbo.org"         = "^3"
  "simplesystems.org/libtiff" = "^4"
  "freetype.org"              = "^2"
  "littlecms.com"             = "^2"
  "google.com/webp"           = "^1"
  "openjpeg.org"              = "^2"
  "x.org/xcb"                 = "^1"
  "zlib.net"                  = "^1"
}

distributable {
  # The sdist PyPI serves, which is what `pip install pillow` builds. It is not
  # the GitHub archive of the tag, which is a different file (edf59ba2…).
  url              = "https://files.pythonhosted.org/packages/source/p/pillow/pillow-{{version.raw}}.tar.gz"
  strip-components = 1

  # 47058631 bytes. ⭐ THIS IS THE ONE FILE OF THE EIGHT RECIPES OF THIS CHAIN
  # THAT THE PROJECT SIGNS. PyPI serves a PEP 740 attestation for it
  # (pypi.org/integrity/pillow/13.0.0/pillow-13.0.0.tar.gz/provenance, HTTP 200):
  # a sigstore bundle whose in-toto statement names this file and
  # sha256 cdcd1ba258178f7356d74170c9a81ba4eab6a5d55748bc402a5a2a6fe6be3510, and
  # whose publisher is GitHub repository python-pillow/Pillow, workflow
  # wheels.yml, environment release-pypi. The same digest is the one PyPI's JSON
  # states for the file, and the bytes fetched from files.pythonhosted.org hash
  # to it.
  #
  # ⚠ WHAT WAS NOT DONE: the sigstore signature and its Rekor inclusion proof
  # were not VERIFIED here (no verifier was run); the statement was decoded and
  # its subject compared with the digest. The digest below is therefore three
  # sources that agree, one of them signed by a key this session did not check.
  sha256 = {
    "13.0.0" = "cdcd1ba258178f7356d74170c9a81ba4eab6a5d55748bc402a5a2a6fe6be3510"
  }
}

build {
  dependencies = {
    "pypa.io/setuptools"         = "*"
    "github.com/pybind/pybind11" = "*"
  }

  env = {
    ARGS = [
      # ⛔ OFFLINE: pyproject.toml:2-6 asks for pybind11 and setuptools>=77 as
      # build requirements; with isolation on, pip would fetch them. They are
      # build dependencies of this recipe instead (pypa.io/setuptools and
      # github.com/pybind/pybind11 are recipes of this tree).
      "--no-build-isolation",
      "--no-index",
      "--no-deps",
      "--no-compile",
      "--prefix={{prefix}}",

      # ⭐ REQUIRED, ONE FLAG EACH (see the header). zlib and jpeg are required
      # without a flag (setup.py:327); they are named too, so the list reads as
      # the whole set and a changed default is visible.
      "--config-settings=zlib=enable",
      "--config-settings=jpeg=enable",
      "--config-settings=tiff=enable",
      "--config-settings=freetype=enable",
      "--config-settings=lcms=enable",
      "--config-settings=webp=enable",
      "--config-settings=jpeg2000=enable",
      "--config-settings=xcb=enable",

      # ⛔ REFUSED, and NAMED, because an unnamed feature is still probed and a
      # copy on the builder's machine would turn it on (setup.py:509-538 reads
      # pkg-config, :665-699 the system directories):
      #
      #   raqm        libraqm needs HarfBuzz and FriBiDi (docs/installation/
      #               building-from-source.rst:72-80), and this tree has a recipe
      #               for neither. `-C raqm=vendor` compiles Pillow's copy of
      #               raqm but still links HarfBuzz (setup.py:835-842). Without
      #               raqm, Pillow lays text out with FreeType alone: text
      #               direction and font features are unsupported
      #               (building-from-source.rst:80).
      #   avif        libavif is "merely an API that wraps AVIF codecs"
      #               (building-from-source.rst:95-96): it needs an encoder and a
      #               decoder (aom, dav1d, rav1e or SVT-AV1), and this tree has a
      #               recipe for none of them nor for libavif. AVIF files are
      #               therefore neither read nor written.
      #   imagequant  libimagequant is GPLv3, "more restrictive than Pillow's
      #               licence" (building-from-source.rst:68-70), so enabling it
      #               would make the `license` field above wrong; it is also not
      #               a recipe of this tree. Quantisation falls back to Pillow's
      #               own median-cut and octree.
      "--config-settings=raqm=disable",
      "--config-settings=avif=disable",
      "--config-settings=imagequant=disable",

      # ⛔ NO GUESSING (setup.py:589-690, :692-699). The probe adds Homebrew,
      # MacPorts, fink, /usr/local, /opt/local, /usr/lib and the loader's
      # directories to its search path, so a library of the BUILDER'S machine
      # could answer for one of ours. Every directory it may use is handed to it
      # below instead.
      "--config-settings=platform-guessing=disable",
    ]

    MAX_CONCURRENCY = "{{ hw.concurrency }}"

    # ⭐ THE LIBRARIES, POINTED AT OURS (setup.py:509-543): `<NAME>_ROOT` makes
    # `<root>/lib` and `<root>/include` the search path for that library.
    JPEG_ROOT     = "{{deps.libjpeg-turbo.org.prefix}}"
    JPEG2K_ROOT   = "{{deps.openjpeg.org.prefix}}"
    TIFF_ROOT     = "{{deps.simplesystems.org/libtiff.prefix}}"
    ZLIB_ROOT     = "{{deps.zlib.net.prefix}}"
    FREETYPE_ROOT = "{{deps.freetype.org.prefix}}"
    WEBP_ROOT     = "{{deps.google.com/webp.prefix}}"
    LCMS_ROOT     = "{{deps.littlecms.com.prefix}}"

    # xcb has no `_ROOT` (it is absent from the table at setup.py:509-522); its
    # header and library are found through the include and library path
    # variables setup.py:565-573 reads.
    C_INCLUDE_PATH = "{{deps.x.org/xcb.prefix}}/include"
    LIBRARY_PATH   = "{{deps.x.org/xcb.prefix}}/lib"

    # ⛔ AN EXPLICIT RPATH PER LIBRARY, so what was linked is what is found when
    # the extension modules load (the same reason freetype.org states one).
    LDFLAGS = "-Wl,-rpath,{{deps.libjpeg-turbo.org.prefix}}/lib -Wl,-rpath,{{deps.openjpeg.org.prefix}}/lib -Wl,-rpath,{{deps.simplesystems.org/libtiff.prefix}}/lib -Wl,-rpath,{{deps.zlib.net.prefix}}/lib -Wl,-rpath,{{deps.freetype.org.prefix}}/lib -Wl,-rpath,{{deps.google.com/webp.prefix}}/lib -Wl,-rpath,{{deps.littlecms.com.prefix}}/lib -Wl,-rpath,{{deps.x.org/xcb.prefix}}/lib"
  }

  script = [
    {
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
export PYTHONPATH="{{deps.pypa.io/setuptools.prefix}}/lib/python$PYVER/site-packages:{{deps.github.com/pybind/pybind11.prefix}}/lib/python$PYVER/site-packages"
python3 -m pip install $ARGS .
EOT
    },
  ]
}

runtime {
  env = {
    # Chained, so a caller's own PYTHONPATH survives.
    PYTHONPATH = "{{prefix}}/lib/python{{deps.python.org.version.major}}.{{deps.python.org.version.minor}}/site-packages:$PYTHONPATH"
  }
}

test {
  script = [
    # ⛔ EVERY FEATURE, BY NAME, ASSERTED BOTH WAYS. `PIL.features.check` is the
    # library's own account of what it was built with (src/PIL/features.py:
    # modules :17-23, codecs :73-77, features :126-134), and it is the only place
    # a silently missing library shows up after the build.
    {
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
cat > features_probe.py <<'PYEOF'
import sys
from PIL import features

required = [
    "pil", "zlib", "jpg", "libtiff", "freetype2", "littlecms2", "webp",
    "jpg_2000", "xcb", "libjpeg_turbo", "tkinter",
]
refused = ["raqm", "avif", "libimagequant"]

bad = [f for f in required if not features.check(f)]
bad += [f + " (refused, but present)" for f in refused if features.check(f)]
for f in required + refused:
    print(f, features.check(f), features.version(f))
if bad:
    sys.exit("features wrong: " + ", ".join(bad))
if not features.version("pil").startswith("{{version.raw}}"):
    sys.exit("Pillow reports " + str(features.version("pil")))

# The libraries are the ones of OUR prefixes: each version begins with the
# major.minor of the dependency that was declared.
want = {
    "freetype2": "{{deps.freetype.org.version.major}}.{{deps.freetype.org.version.minor}}",
    "jpg_2000": "{{deps.openjpeg.org.version.major}}.{{deps.openjpeg.org.version.minor}}",
    "libtiff": "{{deps.simplesystems.org/libtiff.version.major}}.{{deps.simplesystems.org/libtiff.version.minor}}",
    "webp": "{{deps.google.com/webp.version.major}}.{{deps.google.com/webp.version.minor}}",
    "littlecms2": "{{deps.littlecms.com.version.major}}.",
}
for f, prefix in want.items():
    v = features.version(f)
    if not (v or "").startswith(prefix):
        sys.exit(f + " reports " + str(v) + ", declared " + prefix)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 features_probe.py
EOT
    },

    # ⛔ EVERY FORMAT HAS TO READ BACK WHAT IT WROTE. `features.check` says a
    # library was linked; this says it works. Lossless paths compare pixels, the
    # lossy one compares within a bound, and each is asked for by the codec that
    # needs the library under test (zlib: PNG and TIFF deflate; libtiff: LZW and
    # deflate; libjpeg: JPEG; openjpeg: JPEG 2000; libwebp: lossless WebP).
    {
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
cat > formats_probe.py <<'PYEOF'
import io, sys
from PIL import Image, ImageChops

im = Image.new("RGB", (64, 48))
im.putdata([(x * 4, y * 5, (x + y) * 2) for y in range(48) for x in range(64)])

def worst_error(a, b):
    return max(hi for lo, hi in ImageChops.difference(a, b).getextrema())

def roundtrip(fmt, **kw):
    buf = io.BytesIO()
    im.save(buf, fmt, **kw)
    data = buf.getvalue()
    assert len(data) > 0, fmt
    out = Image.open(io.BytesIO(data))
    out.load()
    assert out.format == fmt, (fmt, out.format)
    assert out.size == im.size, (fmt, out.size)
    return out.convert("RGB")

def same(fmt, **kw):
    out = roundtrip(fmt, **kw)
    if ImageChops.difference(im, out).getbbox() is not None:
        sys.exit(fmt + " " + repr(kw) + ": the pixels changed on a lossless path")
    print(fmt, kw, "identical")

same("PNG")
same("BMP")
same("TIFF")
same("TIFF", compression="tiff_lzw")
same("TIFF", compression="tiff_adobe_deflate")
same("WEBP", lossless=True)
same("JPEG2000", irreversible=False)

for fmt, kw, bound in (
    ("JPEG", dict(quality=95, subsampling=0), 12),
    ("TIFF", dict(compression="jpeg"), 24),
    ("WEBP", dict(quality=90), 24),
):
    worst = worst_error(im, roundtrip(fmt, **kw))
    assert worst <= bound, (fmt, kw, worst)
    print(fmt, kw, "worst channel error", worst)
print("all formats read back what they wrote")
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 formats_probe.py
EOT
    },

    # ⛔ FREETYPE DRAWS, LITTLE CMS CONVERTS. load_default() returns a
    # FreeTypeFont only when `_imagingft` imported (ImageFont.py:1108), so a
    # build that lost FreeType hands back the bitmap fallback and fails here.
    {
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
cat > engines_probe.py <<'PYEOF'
import sys
from PIL import Image, ImageChops, ImageCms, ImageDraw, ImageFont

font = ImageFont.load_default(size=18)
assert isinstance(font, ImageFont.FreeTypeFont), type(font)
canvas = Image.new("L", (160, 40), 0)
ImageDraw.Draw(canvas).text((4, 4), "Pillow", fill=255, font=font)
assert canvas.getbbox() is not None, "FreeType drew nothing"
assert font.getlength("Pillow") > 20, font.getlength("Pillow")

srgb = ImageCms.createProfile("sRGB")
lab = ImageCms.createProfile("LAB")

# sRGB -> sRGB is the identity to within one step.
same = ImageCms.buildTransform(srgb, srgb, "RGB", "RGB")
src = Image.new("RGB", (16, 16))
src.putdata([(x * 16, 255 - y * 16, 99) for y in range(16) for x in range(16)])
out = ImageCms.applyTransform(src, same)
worst = max(hi for lo, hi in ImageChops.difference(src, out).getextrema())
assert worst <= 1, worst

# sRGB -> Lab puts white at the top of the lightness scale and black at the bottom.
there = ImageCms.buildTransform(srgb, lab, "RGB", "LAB")
white = ImageCms.applyTransform(Image.new("RGB", (1, 1), (255, 255, 255)), there).getpixel((0, 0))
black = ImageCms.applyTransform(Image.new("RGB", (1, 1), (0, 0, 0)), there).getpixel((0, 0))
assert white[0] >= 250 and black[0] <= 5, (white, black)
print("FreeType drew; Little CMS: sRGB identity within", worst, "white", white, "black", black)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 engines_probe.py
EOT
    },

    # ⭐ ImageTk, AGAINST THE TK THE INTERPRETER LOADED (Tk 9.0.4 here). Pillow
    # compiles against no Tcl or Tk header of ours: src/Tk/_tkmini.h:1 is "Small
    # excerpts from the Tcl / Tk 8.6 headers", and the five functions it calls
    # (Tcl_CreateCommand, Tcl_AppendResult, Tk_PhotoGetImage, Tk_FindPhoto,
    # Tk_PhotoPutBlock) are looked up with dlsym in `_tkinter` when
    # `PIL._imagingtk` is IMPORTED (src/Tk/tkImaging.c:374-421, run from the
    # Py_mod_exec slot at src/_imagingtk.c:52). So the import below is the live
    # check that Tk 9's library exports all five; the signatures were compared
    # with Tk 9.0.4's own tkDecls.h and tcl.h (identical, `int` arguments).
    {
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
cat > tk_probe.py <<'PYEOF'
import tkinter, _tkinter
from PIL import _imagingtk

t = tkinter.Tcl()
_imagingtk.tkinit(t.interpaddr())
cmds = t.tk.call("info", "commands", "PyImagingPhoto*")
assert "PyImagingPhoto" in str(cmds), cmds
print("ImageTk registered", cmds, "in Tcl", t.tk.call("info", "patchlevel"), "Tk", _tkinter.TK_VERSION)
PYEOF
PYTHONPATH="{{prefix}}/lib/python$PYVER/site-packages" python3 tk_probe.py
EOT
    },

    # ⛔ THE EXTENSION MODULES HAVE TO RESOLVE OUR LIBRARIES, not a copy on the
    # machine. With no LD_LIBRARY_PATH / DYLD_LIBRARY_PATH set, the loader's own
    # listing of each module must name the prefix of the dependency it was built
    # against.
    {
      run = <<EOT
set -eu
PYVER=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
SITE="{{prefix}}/lib/python$PYVER/site-packages/PIL"
# On Linux ldd prints the resolved path. On darwin the install names are
# @rpath/..., so the LC_RPATH entries (otool -l) carry the prefixes.
list_libs() {
  if [ "$(uname)" = Darwin ]; then
    otool -L "$1"
    otool -l "$1"
  else
    ldd "$1"
  fi
}
list_libs "$SITE"/_imaging.*so > link-imaging.txt
list_libs "$SITE"/_imagingft.*so > link-ft.txt
list_libs "$SITE"/_imagingcms.*so > link-cms.txt
list_libs "$SITE"/_webp.*so > link-webp.txt
for want in "{{deps.libjpeg-turbo.org.prefix}}" "{{deps.simplesystems.org/libtiff.prefix}}" "{{deps.openjpeg.org.prefix}}" "{{deps.zlib.net.prefix}}" "{{deps.x.org/xcb.prefix}}"; do
  grep -q "$want" link-imaging.txt || { echo "_imaging does not link $want" >&2; cat link-imaging.txt >&2; exit 1; }
done
grep -q "{{deps.freetype.org.prefix}}" link-ft.txt || { echo "_imagingft does not link freetype" >&2; cat link-ft.txt >&2; exit 1; }
grep -q "{{deps.littlecms.com.prefix}}" link-cms.txt || { echo "_imagingcms does not link lcms2" >&2; cat link-cms.txt >&2; exit 1; }
grep -q "{{deps.google.com/webp.prefix}}" link-webp.txt || { echo "_webp does not link libwebp" >&2; cat link-webp.txt >&2; exit 1; }
EOT
    },
  ]
}

provenance {
  read = [
    "setup.py",                      # :311-327 the eleven features and `required = {jpeg, zlib}`; :388-438 finalize_options, `enable` adds to `required` (:421-423); :509-543 the `<NAME>_ROOT` table (xcb absent); :565-573 include and library path variables; :589-699 platform guessing; :731-897 every probe; :899-903 and :1122-1129 the fatal DependencyException; :1054-1061 the silent summary",
    "_custom_build/backend.py",      # :13-18 config settings become --pillow-configuration; :5 the backend IS setuptools.build_meta
    "pyproject.toml",                # :2-6 build requires pybind11 and setuptools>=77; :18 license MIT-CMU
    "src/PIL/features.py",           # :17-23 modules, :73-77 codecs, :126-134 features: what the test asks `check` about
    "src/_imagingtk.c",              # :52 the Py_mod_exec slot that runs load_tkinter_funcs at import
    "src/Tk/tkImaging.c",            # :374-421 dlsym of five symbols from the loaded _tkinter
    "src/Tk/_tkmini.h",              # :1 "Small excerpts from the Tcl / Tk 8.6 headers": no Tk header of ours is compiled against
    "docs/installation/building-from-source.rst", # :65-96 libimagequant (GPLv3, :68), libraqm (HarfBuzz and FriBiDi, :77), libavif (codecs, :95-96); :282-298 the -C flags
  ]

  consulted = [
    # Read for facts only: the pantry names five `-C` flags, a Tcl 8 dependency
    # and the PyPI-less GitHub archive; none of that is copied.
    "pkgxdev/pantry projects/python-pillow.org/package.yml",
    "pypi.org/integrity/pillow/13.0.0/pillow-13.0.0.tar.gz/provenance",
    "pypi.org/pypi/pillow/13.0.0/json",
    "github.com/tcltk/tcl core-9-0-4 generic/tcl.h :560-561 (Tcl_CmdProc keeps `int argc`)",
    "github.com/tcltk/tk core-9-0-4 generic/tkDecls.h (Tk_FindPhoto, Tk_PhotoGetImage, Tk_PhotoPutBlock) and generic/tk.h:1299-1310 (Tk_PhotoImageBlock)",
  ]

  note = <<EOT
⭐⭐ PILLOW LEAVES OUT A LIBRARY IT DOES NOT FIND AND EXITS 0. Eleven features
(setup.py:311-327), two of them required by default (:327), and for the other
nine a miss is one `*** … support not available` line (:1061) in the middle of a
build log. The only thing that makes a feature fatal is `-C <feature>=enable`,
which reaches the backend through --pillow-configuration
(_custom_build/backend.py:13-18), is added to `required` (setup.py:421-423) and
raises at :899-903. This recipe names EIGHT that way (zlib jpeg tiff freetype
lcms webp jpeg2000 xcb) and refuses THREE with `-C <feature>=disable`; the test
asserts all eleven with `PIL.features.check`, then reads each format back.

⛔ THREE FEATURES ARE REFUSED, each with its reason in the build block:
  - raqm: needs HarfBuzz and FriBiDi (building-from-source.rst:77), neither a
    recipe of this tree. Text layout falls back to FreeType alone.
  - avif: libavif is an API over codecs (aom, dav1d, rav1e, SVT-AV1), none a
    recipe of this tree. AVIF is NEITHER READ NOR WRITTEN by this build; that is
    the one image FORMAT of Pillow's list that is absent, and it is absent by
    name.
  - imagequant: GPLv3 (building-from-source.rst:68), which would make the licence
    field above wrong.
Writing HarfBuzz, FriBiDi, libavif and an AV1 codec would lift the first two
refusals; libimagequant stays refused for its licence.

⭐ ImageTk NEEDS NO Tk OF OURS AT BUILD TIME, AND RUNS AGAINST Tk 9.0.4. Pillow
compiles against excerpts of the 8.6 headers (src/Tk/_tkmini.h:1) and resolves
five Tcl/Tk functions with dlsym in whatever `_tkinter` the interpreter loaded
(src/Tk/tkImaging.c:374-421), at the moment `PIL._imagingtk` is imported
(src/_imagingtk.c:52). python.org (3.15) is built against tcl-lang.org and
tcl-lang.org/tk at ^9 (python.org:100-101), so that is the Tk it meets. The
pantry's `tcl.tk/tcl: ^8` dependency is dropped: nothing here links it, and a
Tcl 8 beside a Tk 9 would be a mismatch Pillow could not see. The five
signatures were compared with Tk 9.0.4's tkDecls.h and Tcl 9.0.4's tcl.h and
match the excerpts; the test imports the module and registers the command.

⛔ NO libpng. Pillow decodes PNG itself, through zlib (the `zlib` feature is
named "ZLIB (PNG/ZIP)", setup.py:1042); libpng reaches this artifact only
through freetype.org and openjpeg.org, which declare it.

⛔ NO GUESSING. `-C platform-guessing=disable` turns off the Homebrew, MacPorts,
fink, /usr/local and /usr/lib search (setup.py:589-699); each library is handed
over by `<NAME>_ROOT` instead, with an explicit rpath, and the test lists each
extension module's own dependencies to prove it. xcb is the odd one: it has no
`_ROOT` (setup.py:509-522) and is passed through C_INCLUDE_PATH and LIBRARY_PATH.

⚠ THE SIGNATURE IS NOT VERIFIED. PyPI serves a PEP 740 attestation for this
sdist; its statement names the file and the digest and its publisher is
python-pillow/Pillow's wheels.yml, but the sigstore bundle was not checked here.

⛔ NOT BUILT BY THE FACTORY, BUT THE FLAGS AND THE PROBES WERE RUN. On
darwin/arm64, with a host CPython 3.12.12, setuptools 84.2.1 built from this
tree's setuptools recipe, pybind11 from an index, and Homebrew's libraries
standing in for ours (the `<NAME>_ROOT` variables pointed at them): the same
pip command and all twelve `--config-settings` built Pillow 13.0.0;
`features.check` answered true for the eleven required names and false for
raqm, avif and libimagequant; the format probe read back what it wrote for PNG,
BMP, TIFF (raw, LZW, deflate, JPEG), WebP (lossless and lossy), JPEG and JPEG
2000; PIL._imagingtk imported against that interpreter's Tk 9.0 and registered
PyImagingPhoto. And `-C avif=enable` with no libavif FAILED the build with
"The headers or library files could not be found for avif, which was requested
by the option flag '-C avif=enable'" (rc=1), which is the claim of the first
paragraph measured. What was NOT run: the build against OUR libraries, the
linkage step, and the test as one script inside the factory's sandbox. Two
probe thresholds were wrong the first time (a Lab round trip through 8-bit Lab
is not within 2; a noisy test image breaks lossy WebP) and were corrected from
that run.
EOT
}
