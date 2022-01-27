#!/bin/bash

# to debug, uncomment next line
#set -x

WEBSITE_TITLE="VMware"
WEBSITE_URL="www.vmware.com"

clear
echo "---"
echo "Preparing demo..."

########################
# include the magic
########################
. demo-magic.sh

echo "Check gcc, make..."

RED='\033[1;31m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

# Install necessary Ubuntu packages
# Check if gcc package is installed
dpkg -s gcc | grep Status >/dev/null
if [ $? -eq 1 ]
then
   sudo apt-get install -y gcc
fi

# Check if meld package is installed
dpkg -s make >/dev/null
if [ $? -eq 1 ]
then
   sudo apt-get install -y make
fi

echo "Check that VMware Carbon Black Cloud Linux agent is running..."
pgrep cbagentd >/dev/null
if [ $? -eq 1 ]
then
   echo -e "Please install ${RED}VMware Carbon Black Cloud Linux agent${NC}"
   exit 1
fi

echo "Check that Apache is installed..."
dpkg -s apache2 >/dev/null 2>&1
if [ $? -eq 1 ]
then
   sudo apt-get install -y apache2
fi

echo "Check that PHP is installed..."
dpkg -s php >/dev/null 2>&1
if [ $? -eq 1 ]
then
   sudo apt-get install -y php
fi

echo ""
echo "---"
echo "Downloading a copy of VMware website... (first page only ;-)"
echo -e "${GREEN}Press ENTER${NC}, and wait 20s..."
wait

# Check if VMware website copy is in /etc/host
grep ${WEBSITE_URL} /etc/hosts >/dev/null
if [ $? -eq 1 ]
then
   sudo sed -i "2i127.0.0.1	${WEBSITE_URL}.copy" /etc/hosts
fi

#Check owner of /var/www/html
if [ -w /var/www/html ]; then
	echo ""
else
	sudo chmod -R 770 /var/www/html
	sudo chown -R www-data:www-data /var/www/html
	sudo adduser ${USER} www-data
	sudo usermod -a -G www-data ${USER}
	newgrp www-data
fi

cd /var/www/html
rm -rf /var/www/html/*

# Don't download fonts... too long
wget --no-parent --convert-links --page-requisites --no-directories \
       --no-host-directories --span-hosts --adjust-extension --no-check-certificate \
       -e robots=off \
       -U 'Mozilla/5.0 (X11; U; Linux i686; en-US; rv:1.8.1.6) Gecko/20070802 SeaMonkey/1.1.4' \
       -R '*.woff, *.woff2.html, *.ttf, *.woff2, *.eot, *.otf' \
       https://${WEBSITE_URL}

wget https://raw.githubusercontent.com/slist/security-demo/master/skullify/attack.php

sudo chown -R www-data:www-data /var/www/html

echo "---"
echo "Check that Apache is running..."
pgrep apache2 >/dev/null
if [ $? -eq 1 ]
then
   sudo service apache2 start
fi

cd ${HOME}
echo "Create a sleepy binary..."

cat <<EOF >sleepy_binary.c
#include <unistd.h> /* sleep  */
#include <stdio.h>  /* printf */

/*
 * Compile with gcc:
 * gcc -o sleepy_binary sleepy_binary.c
 */

int main()
{
	printf("Sleeping for 10 seconds...\n");
	sleep(10);
	printf("Wake up !\n");
	return 0;
}
EOF

# Compile sleepy binary
gcc -o sleepy_binary sleepy_binary.c

clear

echo "---"
echo "Press Enter to start the demo"
wait

# pe  : Print and Execute.
# pei : Print and Execute immediately.
# p   : Print only.
# w   : wait
# cmd : interractive mode

#clear
echo "---"
echo -e "${RED}VMware Carbon Black Cloud linux${NC} can protect many Linux distributions:"
wait
echo " - Ubuntu / Debian"
wait
echo " - RedHat / CentOS"
wait
echo " - Suse / OpenSuse"
wait
echo " - Amazon Linux 2"
wait
echo " - with distributions kernel or custom Linux kernel."

wait

echo ""
echo "---"
echo -e "Let's check that our ${GREEN}copy${NC} of ${GREEN}${WEBSITE_TITLE}${NC} website is running"
pe "firefox http://${WEBSITE_URL}.copy &"
wait

echo ""
echo "---"
echo -e "Let's imagine that a malicious user as found a vulnerability in the website to ${RED}inject PHP code${NC}"
pe "firefox http://${WEBSITE_URL}.copy/attack.php &"
wait

echo ""
echo "---"
echo "Let's see how our website looks like now !!! "
pe "firefox http://${WEBSITE_URL}.copy &"
wait

echo ""
echo "---"
echo -e "${GREEN}Investigate${NC} in VMware Carbon Black Cloud console with the following query:"
echo "(process_name:apache2 AND childproc_name:\/usr\/bin\/dash)"
echo -e "Create an ${GREEN}custom Indicator of Compromise (IOC]${NC} and rerun the attack:"
pe "firefox http://${WEBSITE_URL}.copy/attack.php &"
wait

wait
echo ""
echo "---"
echo -e "Now we will ${RED}ban the hash${NC} of a binary called ${RED}sleepy_binary${NC} and we will try to execute it."
echo -e "Let's compute the ${RED}SHA256${NC} of this binary:"
pe "sha256sum sleepy_binary"
wait

echo "---"
echo -e "Now ${RED}ban this hash${NC} in VMware Carbon Black Cloud console:"
echo "Enforce -> Reputation"
wait

echo "---"
echo -e "${GREEN}Wait a minute${NC} for the policy to be applied on Linux"
wait
echo "Now we will try to launch this binary"
echo "For the first run, the process is killed very quickly"
pe "./sleepy_binary"
echo ""

wait
echo "For the following launches, the process can not even start"
pe "./sleepy_binary"
echo ""

echo "---"
echo -e "VMware Carbon Black provides a ${GREEN}Linux test file${NC}, something like ${GREEN}EICAR${NC} on Windows"
echo "Let's download it"
pe "wget https://github.com/slist/LinuxMalware/raw/main/cctest"
echo ""
echo "And run it"
pe "./cctest"
echo ""
echo "And once again"
pe "./cctest"
echo ""
echo ""
echo "---"
echo -e "In 1 minute maximum, you will see some ${RED}alerts${NC} in VMware Carbon Black console"
echo ""
echo ""
echo -e "${GREEN}THANK YOU!${NC}"
echo ""
echo ""

