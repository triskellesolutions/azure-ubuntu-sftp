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

# make backup
sudo cp -f /etc/fstab /etc/fstab".`printf '%(%Y%m%d_%H%M%S)T\n'`"
# temp file
temp_file="/etc/fstab.temp.`printf '%(%Y%m%d_%H%M%S)T\n'`"
sudo touch $temp_file
sudo chmod 777 $temp_file
sudo echo "" > $temp_file
while read line; do
    if ! grep -qs "/home/$user/" <<< "${line}"; then
        sudo echo "$line" >> $temp_file
    fi
done < /etc/fstab

sudo mv $temp_file /etc/fstab
sudo chmod 644 /etc/fstab
sudo chown root:root /etc/fstab
