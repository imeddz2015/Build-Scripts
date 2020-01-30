#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script builds grep from sources.

GREP_XZ=grep-3.3.tar.xz
GREP_TAR=grep-3.3.tar
GREP_DIR=grep-3.3

###############################################################################

CURR_DIR=$(pwd)
function finish {
    cd "$CURR_DIR"
}
trap finish EXIT

# Sets the number of make jobs if not set in environment
: "${INSTX_JOBS:=4}"

###############################################################################

# Get the environment as needed. We can't export it because it includes arrays.
if ! source ./setup-environ.sh
then
    echo "Failed to set environment"
    exit 1
fi

# The password should die when this subshell goes out of scope
if [[ -z "$SUDO_PASSWORD" ]]; then
    source ./setup-password.sh
fi

###############################################################################

if ! ./build-cacert.sh
then
    echo "Failed to install CA Certs"
    exit 1
fi

###############################################################################

if ! ./build-iconv-gettext.sh
then
    echo "Failed to build iConv and GetText"
    exit 1
fi

###############################################################################

if ! ./build-pcre2.sh
then
    echo "Failed to build PCRE2"
    exit 1
fi

###############################################################################

if false; then

# For libint.h, https://stackoverflow.com/q/11370684/608639
if ! ./build-gnulib.sh
then
    echo "Failed to build GnuLib"
    exit 1
fi

fi

###############################################################################

echo
echo "********** Grep **********"
echo

if ! "$WGET" -O "$GREP_XZ" --ca-certificate="$LETS_ENCRYPT_ROOT" \
     "https://ftp.gnu.org/gnu/grep/$GREP_XZ"
then
    echo "Failed to download Grep"
    exit 1
fi

rm -rf "$GREP_DIR" &>/dev/null
unxz "$GREP_XZ" && tar -xf "$GREP_TAR"
cd "$GREP_DIR"

# Fix sys_lib_dlsearch_path_spec and keep the file time in the past
../fix-config.sh

    PKG_CONFIG_PATH="${BUILD_PKGCONFIG[*]}" \
    CPPFLAGS="${BUILD_CPPFLAGS[*]}" \
    CFLAGS="${BUILD_CFLAGS[*]}" \
    CXXFLAGS="${BUILD_CXXFLAGS[*]}" \
    LDFLAGS="${BUILD_LDFLAGS[*]}" \
    LIBS="${BUILD_LIBS[*]}" \
./configure --prefix="$INSTX_PREFIX" --libdir="$INSTX_LIBDIR" \
    --with-libiconv-prefix="$INSTX_PREFIX" \
    --with-libintl-prefix="$INSTX_PREFIX" \
    --with-openssl=yes

if [[ "$?" -ne 0 ]]; then
    echo "Failed to configure Grep"
    exit 1
fi

echo "**********************"
echo "Building package"
echo "**********************"

MAKE_FLAGS=("-j" "$INSTX_JOBS")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to build Grep"
    exit 1
fi

echo "**********************"
echo "Testing package"
echo "**********************"

MAKE_FLAGS=("check")
if ! "$MAKE" "${MAKE_FLAGS[@]}"
then
    echo "Failed to test Grep"
    exit 1
fi

echo "Searching for errors hidden in log files"
COUNT=$(find . -name '*.log' -exec grep -o 'runtime error:' {} \; | wc -l)
if [[ "${COUNT}" -ne 0 ]];
then
    echo "Failed to test Grep"
    exit 1
fi

echo "**********************"
echo "Installing package"
echo "**********************"

MAKE_FLAGS=("install")
if [[ -n "$SUDO_PASSWORD" ]]; then
    echo "$SUDO_PASSWORD" | sudo -S "$MAKE" "${MAKE_FLAGS[@]}"
else
    "$MAKE" "${MAKE_FLAGS[@]}"
fi

cd "$CURR_DIR"

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "*****************************************************************************"

###############################################################################

# Set to false to retain artifacts
if true; then

    ARTIFACTS=("$GREP_XZ" "$GREP_TAR" "$GREP_DIR")
    for artifact in "${ARTIFACTS[@]}"; do
        rm -rf "$artifact"
    done

    # ./build-grep.sh 2>&1 | tee build-grep.log
    if [[ -e build-grep.log ]]; then
        rm -f build-grep.log
    fi
fi

exit 0
