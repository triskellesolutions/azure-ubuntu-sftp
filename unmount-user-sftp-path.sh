#!/bin/bash
set -Eeo pipefail

# shellcheck disable=2154
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

user=$1

# sudo killall -u $user
# sudo umount /home/$user/uploads
# sudo umount /home/$user/downloads
# sudo chown -R $user /home/$user

code=0 && response=$(sudo killall -u $user 2>&1) || code=$?
if [ $code != 0 ]; then
    echo "killall failed:  ${response}"
fi

code=0 && response=$(sudo umount /home/$user/uploads  2>&1) || code=$?
if [ $code != 0 ]; then
    echo "umount failed:  ${response}"
fi

code=0 && response=$(sudo rm -fr /home/$user/uploads 2>&1) || code=$?
if [ $code != 0 ]; then
    echo "rm failed:  ${response}"
fi

code=0 && response=$(sudo umount /home/$user/downloads 2>&1) || code=$?
if [ $code != 0 ]; then
    echo "umount failed:  ${response}"
fi

code=0 && response=$(sudo rm -fr /home/$user/downloads 2>&1) || code=$?
if [ $code != 0 ]; then
    echo "rm failed:  ${response}"
fi

code=0 && response=$(sudo chown -R $user:"sftpusers" /home/$user 2>&1) || code=$?
if [ $code != 0 ]; then
    echo "chown failed:  ${response}"
fi

