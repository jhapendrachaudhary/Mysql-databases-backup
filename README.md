<h1> Mysql-databases Phyical backup using percona xtrabackup automation script (Full + Incremeantal backup) </h1>

Process:
1. Install rclone to upload on google drive
2. Take backup using Percona XtraBackup (Physical backup)
3. Zip + compress backup (zstd)
4. Encrypt file using gpg (password)
5. Upload to google drive (manual or using script, schedule using crontab)
// Note: - Runs as a specific user that has permission to MySQL server (e.g.: -root)
1. Here’s a step-by-step guide to install and configure
rclone, especially tailored for someone working with file
automation and cloud backups (like Google Drive):
Step 1: Install rclone
On Linux (Ubuntu/Debian-based):
Open a terminal and run:
$ sudo apt update
$ sudo apt install rclone –y
Step 2: Create a new remote (e.g., Google Drive)
$ sudo rclone config
1.
2.
3.
4.
Type n for new remote and press Enter.
Give it a name (e.g., mygdrive) — remember this name!
Scroll (give a number or type drive) to select Google Drive as the storage type.
Leave client_id and client_secret blank unless you have your own OAuth credentials (not
needed for personal use).
5. For scope, choose full (or just press Enter to accept default).
6. Leave root_folder_id blank unless you want to restrict to a specific folder.
7. Say No to "Use auto config?" if you're on a server without a browser.
➜ If Yes (on a desktop), a browser will open for login.➜ If No (headless/server), rclone will give you a link to open on another device to get a
verification code.
8. Log in to your Google account and allow access.
9. Paste the verification code back into the terminal.
10. Confirm that the config looks good and say Yes to save.
You’ll now see your remote listed.
Type q to quit the config tool.
Step 3: Test it
List files in your Google Drive:
$ rclone lsd mygdrive:
Replace mygdrive with the name you chose.
To copy a local folder to Google Drive:
$ rclone copy /path/to/local/folder mygdrive:backup-folder
=========Extra commands==========
Show remote list
$ rclone listremotes –long
$ rclone lsd remote:
$ rclone ls remote:
$ rclone lsl remote:
Copy & Sync files
$ rclone copy /local/path remote:backup-folder
$ rclone sync /local/path remote:backup-folder
Check size and stats
$ rclone size remote:backup-folder
$ rclone copy -P /data mygdrive:backup
Move & Delete$ rclone move /local/archive remote:archive
$ rclone purge remote:old-backup
$ rclone delete remote:temp-files
Mount a remote as a local drive
$ rclone mount mygdrive: ~/gdrive-mount --vfs-cache-mode full
Config
$ rclone config file
$ rclone config show
2. What is Percona XtraBackup?
Percona XtraBackup is an open-source, hot backup tool for MySQL, Percona Server, and
(with limitations) MariaDB
XtraBackup lets you back up MySQL without locking tables (hot backup), supports full +
incremental backups, and integrates well with GPG encryption and rclone for cloud sync.
"Hot backup" = No downtime. Your app keeps working during backup.
Here’s a complete step-by-step guide to using Percona XtraBackup
for MySQL (or MariaDB) hot backups — ideal for your work with
incremental backups, automation, and secure cloud storage.
Prerequisites
1.
2.
3.
4.
5.
MySQL or MariaDB installed and running.
Root or backup-user access to MySQL.
Percona XtraBackup installed (see Step 1).
You’re on Linux (most common for servers).
(Optional) A dedicated backup user (recommended for security).Step 1: Install Percona XtraBackup
On Ubuntu/Debian:
# Add Percona repository
$ wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb
$ sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb
# Enable Enable the repository
$ sudo percona-release setup ps80 # or 'pxb-80' for XtraBackup only
# Install XtraBackup
$ sudo apt update
$ sudo apt update sudo apt install percona-xtrabackup-80
Verify Install:
$ xtrabackup –version
Note:
For MySQL 5.7 or older, use percona-xtrabackup-24.
Step 2: Create a MySQL Backup User
Log into MySQL as root:
$ CREATE USER 'bkpuser'@'localhost' IDENTIFIED BY 'strong_password';
$ GRANT LOCK TABLES, PROCESS, RELOAD, REPLICATION CLIENT, SHOW
DATABASES, SUPER, SELECT ON . TO 'bkpuser'@'localhost';
$ FLUSH PRIVILEGES;
# Save these credentials securely — you’ll use them in backup commands or config files.
Note: Step 3 and step 4 doing manually backup, if you want to do automatically
go to number 6.
Step 3: Perform a Full BackupChoose a backup directory (e.g., /backups/mysql/full).
$ sudo mkdir -p /backups/mysql/full
xtrabackup \
--user=bkpuser \
--password=strong_password \
--backup \
--target-dir=/backups/mysql/full
---------completed OK!------------
Step 4: Prepare the Full Backup (Apply logs)
This makes the backup consistent and restorable:
$ xtrabackup \
--prepare \
--target-dir=/backups/mysql/full
Run --prepare only once on a full backup (unless adding incrementals — see below).
Now your full backup is ready to restore or use as a base for incrementals.
Step 5: Perform an Incremental Backup
After your full backup, changes happen. To back up only new changes:
$ sudo mkdir - p /backups/mysql/inc1
$ xtrabackup \
--user=bkpuser \
--password=strong_password \
--backup \
--target-dir=/backups/mysql/inc1 \
--incremental-basedir=/backups/mysql/full
You can create more incrementals:
-
-
inc2 uses --incremental-basedir=/backups/mysql/inc1
But for restore, you’ll apply them in order on top of the full backup.3. Zip + Compress
zstd (short for Zstandard) is a fast, modern compression algorithm developed by Facebook
(Meta). it has compression level 1-19
On Ubuntu/Debian:
$ sudo apt update
$ sudo apt install zstd
Check:
$ zstd –version
Compress only files not folder
$ zstd myfile.txt
How to compress folder?
-
decompress the folder
$ tar -I zstd -xf inc_20251226_2054.tar.zst
-
compress the folder
$ tar -I zstd -cf inc_20251226_2054.tar.zst inc_20251226_2054
For more details :- https://github.com/facebook/zstd
4. What is GPG?
GPG (GNU Privacy Guard) is a free, open-source tool for:
-
-
Encryption (keep data secret)
Signing (verify who sent it)-
Decryption & verification
Install GPG
Ubuntu/debian
$ sudo apt install gnupg
// Encrypt with pasword
$ gpg --batch --yes \
--passphrase-file /secure/gpg.pass \
--symmetric \
--cipher-algo AES256 \
--output backup.tar.zst.gpg \
backup.tar.zst
Decrypt with password
$ gpg --batch --yes \
--passphrase-file /secure/gpg.pass \
--output backup.tar.zst \
--decrypt backup.tar.zst.gpg
Note: Instead of /secure/gpg.pass use your path of password file
$ echo "your_gpg_pass" | sudo tee /secure/gpg.pass
$ sudo chmod 600 /secure/gpg.pass
5. Upload To Google Drive
$ rclone copy /backups/backup-2025-12-28.tar.zst.gpg gdrive:Backup/MySQL/
or
Upload with progress & logging:
$ rclone copy -P --log-file=/var/log/rclone-upload.log \/backups/backup-2025-12-28.tar.zst.gpg \
gdrive:Backup/MySQL/
Verify:
$ rclone ls gdrive:Backup/MySQL/6. Automatically
Step-1: Follow every step before Percona XtraBackup (Step-2)
Step-2: Download mysql-backup.sh file: -
https://github.com/jhapendrachaudhary/Mysql-databases-backup
Step-3: Go to folder where you downloaded mysql-backup.sh
Step-4 : Run this command on terminal
$ Chmod +x mysql-backup.sh
$ Chown root:root mysql-backup.sh
Step-5: Add Schedule using cronjobs
$ sudo crontab –e
- goto end and add this line: -
0 23 * * * /usr/local/bin/backup-mysql.sh >> /var/log/mysql-backup.log 2>&1
- Save it: - according to your editor (vim or nano)
-it will run daily 11:00 pm
Now, Done Check to your Google drive........................................................................

-----------------------remove database-----------------
sudo pkill -9 mysqld
sudo systemctl reset-failed mysql

sudo rm -rf /var/lib/mysql/*

sudo mkdir -p /var/log/mysql
sudo chown mysql:mysql /var/log/mysql

sudo mysqld --initialize --user=mysql --datadir=/var/lib/mysql

sudo cat /var/log/mysql/error.log | grep 'temporary password'

sudo systemctl start mysql


---------------------------restore databse---------------------
gpg --batch --yes \
--passphrase-file /root/.mysql_backup_pass \
--output full_20260105_1616.tar.zst \
--decrypt full_20260105_1616.tar.zst.gpg

tar -I zstd -xf full_20260105_1616.tar.zst

xtrabackup --prepare --target-dir=/home/ErpDemo/database_backups/full/full_20260105_1616_raw

sudo xtrabackup \
  --copy-back \
  --target-dir=/home/ErpDemo/database_backups/full/full_20260105_1616_raw \
  --datadir=/var/lib/mysql
  
#  You can also add --user=mysql to avoid permission issues:
 sudo xtrabackup --copy-back \
  --target-dir=/home/ErpDemo/database_backups/full/full_20260105_1616_raw \
  --datadir=/var/lib/mysql \
  --user=mysql
  
  sudo chown -R mysql:mysql /var/lib/mysql
sudo chmod -R 750 /var/lib/mysql

# error check
sudo journalctl -u mysql --no-pager -n 50 



Reference link: -
https://trilio.io/resources/backup-mysql-database/
https://n2ws.com/blog/mysql-backup-methods
https://docs.percona.com/percona-
xtrabackup/2.4/installation/apt_repo.html



