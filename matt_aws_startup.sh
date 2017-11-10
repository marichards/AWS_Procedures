# Mount ephermeral drive
sudo -s
sudo mkfs.ext4 /dev/xvdba
sudo mkdir -m 000 /scratch 
echo "/dev/xvdba /scratch auto noatime 0 0" | sudo tee -a /etc/fstab
sudo mount /scratch

# Install everything
echo "deb http://ftp.osuosl.org/pub/cran/bin/linux/ubuntu xenial/" >> /etc/apt/sources.list
apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9
apt-get update && apt-get -y upgrade && apt-get -y install r-base postgresql postgresql-contrib awscli libcurl4-openssl-dev libxml2-dev libpq-dev libmariadb-client-lgpl-dev && apt-get -qq install git

# Make data directory and # Get Github Repo(s)
mkdir -p /scratch/data
mkdir -p /scratch/github
cd /scratch/github/
git clone https://github.com/PriceLab/BDDS.git

# Change PostgreSQL storage
sudo /etc/init.d/postgresql stop
mkdir -p /scratch/post
rsync -av /var/lib/postgresql/ /scratch/post/
sed -ie 's/var\/lib\/postgresql/scratch\/post/g' /etc/postgresql/9.5/main/postgresql.conf
sed -ie 's/128MB/256MB/g' /etc/postgresql/9.5/main/postgresql.conf
sed -ie 's/max_connections\ =\ 100/max_connections\ =\ 300/g' /etc/postgresql/9.5/main/postgresql.conf
sudo /etc/init.d/postgresql start

# Make PostgreSQL user roles
mkdir -p /scratch/db
sudo -u postgres psql postgres << EOF
CREATE ROLE root WITH SUPERUSER CREATEDB CREATEROLE LOGIN ENCRYPTED PASSWORD 'trena';
CREATE ROLE trena WITH SUPERUSER CREATEDB CREATEROLE LOGIN ENCRYPTED PASSWORD 'trena';
EOF

# Copy chromsomes and files for FIMO (only if creating new FIMO)
cd /scratch/data/
mkdir meme
mkdir completed
mkdir chromosomes
cd /scratch/data/chromosomes
aws s3 cp s3://marichards/GRCh38 . --recursive

# Copy the footprints
cd /scratch/data/
mkdir footprints
cd footprints
aws s3 cp s3://marichards/footprints . --recursive

# Get Emacs and ESS
apt install emacs

cd /scratch/github
git clone https://github.com/emacs-ess/ESS.git

cd ~
emacs .emacs

### Add this to .emacs:
(package-initialize)

(add-to-list 'load-path "/scratch/github/ESS/lisp/")
(load "ess-site")

(add-hook 'ess-mode-hook
          '(lambda()
             (setq ess-indent-with-fancy-comments nil)
                          ))

###

# Copy FIMO database
sudo -u postgres psql postgres << EOF
create database fimo;
grant all privileges on database fimo to trena;
EOF
cd /scratch/db
aws s3 cp s3://marichards/correct_index_dbs/2017_07_27_fimo .
sudo pg_restore --verbose --clean --no-acl --no-owner --dbname=fimo 2017_07_27_fimo

# Install some R packages (from within R)
source("https://bioconductor.org/biocLite.R")
biocLite(c("RPostgreSQL","dplyr","glmnet","randomForest","vbsr","lassopv","flare","RSQLite","RMySQL","RUnit", "BiocParallel", "doParallel", "GenomicRanges", "rtracklayer"))
