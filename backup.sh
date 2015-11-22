#!/bin/bash

set -e
set -o pipefail

DRIVE_FOLDER_MIME="application/vnd.google-apps.folder"
DRIVE_BACKUP_FOLDER="backups"
BACKUP_FOLDER="/media/data/backups"
PUBKEY="/usr/local/etc/key.pub"
EXCLUDE="/usr/local/etc/backup.exclude"

TARGET="$BACKUP_FOLDER/pi-$(date +"%d-%m-%Y").tar.gz"
OLD_BACKUPS=$(find $BACKUP_FOLDER -mtime +9)

function create_secure_backup {
    umask 077

    local target=$1
    local old_backups=$2    
    local password="$BACKUP_FOLDER/password"

    # Generate archive password (180 bytes + bytes of padding < 256 bytes RSA key)
    openssl rand -base64 180 > "$password"

    echo "Creating encrypted archive... $(date +%H:%M:%S)"

    # Backup, gzip and encrypt the filesystem
    tar -cpf - --directory=/ -X $EXCLUDE . | pigz -p 3 | openssl enc -aes-256-cbc -a -salt -out "$target" -pass file:"$password"

    # Encrypt archive password with public key
    openssl rsautl -encrypt -pubin -inkey $PUBKEY -in "$password" -out "$target.key"

    # Delete archive password 
    rm "$password"

    # Make the files world readable
    chmod 644 "$target" "$target.key"

    echo "Deleting old local backups... $(date +%H:%M:%S)"

    for file in $old_backups 
    do
        rm "$file"
    done
}

function google_drive_backup {
    local target=$1
    local old_backups=$2
    local backup_folder_id=$(drive list -q "mimeType = '$DRIVE_FOLDER_MIME' and 'root' in parents and title = '$DRIVE_BACKUP_FOLDER'" | sed -n 2p | cut -d" " -f1)
    
    if [ -z "$backup_folder_id" ]; then
        echo "WARNING: can't find folder '$DRIVE_BACKUP_FOLDER' on google drive. Remote backup is not possible."
        return
    fi

    for file in $old_backups
    do
        echo "Deleting old remote backups... $(date +%H:%M:%S)"
        
        local basename=$(basename "$file")   
        local googleid=$(drive list -q "mimeType != '$DRIVE_FOLDER_MIME' and '$backup_folder_id' in parents and title = '$basename'" | sed -n 2p | cut -d" " -f1)

        if [ -n "$googleid" ]; then
            drive delete -i "$googleid"
        fi
    done
    
    echo "Uploading new backup and key... $(date +%H:%M:%S)"

    drive upload -f "$target.key" -p "$backup_folder_id"
    drive upload -f "$target" -p "$backup_folder_id"
}

create_secure_backup "$TARGET" "$OLD_BACKUPS"
google_drive_backup "$TARGET" "$OLD_BACKUPS"

echo "Done $(date +%H:%M:%S)"

