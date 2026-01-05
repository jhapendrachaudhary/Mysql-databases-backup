# MySQL Physical Backup Automation (Full + Incremental)

This repository documents a **production-ready automation approach** for taking **physical MySQL backups** using **Percona XtraBackup**, with **compression, encryption, and off-site storage on Google Drive**.

The solution is designed for Linux servers and is suitable for **large databases**, **zero-downtime (hot) backups**, and **scheduled automation via cron**.

---

## Architecture Overview

**Backup Flow**

1. Take **Full / Incremental physical backup** using Percona XtraBackup
2. Compress backup using **Zstandard (zstd)**
3. Encrypt archive using **GPG (AES-256)**
4. Upload encrypted backup to **Google Drive** using **rclone**
5. Schedule via **cron**

Runs as a privileged user (typically `root`) or a dedicated MySQL backup user with required permissions.

---

## 1. Install and Configure rclone (Google Drive)

### 1.1 Install rclone (Ubuntu/Debian)

```bash
sudo apt update
sudo apt install -y rclone
```

### 1.2 Configure Google Drive Remote

```bash
sudo rclone config
```

Steps:

1. Select `n` (new remote)
2. Name the remote (example: `mygdrive`)
3. Choose **Google Drive** as storage
4. Leave `client_id` and `client_secret` empty
5. Select default scope (full access)
6. Leave `root_folder_id` empty (optional)
7. For servers: choose **No** for auto-config
8. Open the provided URL on another device
9. Paste the verification code
10. Save configuration and exit

### 1.3 Test rclone

```bash
rclone lsd mygdrive:
rclone copy /path/to/local/folder mygdrive:Backup/Test
```

### Common rclone Commands

```bash
rclone listremotes
rclone ls mygdrive:
rclone size mygdrive:Backup
rclone copy -P /data mygdrive:Backup
rclone sync /data mygdrive:Backup
rclone delete mygdrive:old-backups
```

---

## 2. Percona XtraBackup

### 2.1 What is Percona XtraBackup?

Percona XtraBackup is an **open-source hot backup utility** for:

* MySQL
* Percona Server
* MariaDB (limited support)

**Key Benefits**

* No downtime (hot backups)
* Supports **full and incremental** backups
* Ideal for large production databases

---

## 3. Install Percona XtraBackup

### Ubuntu / Debian

```bash
wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb
sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb
sudo percona-release setup pxb-80
sudo apt update
sudo apt install -y percona-xtrabackup-80
```

Verify installation:

```bash
xtrabackup --version
```

> For MySQL 5.7 or older, use `percona-xtrabackup-24`

---

## 4. Create MySQL Backup User (Recommended)

```sql
CREATE USER 'bkpuser'@'localhost' IDENTIFIED BY 'strong_password';
GRANT LOCK TABLES, PROCESS, RELOAD, REPLICATION CLIENT, SHOW DATABASES, SUPER, SELECT ON *.* TO 'bkpuser'@'localhost';
FLUSH PRIVILEGES;
```

Store credentials securely.

---

## 5. Manual Backup Operations

### 5.1 Full Backup

```bash
mkdir -p /backups/mysql/full
xtrabackup \
  --user=bkpuser \
  --password=strong_password \
  --backup \
  --target-dir=/backups/mysql/full
```

### 5.2 Prepare Full Backup

```bash
xtrabackup --prepare --target-dir=/backups/mysql/full
```

---

### 5.3 Incremental Backup

```bash
mkdir -p /backups/mysql/inc1
xtrabackup \
  --user=bkpuser \
  --password=strong_password \
  --backup \
  --target-dir=/backups/mysql/inc1 \
  --incremental-basedir=/backups/mysql/full
```

Subsequent incrementals must reference the previous incremental directory.

---

## 6. Compression with Zstandard (zstd)

### Install zstd

```bash
sudo apt install -y zstd
```

### Compress Directory

```bash
tar -I zstd -cf backup_YYYYMMDD.tar.zst /backups/mysql/full
```

### Decompress

```bash
tar -I zstd -xf backup_YYYYMMDD.tar.zst
```

---

## 7. Encryption with GPG

### Install GPG

```bash
sudo apt install -y gnupg
```

### Create Password File

```bash
echo "your_strong_password" | sudo tee /secure/gpg.pass
sudo chmod 600 /secure/gpg.pass
```

### Encrypt Backup

```bash
gpg --batch --yes \
  --passphrase-file /secure/gpg.pass \
  --symmetric \
  --cipher-algo AES256 \
  --output backup.tar.zst.gpg \
  backup.tar.zst
```

### Decrypt Backup

```bash
gpg --batch --yes \
  --passphrase-file /secure/gpg.pass \
  --output backup.tar.zst \
  --decrypt backup.tar.zst.gpg
```

---

## 8. Upload Backup to Google Drive

```bash
rclone copy -P backup.tar.zst.gpg mygdrive:Backup/MySQL/
```

Verify:

```bash
rclone ls mygdrive:Backup/MySQL/
```

---

## 9. Automation (Cron)

### Download Script

```bash
git clone https://github.com/jhapendrachaudhary/Mysql-databases-backup
chmod +x mysql-backup.sh
chown root:root mysql-backup.sh
```

### Schedule Backup

```bash
sudo crontab -e
```

Add:

```bash
0 23 * * * /usr/local/bin/backup-mysql.sh >> /var/log/mysql-backup.log 2>&1
```

Runs daily at **11:00 PM**.

---

## 10. Database Restore Procedure

### 10.1 Remove Existing Database (Clean Rebuild)

```bash
sudo systemctl stop mysql
sudo rm -rf /var/lib/mysql/*
sudo mysqld --initialize --user=mysql --datadir=/var/lib/mysql
sudo systemctl start mysql
```

---

### 10.2 Restore from Backup

```bash
gpg --batch --yes \
  --passphrase-file /secure/gpg.pass \
  --output full_backup.tar.zst \
  --decrypt full_backup.tar.zst.gpg

tar -I zstd -xf full_backup.tar.zst

xtrabackup --prepare --target-dir=/path/to/full_backup

xtrabackup --copy-back \
  --target-dir=/path/to/full_backup \
  --datadir=/var/lib/mysql \
  --user=mysql

chown -R mysql:mysql /var/lib/mysql
chmod -R 750 /var/lib/mysql
```

Check errors:

```bash
journalctl -u mysql --no-pager -n 50
```

---

## References

* [https://docs.percona.com/percona-xtrabackup/](https://docs.percona.com/percona-xtrabackup/)
* [https://trilio.io/resources/backup-mysql-database/](https://trilio.io/resources/backup-mysql-database/)
* [https://n2ws.com/blog/mysql-backup-methods](https://n2ws.com/blog/mysql-backup-methods)

---

**Author:** Jhapendra Chaudhary
