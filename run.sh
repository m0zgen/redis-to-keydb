#!/bin/bash
# Author: Yevgeniy Goncharov aka xck, http://sys-adm.in
# Bash script for migration to KeyDB from Redis

# Sys env / paths / etc
# -------------------------------------------------------------------------------------------\
PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
cd $SCRIPT_PATH

# Vars
# ---------------------------------------------------\
_REDIS="redis"
_KEYDB="keydb"

# Output messages
# ---------------------------------------------------\

# And colors
RED='\033[0;91m'
GREEN='\033[0;92m'
CYAN='\033[0;96m'
YELLOW='\033[0;93m'
PURPLE='\033[0;95m'
BLUE='\033[0;94m'
BOLD='\033[1m'
WHiTE="\e[1;37m"
NC='\033[0m'

ON_SUCCESS="DONE"
ON_FAIL="FAIL"
ON_ERROR="Oops"
ON_CHECK="✓"

Info() {
  echo -en "[${1}] ${GREEN}${2}${NC}\n"
}

Warn() {
  echo -en "[${1}] ${PURPLE}${2}${NC}\n"
}

Success() {
  echo -en "[${1}] ${GREEN}${2}${NC}\n"
}

Error () {
  echo -en "[${1}] ${RED}${2}${NC}\n"
}

Splash() {
  echo -en "${WHiTE} ${1}${NC}\n"
}

space() { 
  echo -e ""
}

# Functions
# ---------------------------------------------------\

# Check is current user is root
isRoot() {
  if [ $(id -u) -ne 0 ]; then
    Error $ON_ERROR "You must be root user to continue"
    exit 1
  fi
  RID=$(id -u root 2>/dev/null)
  if [ $? -ne 0 ]; then
    Error "User root no found. You should create it to continue"
    exit 1
  fi
  if [ $RID -ne 0 ]; then
    Error "User root UID not equals 0. User root must have UID 0"
    exit 1
  fi
}

# Checks supporting distros
checkDistro() {
  # Checking distro
  if [ -e /etc/centos-release ]; then
      DISTRO=`cat /etc/redhat-release | awk '{print $1,$4}'`
      RPM=1
  elif [ -e /etc/fedora-release ]; then
      DISTRO=`cat /etc/fedora-release | awk '{print ($1,$3~/^[0-9]/?$3:$4)}'`
      RPM=2
  elif [ -e /etc/os-release ]; then
    DISTRO=`lsb_release -d | awk -F"\t" '{print $2}'`
    RPM=0
    DEB=1
  else
      Error "Your distribution is not supported (yet)"
      exit 1
  fi
}

# Checking active status from systemd unit
service_exists() {
    local n=$1
    if [[ $(systemctl list-units --all -t service --full --no-legend "$n.service" | sed 's/^\s*//g' | cut -f1 -d' ') == $n.service ]]; then
        return 0
    else
        return 1
    fi
}

paths_fixing() {

    # sed -i '/^pidfile/s//# &/' $1
    # sed -i '/^logfile/s//# &/' $1
    # sed -i '/^dir \/var\/lib/s//# &/' $1
    sed -i '/^bind/s//# &/' $1
    sed -i 's/redis/keydb/g' $1
}

update_configs() {

    # echo "dir /var/lib/keydb" >> keydb.conf
    # echo "logfile /var/log/keydb/keydb-server.log" >> keydb.conf
    # echo "pidfile /var/run/keydb/keydb-server.pid" >> keydb.conf
    echo "bind 0.0.0.0 ::" >> $1

}

migrate() {

    echo "bgsave" | redis-cli
    echo "shutdown" | redis-cli

    cd /etc/keydb; mv keydb.conf keydb.conf_bak;
    cp /etc/redis/redis.conf keydb.conf; chown keydb:keydb keydb.conf

    if [[ -d /etc/redis/modules ]]; then
        cp -r /etc/redis/modules .
        chown -R keydb:keydb modules
    fi

    paths_fixing "keydb.conf"
    paths_fixing "modules/*.conf"
    update_configs "keydb.conf"

    Info "$ON_CHECK" "Stop Redis and trying to start KeyDB..."
    systemctl disable --now $_REDIS-server
    systemctl restart $_KEYDB-server

    Info "$ON_CHECK" "Done!"

}


checking() {

    if [[ ! -d "/etc/redis" ]]; then
        Info "$ON_FAIL" "Redis service already does not found. Exit..."
        exit 1
    fi

    if service_exists "$_REDIS-server"; then
        Info "$ON_CHECK" "Redis service already installed. Checking KeyDB..."

        if service_exists "$_KEYDB-server"; then

            migrate

        else

            Info "$ON_ERROR" "KeyDB is not installed. Trying to install KeyDB..."

            echo -e "[${GREEN}✓${NC}] Install Debian packages"
            echo "deb https://download.keydb.dev/open-source-dist $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/keydb.list
            sudo wget -O /etc/apt/trusted.gpg.d/keydb.gpg https://download.keydb.dev/open-source-dist/keyring.gpg
            sudo apt update

            systemctl stop $_REDIS-server
            sudo apt install keydb-server keydb-tools -y
            
            # Additional step
            systemctl stop $_KEYDB-server; systemctl start $_REDIS-server

            sleep 5

            Info "$ON_CHECK" "Starting migration..."
            migrate

        fi

        
        


    else
        Info "$ON_FAIL" "Redis service does not running. Please start Redis for migration. Exit..."
        exit 1
    fi

}

# 

init() {

    if [[ "$DEB" -eq "1" ]]; then
        Info "$ON_CHECK" "Run Debian installer..."
        checking
    else
        Info "$ON_CHECK" "Not supported distro. Exit..."
        exit 1
    fi

}

# Actions
# ---------------------------------------------------\

isRoot
checkDistro

init