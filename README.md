# star-backup
star-backup is a shell script that creates a secure backup archive of a system using tar and openssl. 

## Requirements
* tar
* pigz (multithreaded version of gzip)
* openssl 
* A pair of public/private RSA keys

## How it works

The script starts by generating a random password that will be used to encrypt the system backup (using the aes-256-cbc cipher). This password is then encrypted using the user's public key (provided in /usr/local/etc/key.pub). In the end 2 files are generated : 

1. The archive password encrypted with RSA
2. The tar.gz backup archive encrypted with AES

The archive password can only be decrypted with the private key associated with the user's public key

## How can I access the archive?

Simply run these 2 commands :

1. `openssl rsautl -decrypt -inkey <path to private key> -in <path to encrypted password> -out password.dec`
2. `openssl enc -d -a -aes-256-cbc -in <path to encrypted backup> -out archive.tar.gz -pass file:<path to decrypted password>`

## Google drive backup

By default this script also uploads a backup of the 2 files to google drive (using the [gdrive client](https://github.com/prasmussen/gdrive))
