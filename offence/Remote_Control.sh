#!/bin/bash

# =====================
# Functions begins here
# =====================

function help_message() {
	echo "Run commands anonymously: two layer anonymity using Tor and VPS"
	echo "==============================================================="
	echo
	echo "Syntax: Remote_Control.sh -c ISO_Country [-f ips_file] | ip_address "
	echo "options:"
	echo "	c: Country in ISO format"
	echo "	f: [Optional] Run Remote Control on a file of ips"
	echo "	h: Help prompt"
	echo
	echo "Set-up: Input your VPS login information in Remote_Control.conf"
	
}

function inst() {
	installnipe() {
		# Function to install nipe if not in usr/local/src folder
		echo "[*] Installing Nipe"
		
		# Install Nipe from github repo
		git clone https://github.com/htrgouvea/nipe && cd nipe
		sudo cpan install Try::Tiny Config::Simple JSON
		sudo perl nipe.pl install
		
		# Move nipe to /usr/local/src folder
		cd ~-
		sudo mv nipe /usr/local/src
	}
	
	installgeoiplookup() {
		# Function to install geoiplookup
		echo "[*] Installing geoiplookup"
		sudo apt-get -y install geoip-bin
	}
	
	installsshpass() {
		echo "[*] Installing sshpass"
		sudo apt-get -y install sshpass
	}
	
	createconf() {
		echo "[*] Creating Remote_Control.conf file"
		echo "# VPS Details" > Remote_Control.conf 
		echo "server=" > Remote_Control.conf
		echo "user=" > Remote_Control.conf
		echo "password=" > Remote_Control.conf
	}
	
	# Check for nipe
	if ! [ -d "/usr/local/src/nipe" ]; then
		installnipe
	fi
	
	# Check for geoiplookup
	if ! [ -x "$(command -v geoiplookup)" ]; then
		installgeoiplookup
	fi
	
	# Check for sshpass
	if ! [ -x "$(command -v sshpass)" ]; then
		installsshpass
	fi
	
	# Check for Remote_Control.conf file
	if ! [ -f ./Remote_Control.conf ]; then
		createconf
	fi
}

function anon() {
	# Get Current ip address
	country=$1
	cd /usr/local/src/nipe
	current_IP=$(sudo perl nipe.pl status | grep Ip | awk '{print $NF}')
	current_loc=$(geoiplookup $current_IP | awk '{print $4}' | sed 's/,//')
	
	# Check country of ip address
	if [ "$current_loc" == "$country" ]; then
		# Run nipe if current location is Singapore
		echo "[!] You are not anonymous"
		echo "[*] Running Nipe"
		
		sudo perl nipe.pl restart
		new_IP=$(sudo perl nipe.pl status | grep Ip | awk '{print $NF}')
		new_loc=$(geoiplookup $new_IP | awk -F: '{print $NF}') 
		
		echo "[*] Your current IP is $new_IP"
		echo "[*] Your IP is located in$new_loc"
	fi
	
	echo "[*] You are Anonymous"
	
	# Move back to current directory
	cd ~-
}

function stopanon() {
	echo "[*] Turning Nipe off"
	
	cd /usr/local/src/nipe
	sudo perl nipe.pl stop
	
	new_IP=$(sudo perl nipe.pl status | grep Ip | awk '{print $NF}')
	new_loc=$(geoiplookup $new_IP | awk -F: '{print $NF}') 
	echo "[*] Your current IP is $new_IP"
	echo "[*] Your IP is located in $new_loc"
}

function vps() {
	# Parse input
	ip=$1
	working_dir=$2
	whois_query=$3
	nmap_query=$4
	
	# Create directory to store info 
	mkdir -p $working_dir
	cd $working_dir
	
	if [ "$whois_query" == "yes" ]; then
		whois $ip > whois.info
	fi
	
	if [ "$nmap_query" == "yes" ]; then
		nmap -sV -Pn -p- --host-timeout 10m $ip -oN nmap_result 
	fi
}

# ==================
# Script begins here
# ==================

# Check if user has packages needed to run command
inst

# Check if user has inputted any argument
if [ $# -eq 0 ]; then
	echo "[!] You did not provide any arguments"
	echo
	help_message
	exit 1
fi

# Parse user input
while getopts ":hc:f:" opt; do
	case ${opt} in
		h)
			help_message
			exit
		;;
		c)
			country=$OPTARG
		;;
		f)
			ips=$OPTARG
		;;
		\?)
			echo "[!] Invalid option: $OPTARG" 1>&2
			echo
			help_message
			exit 1
		;;
		:)
			echo "[!] Invalid option: $OPTARG requires an argument" 1>&2
			echo
			help_message
			exit 1
		;;
	esac
done
shift $((OPTIND -1))

# Get ip address if user inputted one
ip=$1

# Check if user has sepcified an ISO country
if [ -z "$country" ]; then
	echo "[!] Please specify a country with the -c flag."
	echo
	help_message
	exit 1
fi

# Check if user specified both a list of ips and an ip
if [ -e "$ips" ] && [ -n "$ip" ]; then
	echo "[!] You have entered both a file of ips and an ip. Please only specify one."
	echo
	help_message
	exit 1
fi 

# Get server login information from Remote_Control.conf
while read -r line; do
	# Skip comment lines
	if [ "${line::1}" == "#" ]; then
		continue
	fi
	
	# Get configuration variables
	var=$(echo $line | awk -F= '{print $1}')
	value=$(echo $line | awk -F= '{print $2}')
	
	# If any of the fields are empty, exit script
	if [ -z "$value" ]; then
		echo "[!] There is no value specified for $var"
		echo "[*] Please enter your VPS login information in the Remote_Control.conf file"
		exit 1
	fi
	
	# Get values from conf file
	if [ "$var" == "server" ]; then
		server="$value"
	fi
	
	if [ "$var" == "user" ]; then
		user="$value"
	fi
	
	if [ "$var" == "password" ]; then
		password="$value"
	fi
done < <(cat Remote_Control.conf | sed '1d')

# Get user input on what services to run on specified ip(s)

# Check if user wants to run whois query
read -r -p "Run whois query on ip(s)? (Y/n/q) " input
case "$input" in
	[Yy])
		whois_query="yes"
	;;
	"")
		whois_query="yes"
	;;
	[Nn])
		whois_query="no"
	;;
	[Qq])
		echo "[*] Thank you for using Remote_Control. Good Bye!"
		exit
	;;
	*)
		echo "[!] You have entered an invalid option. Please try again."
		exit 
	;;
esac

# Check if user wants to run nmap query
read -r -p "Run nmap query on ip(s)? (Y/n/q) " input
case "$input" in
	[Yy])
		nmap_query="yes"
	;;
	"")
		nmap_query="yes"
	;;
	[Nn])
		nmap_query="no"
	;;
	[Qq])
		echo "[*] Thank you for using Remote_Control. Good Bye!"
		exit
	;;
	*)
		echo "[!] You have entered an invalid option. Please try again."
		exit 
	;;
esac

# Get date to help organise folders
date=$(date +%d%m%y)

# Start anonymity service
anon $country

# Check if user inputted file of ips
if [ -e "$ips" ]; then
	for ip in $(cat $ips); do
		echo "[*] Running scripts on $ip"
		working_dir=./Remote_Control_logs/$ip/$date
		sshpass -p $password ssh -o StrictHostKeyChecking=no $user@$server "$(typeset -f vps); vps $ip $working_dir $whois_query $nmap_query"
	done
# Run scripts for given ip
else
	echo "[*] Running scripts on $ip"
	working_dir=./Remote_Control_logs/$ip/$date
	sshpass -p $password ssh -o StrictHostKeyChecking=no $user@$server "$(typeset -f vps); vps $ip $working_dir $whois_query $nmap_query"
fi

# Stop anonymity service
stopanon

# Inform user on what has been done
echo "Thank you for using Remote_Control!"
echo "All information has been saved in ~/Remote_Control_logs in your vps."
