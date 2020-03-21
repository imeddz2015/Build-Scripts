#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds Guile from sources. Guile has a lot of issues
# and I am not sure all of them can be worked around.
#
# Requires libtool-ltdl-devel on Fedora.

GUILE_TAR=guile-2.2.4.tar.xz
GUILE_DIR=guile-2.2.4
PKG_NAME=guile

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR"
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=2}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

# Boehm garbage collector. Look in /usr/lib and /usr/lib64
if [[ "$IS_DEBIAN" -ne 0 ]]; then
    if [[ -z $(find /usr -maxdepth 2 -name libgc.so 2>/dev/null) ]]; then
        echo "Guile requires Boehm garbage collector. Please install libgc-dev."
        exit 1
    fi
elif [[ "$IS_FEDORA" -ne 0 ]]; then
    if [[ -z $(find /usr -maxdepth 2 -name libgc.so 2>/dev/null) ]]; then
        echo "Guile requires Boehm garbage collector. Please install gc-devel."
        exit 1
    fi
fi

if [[ -e "$INSTX_PACKAGE_CACHE/$PKG_NAME" ]]; then
    # Already installed, return success
    echo ""
    echo "$PKG_NAME is already installed."
    exit 0
fi

# The password should die when this subshell goes out of scope
if [[ "$SUDO_PASSWORD_SET" != "yes" ]]; then
    if ! source ./setup-password.sh
    then
        echo "Failed to process password"
        exit 1
    fi
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-gmp.sh
then
    echo "Failed to build GMP"
    exit 1
fi

###############################################################################

# Solaris is missing the Boehm GC. We have to build it. Ugh...
if [[ "$IS_SOLARIS" -eq 1 ]]; then
    if ! ./build-boehm-gc.sh
    then
        echo "Failed to build Boehm GC"
        exit 1
    fi
fi

###############################################################################

if ! ./build-libffi.sh
then
    echo "Failed to build libffi"
    exit 1
fi

###############################################################################

if ! ./build-unistr.sh
then
    echo "Failed to build Unistring"
    exit 1
fi

###############################################################################

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

echo
echo "********** Guile **********"
echo

if ! "$WGET" -O "$GUILE_TAR" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/guile/$GUILE_TAR"
then
    echo "Failed to download Guile"
    exit 1
fi

rm -rf "$GUILE_DIR" &>/dev/null
xz -d < "$GUILE_TAR" | tar xf -
cd "$GUILE_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
cp -p ../fix-config.sh .; ./fix-config.sh

CONFIG_OPTS=()
CONFIG_OPTS+=("--build=$AUTOCONF_BUILD")
CONFIG_OPTS+=("--prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--libdir=$INSTX_LIBDIR")
CONFIG_OPTS+=("--enable-shared")
CONFIG_OPTS+=("--enable-static")
CONFIG_OPTS+=("--with-pic")
CONFIG_OPTS+=("--disable-deprecated")
CONFIG_OPTS+=("--with-libgmp-prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--with-libunistring-prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--with-libiconv-prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--with-libltdl-prefix=$INSTX_PREFIX")
CONFIG_OPTS+=("--with-libintl-prefix=$INSTX_PREFIX")

# --with-bdw-gc="${BUILD_PKGCONFIG[*]}/"
# --disable-posix --disable-networking

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure \
    "${CONFIG_OPTS[@]}"

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Guile"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Guile"
    exit 1
fi

# Fix flags in *.pc files
cp -p ../fix-pc.sh .; ./fix-pc.sh

echo "**********************"
echo "Testing package"
echo "**********************"

# https://lists.gnu.org/archive/html/guile-devel/2017-10/msg00009.html
MAKE_FLAGS=("check" "V=1")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Guile"
    # exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' ! -name 'config.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Guile"
    # exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    printf "%s\n" "$SUDO_PASSWORD" | sudo -kS "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

# Set package status to installed. Delete the file to rebuild the package.
touch "$INSTX_PACKAGE_CACHE/$PKG_NAME"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$GUILE_TAR" "$GUILE_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-guile.sh 2>&1 | tee build-guile.log
    if [[ -e build-guile.log ]]; then
        rm -f build-guile.log
    fi
fi

exit 0
