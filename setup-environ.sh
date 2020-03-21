#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script verifies most prerequisites and creates
# an environment for other scripts to execute in.

###############################################################################

# SC2034: XXX appears unused. Verify use (or export if used externally).
# shellcheck disable=SC2034

###############################################################################

# Can't apply the fixup reliably. Ancient Bash causes build scripts
# to die after setting the environment. TODO... figure it out.

# Fixup ancient Bash
# https://unix.stackexchange.com/q/468579/56041
#if [[ -z "$BASH_SOURCE" ]]; then
#    BASH_SOURCE="$0"
#fi

###############################################################################

# Prerequisites needed for nearly all packages. Set to false to skip check.

if [[ "$INSTX_DISABLE_PKGCONFIG_CHECK" -ne 1 ]]
then
    if [[ -z $(command -v pkg-config 2>/dev/null) ]]; then
        echo "Some packages require Package-Config. Please install pkg-config."
        [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
    fi
fi

if [[ -z $(command -v gzip 2>/dev/null) ]]; then
    echo "Some packages require Gzip. Please install Gzip."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

if [[ -z $(command -v tar 2>/dev/null) ]]; then
    echo "Some packages require Tar. Please install Tar."
    [[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1
fi

###############################################################################

LETS_ENCRYPT_ROOT="$HOME/.cacert/lets-encrypt-root-x3.pem"
IDENTRUST_ROOT="$HOME/.cacert/identrust-root-x3.pem"
GO_DADDY_ROOT="$HOME/.cacert/godaddy-root-ca.pem"
DIGICERT_ROOT="$HOME/.cacert/digicert-root-ca.pem"
DIGITRUST_ROOT="$HOME/.cacert/digitrust-root-ca.pem"
GLOBALSIGN_ROOT="$HOME/.cacert/globalsign-root-r1.pem"
USERTRUST_ROOT="$HOME/.cacert/usertrust-root-ca.pem"

# Some downloads need the CA Zoo due to multiple redirects
CA_ZOO="$HOME/.cacert/cacert.pem"

###############################################################################

CURR_DIR=$(pwd)

# `gcc ... -o /dev/null` does not work on Solaris due to LD bug.
# `mktemp` is not available on AIX or Git Windows shell...
infile="in.$RANDOM$RANDOM.c"
outfile="out.$RANDOM$RANDOM"
echo 'int main(int argc, char* argv[]) {return 0;}' > "$infile"
echo "" >> "$infile"

function finish {
  rm -f "$CURR_DIR/$infile" 2>/dev/null
  rm -f "$CURR_DIR/$outfile" 2>/dev/null
  rm -rf "$CURR_DIR/$outfile.dSYM" 2>/dev/null
    cd "$CURR_DIR" || exit 1
}
trap finish EXIT

###############################################################################

# Autotools on Solaris has an implied requirement for GNU gear. Things fall apart without it.
# Also see https://blogs.oracle.com/partnertech/entry/preparing_for_the_upcoming_removal.
if [[ -d "/usr/gnu/bin" ]]; then
    if [[ ! ("$PATH" == *"/usr/gnu/bin"*) ]]; then
        echo
        echo "Adding /usr/gnu/bin to PATH for Solaris"
        export PATH="/usr/gnu/bin:$PATH"
    fi
elif [[ -d "/usr/swf/bin" ]]; then
    if [[ ! ("$PATH" == *"/usr/sfw/bin"*) ]]; then
        echo
        echo "Adding /usr/sfw/bin to PATH for Solaris"
        export PATH="/usr/sfw/bin:$PATH"
    fi
elif [[ -d "/usr/ucb/bin" ]]; then
    if [[ ! ("$PATH" == *"/usr/ucb/bin"*) ]]; then
        echo
        echo "Adding /usr/ucb/bin to PATH for Solaris"
        export PATH="/usr/ucb/bin:$PATH"
    fi
fi

###############################################################################

# Wget is special. We have to be able to bootstrap it and
# use a modern version throughout these scripts.

if [[ -z "$WGET" ]]; then
    if [[ -e "$HOME/.buildscripts/wget/bin/wget" ]]; then
        WGET="$HOME/.buildscripts/wget/bin/wget"
    elif [[ -e "/usr/local/bin/wget" ]]; then
        WGET="/usr/local/bin/wget"
    elif [[ -n $(command -v wget) ]]; then
        WGET=$(command -v wget)
    else
        WGET=wget
    fi
fi

###############################################################################

THIS_SYSTEM=$(uname -s 2>&1)
IS_LINUX=$(echo -n "$THIS_SYSTEM" | grep -i -c 'linux')
IS_SOLARIS=$(echo -n "$THIS_SYSTEM" | grep -i -c 'sunos')
IS_DARWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c 'darwin')
IS_AIX=$(echo -n "$THIS_SYSTEM" | grep -i -c 'aix')
IS_CYGWIN=$(echo -n "$THIS_SYSTEM" | grep -i -c 'cygwin')
IS_OPENBSD=$(echo -n "$THIS_SYSTEM" | grep -i -c 'openbsd')
IS_FREEBSD=$(echo -n "$THIS_SYSTEM" | grep -i -c 'freebsd')
IS_NETBSD=$(echo -n "$THIS_SYSTEM" | grep -i -c 'netbsd')
IS_BSD_FAMILY=$(echo -n "$THIS_SYSTEM" | grep -i -c -E 'dragonfly|freebsd|netbsd|openbsd')

# Red Hat and derivatives use /lib64, not /lib.
IS_REDHAT=$(grep -i -c 'redhat' /etc/redhat-release 2>/dev/null)
IS_CENTOS=$(grep -i -c 'centos' /etc/centos-release 2>/dev/null)
IS_FEDORA=$(grep -i -c 'fedora' /etc/fedora-release 2>/dev/null)

OSX_VERSION=$(system_profiler SPSoftwareDataType 2>&1 | grep 'System Version:' | awk '{print $6}')
OSX_1010_OR_ABOVE=$(echo -n "$OSX_VERSION" | grep -i -c -E "(^10.10|^1[1-9].|^[2-9][0-9])")

if [[ "$IS_REDHAT" -ne 0 ]] || [[ "$IS_CENTOS" -ne 0 ]] || [[ "$IS_FEDORA" -ne 0 ]]
then
    IS_RH_FAMILY=1
else
    IS_RH_FAMILY=0
fi

# Fix decades old compile and link errors on early Darwin.
# https://gmplib.org/list-archives/gmp-bugs/2009-May/001423.html
IS_OLD_DARWIN=$(system_profiler SPSoftwareDataType 2>/dev/null | grep -i -c -E "OS X 10\.[0-5]")

THIS_MACHINE=$(uname -m 2>&1)
IS_IA32=$(echo -n "$THIS_MACHINE" | grep -E -i -c 'i86pc|i.86|amd64|x86_64')
IS_AMD64=$(echo -n "$THIS_MACHINE" | grep -E -i -c 'amd64|x86_64')
IS_MIPS=$(echo -n "$THIS_MACHINE" | grep -E -i -c 'mips')

# The BSDs and Solaris should have GMake installed if its needed
if [[ -z "$MAKE" ]]; then
    if [[ $(command -v gmake 2>/dev/null) ]]; then
        MAKE="gmake"
    else
        MAKE="make"
    fi
fi

# If CC and CXX are not set, then use default or assume GCC
if [[ -z "$CC" ]] && [[ -n "$(command -v gcc)" ]]; then export CC='gcc'; fi
if [[ -z "$CC" ]] && [[ -n "$(command -v cc)" ]]; then export CC='cc'; fi
if [[ -z "$CXX" ]] && [[ -n "$(command -v g++)" ]]; then export CXX='g++'; fi
if [[ -z "$CXX" ]] && [[ -n "$(command -v CC)" ]]; then export CXX='CC'; fi

IS_GCC=$("$CC" --version 2>&1 | grep -i -c 'gcc')
IS_CLANG=$("$CC" --version 2>&1 | grep -i -c -E 'clang|llvm')
IS_SUNC=$("$CC" -V 2>&1 | grep -i -c -E 'sun|studio')
TEST_CC="$CC"

# Where the package will run. We need to override for 64-bit Solaris.
# On Solaris some Autotools packages use 32-bit instead of 64-bit build.
AUTOCONF_BUILD=$(bash patch/config.guess 2>/dev/null)

###############################################################################

# Use 64-bit for Solaris if available
# https://docs.oracle.com/cd/E37838_01/html/E66175/features-1.html

if [[ "$IS_SOLARIS" -ne 0 ]]
then
    if [[ $(isainfo -b 2>/dev/null) = 64 ]]; then
        CFLAGS64=-m64
        TEST_CC="$TEST_CC -m64"
    fi
fi

###############################################################################

# Try to determine 32 vs 64-bit, /usr/local/lib, /usr/local/lib32,
# /usr/local/lib64 and /usr/local/lib/64. We drive a test compile
# using the supplied compiler and flags.
if $TEST_CC $CFLAGS bootstrap/bitness.c -o /dev/null &>/dev/null
then
    IS_64BIT=1
    IS_32BIT=0
    INSTX_BITNESS=64
else
    IS_64BIT=0
    IS_32BIT=1
    INSTX_BITNESS=32
fi

# Don't override a user choice of INSTX_PREFIX
if [[ -z "$INSTX_PREFIX" ]]; then
    INSTX_PREFIX="/usr/local"
fi

# Don't override a user choice of INSTX_LIBDIR. Also see
# https://blogs.oracle.com/dipol/dynamic-libraries,-rpath,-and-mac-os
if [[ -z "$INSTX_LIBDIR" ]]
then
    #if [[ "$IS_64BIT" -ne 0 ]] && [[ "$IS_SOLARIS" -ne 0 ]]; then
    #    INSTX_LIBDIR="$INSTX_PREFIX/lib/64"
    #    INSTX_RPATH="'""\$\$ORIGIN/../lib/64""'"
    #elif [[ "$IS_SOLARIS" -ne 0 ]]; then
    #    INSTX_LIBDIR="$INSTX_PREFIX/lib/32"
    #    INSTX_RPATH="'""\$\$ORIGIN/../lib/32""'"

    if [[ "$IS_SOLARIS" -ne 0 ]]; then
        INSTX_LIBDIR="$INSTX_PREFIX/lib"
        INSTX_RPATH="'""\$\$ORIGIN/../lib""'"
    elif [[ "$IS_DARWIN" -ne 0 ]]; then
        INSTX_LIBDIR="$INSTX_PREFIX/lib"
        INSTX_RPATH="@loader_path/../lib"
    elif [[ "$IS_RH_FAMILY" -ne 0 ]] && [[ "$IS_64BIT" -ne 0 ]]; then
        INSTX_LIBDIR="$INSTX_PREFIX/lib64"
        INSTX_RPATH="'""\$\$ORIGIN/../lib64""'"
    else
        INSTX_LIBDIR="$INSTX_PREFIX/lib"
        INSTX_RPATH="'""\$\$ORIGIN/../lib""'"
    fi
fi

# Use a sane default
if [[ -z "$INSTX_RPATH" ]]; then
    INSTX_RPATH="$INSTX_LIBDIR"
fi

# Solaris Fixup
if [[ "$IS_IA32" -eq 1 ]] && [[ "$IS_64BIT" -eq 1 ]]; then
    IS_AMD64=1
fi

# Solaris Fixup
if [[ "$IS_SOLARIS" -eq 1 && "$IS_AMD64" -eq 1 ]]; then
    AUTOCONF_BUILD="amd64-sun-solaris"
fi

###############################################################################

SH_ERROR=$($TEST_CC -fPIC -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
if [[ "$SH_ERROR" -eq 0 ]]; then
    SH_PIC="-fPIC"
fi

# For the benefit of the programs and libraries. Make them run faster.
SH_ERROR=$($TEST_CC -march=native -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
if [[ "$SH_ERROR" -eq 0 ]]; then
    SH_NATIVE="-march=native"
fi

SH_ERROR=$($TEST_CC -pthread -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
if [[ "$SH_ERROR" -eq 0 ]]; then
    SH_PTHREAD="-pthread"
fi

# Switch from -march=native to something more appropriate
if [[ $(grep -i -c -E 'armv7' /proc/cpuinfo 2>/dev/null) -ne 0 ]]; then
    SH_ERROR=$($TEST_CC -march=armv7-a -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
    if [[ "$SH_ERROR" -eq 0 ]]; then
        SH_ARMV7="-march=armv7-a"
    fi
fi
# See if we can upgrade to ARMv7+NEON
if [[ $(grep -i -c -E 'neon' /proc/cpuinfo 2>/dev/null) -ne 0 ]]; then
    SH_ERROR=$($TEST_CC -march=armv7-a -mfpu=neon -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
    if [[ "$SH_ERROR" -eq 0 ]]; then
        IS_ARM_NEON=1
        SH_ARMV7="-march=armv7-a -mfpu=neon"
    fi
fi
# See if we can upgrade to ARMv8
if [[ $(uname -m 2>&1 | grep -i -c -E 'aarch32|aarch64') -ne 0 ]]; then
    SH_ERROR=$($TEST_CC -march=armv8-a -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
    if [[ "$SH_ERROR" -eq 0 ]]; then
        SH_ARMV8="-march=armv8-a"
    fi
fi

# See if -Wl,-rpath,$ORIGIN/../lib works
SH_ERROR=$($TEST_CC -Wl,-rpath,$INSTX_RPATH -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
if [[ "$SH_ERROR" -eq 0 ]]; then
    SH_OPATH="-Wl,-rpath,$INSTX_RPATH"
fi
SH_ERROR=$($TEST_CC -Wl,-R,$INSTX_RPATH -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
if [[ "$SH_ERROR" -eq 0 ]]; then
    SH_OPATH="-Wl,-R,$INSTX_RPATH"
fi

# See if -Wl,-rpath,/usr/loca/lib works
SH_ERROR=$($TEST_CC -Wl,-rpath,$INSTX_LIBDIR -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
if [[ "$SH_ERROR" -eq 0 ]]; then
    SH_RPATH="-Wl,-rpath,$INSTX_LIBDIR"
fi
SH_ERROR=$($TEST_CC -Wl,-R,$INSTX_LIBDIR -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
if [[ "$SH_ERROR" -eq 0 ]]; then
    SH_RPATH="-Wl,-R,$INSTX_LIBDIR"
fi

# See if RUNPATHs are available
SH_ERROR=$($TEST_CC -Wl,--enable-new-dtags -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
if [[ "$SH_ERROR" -eq 0 ]]; then
    SH_DTAGS="-Wl,--enable-new-dtags"
fi

SH_ERROR=$($TEST_CC -fopenmp -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
if [[ "$SH_ERROR" -eq 0 ]]; then
    SH_OPENMP="-fopenmp"
fi

SH_ERROR=$($TEST_CC -Wl,--no-as-needed -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
if [[ "$SH_ERROR" -eq 0 ]]; then
    SH_NO_AS_NEEDED="-Wl,--no-as-needed"
fi

# OS X linker and install names
SH_ERROR=$($TEST_CC -headerpad_max_install_names -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
if [[ "$SH_ERROR" -eq 0 ]]; then
    SH_INSTNAME="-headerpad_max_install_names"
fi

# Debug symbols
if [[ -z "$SH_SYM" ]]; then
    SH_ERROR=$($TEST_CC -g2 -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
    if [[ "$SH_ERROR" -eq 0 ]]; then
        SH_SYM="-g2"
    else
        SH_ERROR=$($TEST_CC -g -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
        if [[ "$SH_ERROR" -eq 0 ]]; then
            SH_SYM="-g"
        fi
    fi
fi

# Optimizations symbols
if [[ -z "$SH_OPT" ]]; then
    SH_ERROR=$($TEST_CC -O2 -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
    if [[ "$SH_ERROR" -eq 0 ]]; then
        SH_OPT="-O2"
    else
        SH_ERROR=$($TEST_CC -O -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
        if [[ "$SH_ERROR" -eq 0 ]]; then
            SH_OPT="-O"
        fi
    fi
fi

# OpenBSD does not have -ldl
if [[ -z "$SH_DL" ]]; then
    SH_ERROR=$($TEST_CC -o "$outfile" "$infile" -ldl 2>&1 | tr ' ' '\n' | wc -l)
    if [[ "$SH_ERROR" -eq 0 ]]; then
        SH_DL="-ldl"
    fi
fi

if [[ -z "$SH_LIBPTHREAD" ]]; then
    SH_ERROR=$($TEST_CC -o "$outfile" "$infile" -lpthread 2>&1 | tr ' ' '\n' | wc -l)
    if [[ "$SH_ERROR" -eq 0 ]]; then
        SH_LIBPTHREAD="-lpthread"
    fi
fi

# C++11 for Guile
SH_ERROR=$($TEST_CC -std=gnu11 -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
if [[ "$SH_ERROR" -eq 0 ]]; then
    SH_C11=1
else
    SH_ERROR=$($TEST_CC -std=c11 -o "$outfile" "$infile" 2>&1 | tr ' ' '\n' | wc -l)
    if [[ "$SH_ERROR" -eq 0 ]]; then
        SH_C11=1
    fi
fi

# Msan option
if [[ -z "$SH_MSAN_ORIGIN" ]]; then
    SH_ERROR=$($TEST_CC -o "$outfile" "$infile" -fsanitize-memory-track-origins 2>&1 | tr ' ' '\n' | wc -l)
    if [[ "$SH_ERROR" -eq 0 ]]; then
        SH_MSAN_ORIGIN=1
    fi
fi

###############################################################################

# CA cert path? Also see http://gagravarr.org/writing/openssl-certs/others.shtml
# For simplicity use $INSTX_PREFIX/etc/pki. Avoid about 10 different places.

SH_CACERT_PATH="$INSTX_PREFIX/etc/pki"
SH_CACERT_FILE="$INSTX_PREFIX/etc/pki/cacert.pem"
SH_UNBOUND_ROOTKEY_PATH="$INSTX_PREFIX/etc/unbound"
SH_UNBOUND_ROOTKEY_FILE="$INSTX_PREFIX/etc/unbound/root.key"
SH_UNBOUND_CACERT_PATH="$INSTX_PREFIX/etc/unbound"
SH_UNBOUND_CACERT_FILE="$INSTX_PREFIX/etc/unbound/icannbundle.pem"

###############################################################################

BUILD_PKGCONFIG=("$INSTX_LIBDIR/pkgconfig")
BUILD_CPPFLAGS=("-I$INSTX_PREFIX/include" "-DNDEBUG")
BUILD_CFLAGS=("$SH_SYM" "$SH_OPT")
BUILD_CXXFLAGS=("$SH_SYM" "$SH_OPT")
BUILD_LDFLAGS=("-L$INSTX_LIBDIR")
BUILD_LIBS=()

if [[ -n "$CFLAGS64" ]]
then
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="$CFLAGS64"
    BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="$CFLAGS64"
    BUILD_LDFLAGS[${#BUILD_LDFLAGS[@]}]="$CFLAGS64"
fi

# -fno-sanitize-recover causes an abort(). Useful for test
# programs that swallow UBsan output and pretty print "OK"
if [[ -n "$INSTX_UBSAN" ]]; then
    BUILD_CPPFLAGS[${#BUILD_CPPFLAGS[@]}]="-DTEST_UBSAN=1"
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="-fsanitize=undefined"
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="-fno-sanitize-recover"
    BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="-fsanitize=undefined"
    BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="-fno-sanitize-recover"
    BUILD_LDFLAGS[${#BUILD_LDFLAGS[@]}]="-fsanitize=undefined"
    BUILD_LDFLAGS[${#BUILD_LDFLAGS[@]}]="-fno-sanitize-recover"

elif [[ -n "$INSTX_ASAN" ]]; then
    BUILD_CPPFLAGS[${#BUILD_CPPFLAGS[@]}]="-DTEST_ASAN=1"
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="-fsanitize=address"
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="-fno-omit-frame-pointer"
    BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="-fsanitize=address"
    BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="-fno-omit-frame-pointer"
    BUILD_LDFLAGS[${#BUILD_LDFLAGS[@]}]="-fsanitize=address"

elif [[ -n "$INSTX_MSAN" ]]; then
    BUILD_CPPFLAGS[${#BUILD_CPPFLAGS[@]}]="-DTEST_MSAN=1"
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="-fsanitize=memory"
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="-fno-omit-frame-pointer"
    BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="-fsanitize=memory"
    BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="-fno-omit-frame-pointer"
    BUILD_LDFLAGS[${#BUILD_LDFLAGS[@]}]="-fsanitize=memory"
    BUILD_LDFLAGS[${#BUILD_LDFLAGS[@]}]="-fno-omit-frame-pointer"

    if [[ -n "$SH_MSAN_ORIGIN" ]]; then
        BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="-fsanitize-memory-track-origins"
        BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="-fsanitize-memory-track-origins"
        BUILD_LDFLAGS[${#BUILD_LDFLAGS[@]}]="-fsanitize-memory-track-origins"
    fi
fi

if [[ -n "$SH_ARMV8" ]]; then
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="$SH_ARMV8"
    BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="$SH_ARMV8"
elif [[ -n "$SH_ARMV7" ]]; then
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="$SH_ARMV7"
    BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="$SH_ARMV7"
elif [[ -n "$SH_NATIVE" ]]; then
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="$SH_NATIVE"
    BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="$SH_NATIVE"
fi

if [[ -n "$SH_PIC" ]]; then
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="$SH_PIC"
    BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="$SH_PIC"
fi

if [[ -n "$SH_PTHREAD" ]]; then
    BUILD_CFLAGS[${#BUILD_CFLAGS[@]}]="$SH_PTHREAD"
    BUILD_CXXFLAGS[${#BUILD_CXXFLAGS[@]}]="$SH_PTHREAD"
fi

if [[ -n "$SH_OPATH" ]]; then
    BUILD_LDFLAGS[${#BUILD_LDFLAGS[@]}]="$SH_OPATH"
fi

if [[ -n "$SH_RPATH" ]]; then
    BUILD_LDFLAGS[${#BUILD_LDFLAGS[@]}]="$SH_RPATH"
fi

if [[ -n "$SH_DTAGS" ]]; then
    BUILD_LDFLAGS[${#BUILD_LDFLAGS[@]}]="$SH_DTAGS"
fi

if [[ -n "$SH_DL" ]]; then
    BUILD_LIBS[${#BUILD_LIBS[@]}]="$SH_DL"
fi

if [[ -n "$SH_LIBPTHREAD" ]]; then
    BUILD_LIBS[${#BUILD_LIBS[@]}]="$SH_LIBPTHREAD"
fi

#if [[ "$IS_DARWIN" -ne 0 ]] && [[ -n "$SH_INSTNAME" ]]; then
#    BUILD_LDFLAGS+=("$SH_INSTNAME")
#    BUILD_LDFLAGS[${#BUILD_LDFLAGS[@]}]="$SH_INSTNAME"
#fi

# Used to track packages that have been built by these scripts.
# The accounting is local to a user account. There is no harm
# in rebuilding a package under another account. In April 2019
# we added INSTX_PREFIX so we could build packages in multiple
# locations. For example, /usr/local for updated packages, and
# /var/sanitize for testing packages.
if [[ -z "$INSTX_CACHE" ]]; then
    # Change / to - for CACHE_DIR
    CACHE_DIR=$(echo "$INSTX_PREFIX" | cut -c 2- | sed 's/\//-/g')
    INSTX_CACHE="$HOME/.build-scripts/$CACHE_DIR"
    mkdir -p "$INSTX_CACHE"
fi

###############################################################################

# NetBSD only puts /usr/lib on path. NetBSD does not use ldconf.
# Many build systems assume can get past configure.
# NetBSD ELF FAQ, https://www.netbsd.org/docs/elf.html
if [[ "$IS_NETBSD" -ne 0 ]]
then
    LD_LIBRARY_PATH="$INSTX_LIBDIR:$LD_LIBRARY_PATH"
    LD_LIBRARY_PATH=$(echo -n "$LD_LIBRARY_PATH" | sed 's/:$//')
    export LD_LIBRARY_PATH
fi

###############################################################################

# If the package is older than 7 days, then rebuild it. This sidesteps the
# problem of continually rebuilding the same package when installing a
# program like Git and SSH. It also avoids version tracking by automatically
# building a package after 7 days (even if it is the same version).
for pkg in $(find "$INSTX_CACHE" -type f -mtime +7 2>/dev/null);
do
    # echo "Setting $pkg for rebuild"
    rm -f "$pkg" 2>/dev/null
done

###############################################################################

# Print a summary once
if [[ -z "$PRINT_ONCE" ]]; then

    if [[ "$IS_SOLARIS" -ne 0 ]]; then
        echo ""
        echo "Solaris tools:"
        echo ""
        echo "     sed: $(command -v sed)"
        echo "     awk: $(command -v awk)"
        echo "    grep: $(command -v grep)"
        if [[ -n "$LEX" ]]; then
            echo "     lex: $LEX"
        else
            echo "     lex: $(command -v lex)"
        fi
        if [[ -n "$YACC" ]]; then
            echo "     lex: $YACC"
        else
            echo "    yacc: $(command -v yacc)"
        fi
    fi

    echo ""
    echo "Common flags and options:"
    echo ""
    echo "  INSTX_BITNESS: $INSTX_BITNESS-bits"
    echo "   INSTX_PREFIX: $INSTX_PREFIX"
    echo "   INSTX_LIBDIR: $INSTX_LIBDIR"
    echo "    INSTX_RPATH: $INSTX_RPATH"
    echo ""
    echo " AUTOCONF_BUILD: $AUTOCONF_BUILD"
    echo "PKG_CONFIG_PATH: ${BUILD_PKGCONFIG[*]}"
    echo "       CPPFLAGS: ${BUILD_CPPFLAGS[*]}"
    echo "         CFLAGS: ${BUILD_CFLAGS[*]}"
    echo "       CXXFLAGS: ${BUILD_CXXFLAGS[*]}"
    echo "        LDFLAGS: ${BUILD_LDFLAGS[*]}"
    echo "         LDLIBS: ${BUILD_LIBS[*]}"
    echo ""

    echo " WGET: $WGET"
    if [[ -n "$SH_CACERT_PATH" ]]; then
        echo " SH_CACERT_PATH: $SH_CACERT_PATH"
    fi
    if [[ -n "$SH_CACERT_FILE" ]]; then
        echo " SH_CACERT_FILE: $SH_CACERT_FILE"
    fi

    export PRINT_ONCE="TRUE"
fi

[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 0 || return 0
