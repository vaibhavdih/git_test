#!/usr/bin/env bash
set -euo pipefail
################################################################################
# Frappe dev stack bootstrap for Codex / Codespaces (Ubuntu 24.04)
# - MariaDB 10.6, Redis 7, Node 18 + Yarn 1, cron, Bench CLI
# - creates non-root user "frappe" and initial site "test_site"
################################################################################

# ──────────────────────────────────────────────────────────────────────────────
# 0. Basic variables – tweak if you like
MYSQL_ROOT_PW="root"
NEW_USER="frappe"
BENCH_PATH="/home/${NEW_USER}/frappe-bench"
SITE_NAME="test_site"
ADMIN_PW="admin"
################################################################################

echo ">>> [0] Updating apt index"
apt-get update -y

echo ">>>    Installing deadsnakes PPA and Python 3.10"
apt-get install -y software-properties-common
add-apt-repository -y ppa:deadsnakes/ppa
apt-get update -y
apt-get install -y python3.10 python3.10-venv python3.10-dev

# ──────────────────────────────────────────────────────────────────────────────
echo ">>> [1] MariaDB 10.6 repo + server"
apt-get install -y software-properties-common dirmngr curl ca-certificates
curl -Ls https://downloads.mariadb.com/MariaDB/mariadb_repo_setup \
  | bash -s -- --os-type=ubuntu --os-version=jammy --mariadb-server-version=10.6
DEBIAN_FRONTEND=noninteractive \
  apt-get install -y mariadb-server mariadb-client

echo ">>>    Making runtime dir & launching mysqld (no systemd here)"
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
mysqld_safe --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock &

echo ">>>    Waiting for MariaDB socket"
until mysqladmin --socket=/run/mysqld/mysqld.sock ping &>/dev/null; do sleep 1; done

echo ">>>    Securing root account non-interactively"
mysql --socket=/run/mysqld/mysqld.sock -u root <<SQL
ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PW}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user
 WHERE User='root' AND Host NOT IN ('localhost','127.0.0.1','::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
SQL

echo ">>>    Setting utf8mb4 defaults"
cat >/etc/mysql/mariadb.conf.d/60-frappe.cnf <<'EOF'
[mysqld]
innodb-file-format=barracuda
innodb-file-per-table=1
innodb-large-prefix=1
character-set-server=utf8mb4
collation-server=utf8mb4_unicode_ci
[mysql]
default-character-set=utf8mb4
EOF
# restart inside same PID namespace
mysqladmin --socket=/run/mysqld/mysqld.sock -u root -p"${MYSQL_ROOT_PW}" shutdown
mysqld_safe --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock &

# ──────────────────────────────────────────────────────────────────────────────
echo ">>> [2] System packages: Node 18, Yarn 1, Redis 7, cron, build utils"
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs redis-server cron \
                   python3-venv pipx build-essential libmysqlclient-dev
npm install -g yarn@1

# ──────────────────────────────────────────────────────────────────────────────
echo ">>> [3] Non-root user '${NEW_USER}'"
id -u "${NEW_USER}" &>/dev/null || useradd -m -s /bin/bash "${NEW_USER}"
chown -R "${NEW_USER}:${NEW_USER}" /workspace || true
echo "${NEW_USER} ALL=(ALL) NOPASSWD:ALL" >/etc/sudoers.d/${NEW_USER}

cp ~/.git-credentials /home/frappe/.git-credentials
# ──────────────────────────────────────────────────────────────────────────────
echo ">>> [4] Become '${NEW_USER}' and finish Bench-level tasks"
sudo -iu "${NEW_USER}" bash <<'EOSU'
set -euo pipefail
MYSQL_ROOT_PW="root"
BENCH_PATH="$HOME/frappe-bench"
SITE_NAME="test_site"
ADMIN_PW="admin"

echo "---- 4.1 pipx + Bench CLI"
pipx ensurepath
export PATH="$HOME/.local/bin:$PATH"
command -v bench >/dev/null 2>&1 || pipx install frappe-bench

echo "---- 4.2 Node & Yarn sanity"
node -v
yarn -v

sudo chown frappe:frappe /home/frappe/.git-credentials
sudo chmod 600      /home/frappe/.git-credentials
git config --global credential.helper "store --file=/home/frappe/.git-credentials"

echo "---- 4.3 Initialise bench (dev settings)"

#bench init "$BENCH_PATH" \
#   --python "$(which python3)" \
#   --skip-assets \
#   --skip-redis-config-generation

bench init "$BENCH_PATH" --python /usr/bin/python3.10 --frappe-branch=main --frappe-path=https://github.com/Traqo/frappe --skip-assets --skip-redis-config-generation
   
cd "$BENCH_PATH"

echo "---- 4.4 Add honcho & dev deps missing from venv"
env/bin/pip install honcho responses "rq<2" numpy PyPDF2 freezegun


echo "---- 4.6 Install Python & JS deps, build assets"
bench setup requirements --dev


echo "---- 4.6 Create first site and install frappe"
bench new-site "${SITE_NAME}" \
     --db-root-password "${MYSQL_ROOT_PW}" \
     --admin-password "${ADMIN_PW}"
bench --site "${SITE_NAME}" install-app frappe

bench get-app https://github.com/Traqo/frappe-utils.git



if bench --site test_site install-app frappe_utils; then
 echo "✅ frappe_utils installed successfully"
else
 echo "❌ frappe_utils install failed" >&2
fi

bench get-app https://github.com/Traqo/frappe-trip-execution.git --skip-assets
cd /home/frappe/frappe-bench/apps/execution
git submodule update --init --recursive

bench get-app https://github.com/Traqo/frappe-ptl.git --skip-assets
cd /home/frappe/frappe-bench/apps/ptl
git submodule update --init --recursive

bench build

bench --site test_site install-app ptl

echo "---- 4.7 Done.  Start the stack with:  bench start"


ln -s /workspace/frappe-ptl /home/frappe/frappe-bench/apps/ptl

/home/frappe/frappe-bench/env/bin/python -m pip install -e /home/frappe/frappe-bench/apps/ptl --use-pep517 

cat << 'EOF' | tee /home/frappe/frappe-bench/sites/apps.txt
frappe
frappe_utils
execution
ptl
EOF

bench --site test_site set-config allow_tests true

EOSU
