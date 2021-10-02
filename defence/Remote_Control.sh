#!/bin/bash

function help_message() {
	echo "Basic security maintenance and analysis of your server"
	echo "======================================================"
	echo "Syntax: Remote_Control.sh [-a] [-f file of ips | ip_address]"
	echo "options:"
	echo "	a: [Optional] Become anonymous using Nipe (Source: https://github.com/htrgouvea/nipe)"
	echo "	f: [Optional] Run maintenance on file containing multiple servers"
	echo
	echo "See Remote_Control.sh help for more information on how Remote_Control helps to maintain your server."
}

function help_verbose() {
	echo "Basic security maintenance and analysis of your server"
	echo "======================================================"
	echo "[*] Update and upgrade all packages in server (Only for Ubuntu and Debian servers for current version)"
	echo "[*] Save auth.log file into your local system"
	echo "[*] Scan for open ports and services"
	echo "[*] Check for potental exploits that hackers may use using searchsploit"
	echo
	echo "Syntax: Remote_Control.sh [-a] [-f file of ips | ip_address]"
	echo "options:"
	echo "	a: [Optional] Become anonymous using Nipe (Source: https://github.com/htrgouvea/nipe)"
	echo "	f: [Optional] Run maintenance on file containing multiple servers"	
	echo
	echo "Important note: This script assumes that you have root access to all specified servers."
	echo "Additionally, this script expects to be able to ssh into the servers using ssh-keys."
}

function check_packages() {
	# Check for SCP
	if ! [ -x "$(command -v scp)" ]; then
		echo "[!] You do not have one or more required packages installed."
		echo "[*] Please install required packages using Remote_Control.sh install"
		exit 1
	fi
	
	# Check for nipe
	if ! [ -d "/usr/local/src/nipe" ]; then
		echo "[!] You do not have one or more required packages installed."
		echo "[*] Please install required packages using Remote_Control.sh install"
		exit 1
	fi
	
	# Check for geoiplookup
	if ! [ -x "$(command -v geoiplookup)" ]; then
		echo "[!] You do not have one or more required packages installed."
		echo "[*] Please install required packages using Remote_Control.sh install"
		exit 1
	fi
	
	# Check for sshpass
	if ! [ -x "$(command -v sshpass)" ]; then
		echo "[!] You do not have one or more required packages installed."
		echo "[*] Please install required packages using Remote_Control.sh install"
		exit 1
	fi
}

function inst() {
	installscp() {
		# Function to install geoiplookup
		echo "[*] Installing installscp"
		sudo apt-get -y install openssh-client
	}
	
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
	
	sudo apt-get update
	installnipe
	installgeoiplookup
	installsshpass
}

function anon() {
	# Get Current ip address
	cd /usr/local/src/nipe
	current_IP=$(sudo perl nipe.pl status | grep Ip | awk '{print $NF}')
	current_loc=$(geoiplookup $current_IP | awk '{print $NF}')
	
	# Check country of ip address
	if [ "$current_loc" == "Singapore" ]; then
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
	# Middleware functions
	check_ssh_possible() {
		ip=$1
		# Check if ssh connection with server can be established
		# Check if SSH service is open
		ssh_open=$(nmap $ip -Pn -p ssh | grep open)
		if [ -z "$ssh_open" ]; then
			echo "[!] SSH port is not open."
			return 2
		fi
		
		# Check if possible to ssh into server
		ssh root@$ip true > /dev/null 2>&1
		if [ $? -ne 0 ]; then
			echo "[!] Please check if you have configured your SSH keys with the specified server at $ip correctly."
			return 3
		fi
	}
	
	# Functions to maintain servers
	update_packages() {
		# Update all packages in server (To ensure that all security patches are applied)
		apt-get -y update
		apt-get -y upgrade
	}
	
	check_virus() {
		# Scan all files in server if there is a virus
		echo ""
	}
	
	get_logs() {
		# Get logs for analysis on local machine
		echo ""
	}
	
	check_vuln() {
		# Check for open ports and their services. Determine if there are any exploits available
		working_dir=$1
		cd $working_dir
		nmap -sV -Pn -p- --host-timeout 10m $ip -oX nmap.xml
		xsltproc -o nmap.html nmap.xml
		searchsploit -x --nmap nmap.xml > searchsploit.res
		num_vuln=$(grep / searchsploit.res | wc -l)
		rm nmap.xml
		cd ~-
	}
		
	# Get user input for function
	ip=$1
	date=$2
		
	# Check if it is possible to SSH into server
	check_ssh_possible $ip
	if [ $? -ne 0 ]; then
		exit $?
	fi
	
	# Create directories to store information from maintenance
	mkdir -p ./Remote_Control_logs/$ip/$date
	working_dir=./Remote_Control_logs/$ip/$date
	
	# Run maintenance
	ssh root@$ip "$(typeset -f update_packages); update_packages"
	scp root@$ip:/var/log/auth.log $working_dir
	check_vuln $working_dir
}

# ==================
# Script begins here
# ==================

# Check if user has inputted any argument
if [ $# -eq 0 ]; then
	echo "[!] You did not provide any arguments"
	help_message
	exit 5
fi

# Check first argument for subcommands
subcommand=$1
case  "$subcommand" in
	install)
		inst
		exit
	;;
	help)
		help_verbose
		exit
	;;
esac

while getopts ":haf:" opt; do
	case ${opt} in
		h)
			help_message
			exit
		;;
		a)
			anon="True"
		;;
		f)
			ips=$OPTARG
		;;
		\?)
			echo "[!] Invalid option: $OPTARG" 1>&2
			help_message
			exit 6
		;;
		:)
			echo "[!] Invalid option: $OPTARG requires an argument" 1>&2
			help_message
			exit 7
		;;
	esac
done
shift $((OPTIND -1))
ip=$1

# Get current date to organise data
date=$(date +%d%m%y)

# Start anonymity service
if [ "$anon" ]; then
	anon
fi

# Run maintenance on server(s)
if [ -e "$ips" ]; then
	for ip in $(cat $ips); do
		echo "[*] Running scripts on $ip"
		vps $ip $date
	done
else
	vps $ip $date
fi


# Stop anonymity service
if [ "$anon" ]; then
	stopanon
fi

# Inform user on what has been done
echo "Thank you for using my program!"
echo "All information has been saved in ./Remote_Control_logs"
echo "For more information on how this script helps to maintain your servers, run Remote_Control.sh help"
