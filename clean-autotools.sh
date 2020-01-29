#!/usr/bin/env bash

# Written and placed in public domain by Jeffrey Walton
# This script cleans Autotools when Autotools was installed
# by build-autotools.sh at /usr/local.

# Run the script like so:
#
#    sudo ./clean-autotools.sh

###############################################################################

CURR_DIR=$(pwd)
function finish {
  cd "$CURR_DIR"
}
trap finish EXIT

###############################################################################

# The extra gyrations around Perl files are due to Perl's
# Autom4te::ChannelDefs getting whacked along with the
# Autotools files. Its non-trivial to reinstall the missing
# Perl files because the sources must be compiled again.

AUTOTOOLS=(autom4te autoconf automake autopoint autoreconf autoupdate autoheader autoscan aclocal)
for dir in "${AUTOTOOLS[@]}"; do
    find /usr/local -type d -name "$dir*" -exec rm -rf {} \; 2>/dev/null
done

for file in "${AUTOTOOLS[@]}"; do
    find /usr/local -type f -name "$file*" -exec rm -f {} \; 2>/dev/null
done

###############################################################################

echo ""
echo "*****************************************************************************"
echo "Please run Bash's 'hash -r' to update program cache in the current shell"
echo "You may need to update libtool if you did so previously."
echo "*****************************************************************************"

[[ "$0" = "${BASH_SOURCE[0]}" ]] && hash -r
