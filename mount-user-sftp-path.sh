#!/bin/bash
set -Eeo pipefail

# shellcheck disable=2154
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

. /vmsetup/install.keys

SFTPUSER=$1
STORAGE_ACCOUNT_NAME="${storageAccountName}"
FILE_SHARE_NAME="${storageAccountFileShareName}"

if [[ -z ${STORAGE_ACCOUNT_NAME} || -z ${SFTPUSER} || -z ${FILE_SHARE_NAME} ]]; then
    exit 1
fi

mkdir -p "/home/$SFTPUSER"
chown root:root "/home/$SFTPUSER"
chmod 755 "/home/$SFTPUSER"

sudo usermod -g sftpusers -s /bin/bash $SFTPUSER

LOCAL_UID=$(id -u ${SFTPUSER})
LOCAL_GID=$(id -g ${SFTPUSER})
FILE_SHARE_NAME_PATH="${storageAccountSmbPathFileShare}"
CRED_FOLDER=/etc/smbcredentials
CRED_FILE=${CRED_FOLDER}/${STORAGE_ACCOUNT_NAME}.cred
ROOT_MOUNT_OPTIONS="vers=3.0,credentials=${CRED_FILE},serverino"

# Make the user's "local" directory

sudo mkdir -p /mount/${STORAGE_ACCOUNT_NAME}/

if grep -qs "/mount/${STORAGE_ACCOUNT_NAME} " /proc/mounts; then
   echo "Attempt unmount of: /mount/${STORAGE_ACCOUNT_NAME} "
   sudo umount -a -t cifs -l /mount/${STORAGE_ACCOUNT_NAME}
fi
sudo mount -t cifs ${FILE_SHARE_NAME_PATH} /mount/${STORAGE_ACCOUNT_NAME} -o ${ROOT_MOUNT_OPTIONS}
sudo mkdir -p /mount/${STORAGE_ACCOUNT_NAME}/${SFTPUSER}/downloads
sudo mkdir -p /mount/${STORAGE_ACCOUNT_NAME}/${SFTPUSER}/uploads
sudo umount /mount/${STORAGE_ACCOUNT_NAME}

# Mount the folders
USER_MOUNT_OPTIONS="vers=3.0,credentials=${CRED_FILE},uid=${LOCAL_UID},gid=${LOCAL_GID},serverino"
if grep -qs "${FILE_SHARE_NAME_PATH}/${SFTPUSER}/uploads " /proc/mounts; then
    echo "Attempt unmount of: ${FILE_SHARE_NAME_PATH}/${SFTPUSER}/uploads"
    sudo umount -a -t cifs -l ${FILE_SHARE_NAME_PATH}/${SFTPUSER}/uploads
    [ -d /home/${SFTPUSER}/uploads ] && rm -fr /home/${SFTPUSER}/uploads && sudo mkdir /home/${SFTPUSER}/uploads
fi

code=0 && response=$(sudo mkdir /home/${SFTPUSER}/uploads 2>&1) || code=$?
if [ $code != 0 ]; then
    echo "mkdir failed:  ${response}"
fi
sudo mount -t cifs ${FILE_SHARE_NAME_PATH}/${SFTPUSER}/uploads /home/${SFTPUSER}/uploads -o ${USER_MOUNT_OPTIONS}

if grep -qs "${FILE_SHARE_NAME_PATH}/${SFTPUSER}/downloads " /proc/mounts; then
    echo "Unmount: ${FILE_SHARE_NAME_PATH}/${SFTPUSER}/downloads"
    sudo umount -a -t cifs -l ${FILE_SHARE_NAME_PATH}/${SFTPUSER}/downloads
    [ -d /home/${SFTPUSER}/downloads ] && rm -fr /home/${SFTPUSER}/downloads && sudo mkdir /home/${SFTPUSER}/downloads
fi
code=0 && response=$(sudo mkdir /home/${SFTPUSER}/downloads 2>&1) || code=$?
if [ $code != 0 ]; then
    echo "mkdir failed:  ${response}"
fi
sudo mount -t cifs ${FILE_SHARE_NAME_PATH}/${SFTPUSER}/downloads /home/${SFTPUSER}/downloads -o ${USER_MOUNT_OPTIONS}

# Add entries to /etc/fstab so that it will survive a reboot
if ! grep -qs "${FILE_SHARE_NAME_PATH}/${SFTPUSER}/uploads " /etc/fstab; then
    echo "Adding entry to sftab for uploads"
    sudo bash -c "echo \"${FILE_SHARE_NAME_PATH}/${SFTPUSER}/uploads /home/${SFTPUSER}/uploads cifs nofail,${USER_MOUNT_OPTIONS}\" >> /etc/fstab"
else
    echo "Skip fstab for uploads"
fi
if ! grep -qs "${FILE_SHARE_NAME_PATH}/${SFTPUSER}/downloads " /etc/fstab; then
    echo "Adding entry to sftab for downloads"
    sudo bash -c "echo \"${FILE_SHARE_NAME_PATH}/${SFTPUSER}/downloads /home/${SFTPUSER}/downloads cifs nofail,${USER_MOUNT_OPTIONS}\" >> /etc/fstab"
else
    echo "Skip fstab for downloads"
fi
