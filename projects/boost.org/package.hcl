# boost.org — the Boost C++ libraries: ~180 header-only libraries and the
# ~25 that need compiling (Iostreams, Locale, Regex, Thread, Log, ...).
#
# ⛔ WRITTEN FROM BOOST'S OWN FILES (go-zpkg/packages#431), at 1.92.0, from the
# release archive's bootstrap.sh, libs/*/build/*.v2 and libs/iostreams/build.jam.
#
# ⭐⭐ WHAT WRITING IT FOUND: three compiled libraries decide their optional
# parts by LOOKING AT THE BUILD MACHINE and drop them without a word.
#
#   Iostreams  zlib, bzip2, lzma and zstd filters are each wrapped in
#              `ac.check-library` (libs/iostreams/build/Jamfile.v2:38,58,82,99):
#              the library is absent from the link and the filter classes are
#              simply not in libboost_iostreams. The upstream fragment declared
#              two of the four.
#   Regex      links ICU when its headers are on the compiler's search path
#              (libs/regex/build/Jamfile.v2:147-150, `check-target-builds`),
#              `--disable-icu` (:20) is the only switch.
#   Locale     picks its backends the same way: ICU (libs/locale/build/Jamfile.v2:222),
#              then iconv (:252), std and posix (:275, :343). The test reads
#              the backends back from the installed library.
#   Python     bootstrap.sh runs `python -c exit`; if that works it writes a
#              `using python` into project-config.jam (:168-186) and builds
#              Boost.Python against whatever interpreter the builder has.
#
# Every one is named below.

summary = "Boost: peer-reviewed portable C++ source libraries"

# LICENSE_1_0.txt: the Boost Software License 1.0. Individual libraries carry
# their own headers; none was audited one by one for this note, only the
# top-level licence file is cited.
license = "BSL-1.0"

# ⛔ WITHOUT `strip` THIS BLOCK RESOLVED NOTHING, and nothing said so until
# `zpkb lint --check-newest-pinned` (v0.94.0) did: "cannot resolve its newest
# version: versions: no candidate version matched". boostorg/boost tags every
# release `boost-X.Y.Z`, so no tag parsed as a version. Read from `gh release
# list -R boostorg/boost` on 2026-11-20: boost-1.93.0.beta1, boost-1.92.0,
# boost-1.92.0.beta1, boost-1.91.0-1. The betas are not releases; `-1` is a
# respin suffix the archive URL below does not spell, so it is ignored too.
versions {
  github = "boostorg/boost"
  strip  = "/^boost-/"
  ignore = ["/beta/", "/rc/", "/-[0-9]+$/"]
}

dependencies = {
  # Each is a filter of libboost_iostreams, and each is SILENTLY DROPPED by
  # b2 when its library is not found — so each is declared, and the test links
  # the four filters.
  "zlib.net"             = "*"
  "sourceware.org/bzip2" = "^1"
  "tukaani.org/xz"       = "^5"
  "facebook.com/zstd"    = "^1"
}

distributable {
  # archives.boost.io is where boost.org's download page points; the file is
  # the same tree the git tag holds, with the submodules already merged
  # (bootstrap.sh is at the root).
  url              = "https://archives.boost.io/release/{{version.raw}}/source/boost_{{version.major}}_{{version.minor}}_{{version.patch}}.tar.gz"
  strip-components = 1

  # 235384471 bytes. Recorded with `zpkb sourcepin`; the project's own digest
  # (boost_1_92_0.tar.gz.json, field "sha256", next to the archive) names the
  # same value, which is the second, independent source. The archive is
  # unsigned.
  sha256 = {
    "1.92.0" = "c4a3b310ddd2472416e091067166b0713be97c63f38c212c484ada022fd296ce"
  }
}

build {
  dependencies = {
    "gnu.org/make" = "*"
  }

  env {
    # bootstrap.sh options (bootstrap.sh:21-31 sets the defaults, :134-170 reads them)
    BOOTSTRAP = [
      "--prefix={{prefix}}",

      # ⛔⛔ 1. PYTHON. bootstrap.sh:166-186: unless --without-libraries names
      # python, a working `python` on PATH turns Boost.Python on. Removing
      # it from the library list sets flag_no_python (:103-106).
      "--without-libraries=python",

      # ⛔⛔ 2. ICU for Regex. bootstrap.sh:196-230 asks pkg-config for icu-uc
      # and then looks in /usr, /usr/local, /sw; `--without-icu` stops that
      # search. It does not stop b2 (see ARGS).
      "--without-icu",
    ]

    ARGS = [
      "install",
      "--prefix={{prefix}}",

      # ⛔⛔ 2 (again). libs/regex/build/Jamfile.v2:20,39 and libs/locale/build/Jamfile.v2:222:
      # even without ICU_PATH, b2 tries the compiler's default include path.
      "--disable-icu",
      "boost.locale.icu=off",

      # ⛔⛔ 3. LOCALE BACKENDS. libs/locale/build/Jamfile.v2:252-262 takes iconv
      # if libc has one or a separate libiconv links, and :269-272 refuses to
      # build when neither ICU nor iconv exists (not on Windows). Named on
      # so the iconv backend is not optional.
      "boost.locale.iconv=on",
    ]

    # Carried over unchanged from the fragment this replaces. headerpad leaves
    # room in the Mach-O header for the install_name_tool call below; -fPIC
    # makes the static archives linkable into shared objects on Linux.
    darwin {
      ARGS = [
        "linkflags=-Wl,-headerpad_max_install_names",
      ]
    }

    linux {
      ARGS = [
        "cxxflags=-fPIC",
        "linkflags=-fPIC",
      ]
    }
  }

  script = [
    "./bootstrap.sh $BOOTSTRAP",
    "./b2 $ARGS",
    {
      if                = "darwin"
      run               = <<EOT
for LIB in *.dylib; do
  install_name_tool -add_rpath @loader_path $LIB
  install_name_tool -add_rpath @loader_path/../../.. $LIB
done
EOT
      working-directory = "$${{prefix}}/lib"
    },
  ]

}

test {
  # libs/iostreams/src/{zlib,bzip2,lzma,zstd}.cpp are in libboost_iostreams
  # only when their library was found; a program that uses each filter fails
  # to LINK when one was dropped. The Locale part lists the backends the
  # build kept (localization_backend_manager::get_all_backends).
  fixture = <<EOT
#include <boost/iostreams/copy.hpp>
#include <boost/iostreams/filter/bzip2.hpp>
#include <boost/iostreams/filter/gzip.hpp>
#include <boost/iostreams/filter/lzma.hpp>
#include <boost/iostreams/filter/zlib.hpp>
#include <boost/iostreams/filter/zstd.hpp>
#include <boost/iostreams/filtering_stream.hpp>
#include <boost/locale/localization_backend.hpp>
#include <iostream>
#include <sstream>
#include <string>

namespace io = boost::iostreams;

template <class Compressor, class Decompressor>
static bool roundtrip(const char *name)
{
	const std::string in(4096, 'x');
	std::stringstream packed;
	{
		io::filtering_ostream out;
		out.push(Compressor());
		out.push(packed);
		out << in;
	}
	io::filtering_istream back;
	back.push(Decompressor());
	back.push(packed);
	std::string got;
	std::getline(back, got, '\0');
	if (got != in) {
		std::cerr << name << " round trip failed\n";
		return false;
	}
	return true;
}

int main()
{
	bool ok = true;
	ok &= roundtrip<io::zlib_compressor, io::zlib_decompressor>("zlib");
	ok &= roundtrip<io::gzip_compressor, io::gzip_decompressor>("gzip");
	ok &= roundtrip<io::bzip2_compressor, io::bzip2_decompressor>("bzip2");
	ok &= roundtrip<io::lzma_compressor, io::lzma_decompressor>("lzma");
	ok &= roundtrip<io::zstd_compressor, io::zstd_decompressor>("zstd");

	bool icu = false, std_be = false;
	for (const std::string &b : boost::locale::localization_backend_manager::global().get_all_backends()) {
		if (b == "icu") icu = true;
		if (b == "std" || b == "posix") std_be = true;
	}
	if (icu) { std::cerr << "ICU backend present, pinned off\n"; ok = false; }
	if (!std_be) { std::cerr << "no std/posix locale backend\n"; ok = false; }
	return ok ? 0 : 1;
}
EOT

  script = [
    "c++ -x c++ $FIXTURE -x none -std=c++17 -o probe -I{{prefix}}/include -L{{prefix}}/lib -lboost_iostreams -lboost_locale",
    {
      run = <<EOT
set -eu
LD_LIBRARY_PATH="{{prefix}}/lib:$${LD_LIBRARY_PATH:-}" DYLD_LIBRARY_PATH="{{prefix}}/lib:$${DYLD_LIBRARY_PATH:-}" ./probe
EOT
    },
  ]
}

provenance {
  read = [
    "bootstrap.sh",                       # :134-170 options, :166-186 python probe, :196-230 ICU search
    "libs/iostreams/build.jam",           # :35-52 NO_COMPRESSION/NO_ZLIB/NO_BZIP2, has_zlib
    "libs/iostreams/build/Jamfile.v2",    # :38,58,82,99 ac.check-library: silent drop of each filter
    "libs/locale/build/Jamfile.v2",       # :222 icu, :252 iconv, :269-272 refusal, :275/:343 std/posix
    "libs/regex/build/Jamfile.v2",        # :20 --disable-icu, :147-150 ICU by check-target-builds
    "libs/mpi/build/Jamfile.v2",          # :30 only built when mpi.configured
    "LICENSE_1_0.txt",
  ]

  consulted = [
    # Read for facts only: the download URL shape and the darwin rpath fix-up.
    "pkgxdev/pantry projects/boost.org/package.yml",
  ]

  note = <<EOT
⚠ NOT BUILT. No session here can run the factory; the build lines were read
from the project's files, not executed. The darwin/linux flag blocks and the
rpath fix-up are the fragment's own, kept as they were.
EOT
}
