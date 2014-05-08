#!/bin/bash

NEWUSER=""
PUBKEY=""
PUBKEYSIG=""

HEADER='
######################################################################
#		  F5 - A Rapid Provisioning Script		     #
#	   (C) 2013 Mischif, Released under the MPL, v. 2.0	     #
#  This Source Code Form is "Incompatible With Secondary Licenses",  #
#	  as defined by the Mozilla Public License, v. 2.0.	     #
######################################################################
'
CREATEUSER=true
SETROOTPW=false
EXTRACMDS=false
NOPWSUDO=false
USEPASS=false
SSHAUTH=false
SUDOER=false
DEBUG=false
HALP=false
DSUP=false
RESULT=0
ARGS=($@)

set_debservers () {
DEBSERVERS=""
TAILSERVER=`echo -e $DEBSERVERS | tail -n 1`

if [[ ! -f /etc/apt/sources.list ]] ; then
	echo "Can't find the debserver file, is this a Debian distro?"
	return 1
	fi

if [[ $DEBSERVERS == "" ]] ; then
	echo "No debservers found, did you include any?"
	return 1
	fi

if [[ `grep "#" /etc/apt/sources.list | wc -l` == 0 ]] ; then
	sed -i 's/^/#/' /etc/apt/sources.list

	RESULT=$?
	if [[ $DEBUG == true ]] ; then
		echo "comment out existing debservers return code: $RESULT"
		fi
	if [[ $RESULT != 0 ]] ; then
		echo "Error commenting out original debservers"
		return 1
		fi
	fi

if [[ `grep $TAILSERVER /etc/apt/sources.list | wc -l` == 0 ]] ; then
	echo -e $DEBSERVERS >> /etc/apt/sources.list

	RESULT=$?
	if [[ $DEBUG == true ]] ; then
		echo "adding new debservers return code: $RESULT"
		fi
	if [[ $RESULT != 0 ]] ; then
		echo "Error adding new debservers"
		return 1
		fi
	fi

return 0
}

set_sudo () {

if [[ `getent group sudo | wc -l` == 0 ]] ; then
	echo "Cannot find sudo group"
	return 1
	fi

if [[ $NOPWSUDO == true || $USEPASS == false ]] ; then
	if [[ ! -f /etc/sudoers ]] ; then
		echo "No sudoers file, cannot enable passwordless access"
		return 1
		fi

	if [[ `grep ") NOPASSWD: " /etc/sudoers | wc -l` != 0 ]] ; then
		return 0
		fi

	SUDOLINE=$(grep -n '%sudo' /etc/sudoers | cut -d: -f1)

	if [[ $SUDOLINE == "" ]] ; then
		echo "%sudo	ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers

		RESULT=$?
		if [[ $DEBUG == true ]] ; then
			echo "adding sudo group to sudoers return code: $RESULT"
			fi
		if [[ $RESULT != 0 ]] ; then
			echo "Error enabling passwordless access"
			return 1
			fi
	else
		sed -i "${SUDOLINE}s/) /) NOPASSWD: /" /etc/sudoers

		RESULT=$?
		if [[ $DEBUG == true ]] ; then
			echo "adding passwordless sudo support return code: $RESULT"
			fi
		if [[ $RESULT != 0 ]] ; then
			echo "Error enabling passwordless access"
			return 1
			fi
		fi
	fi

return 0
}

use_ssh_keys () {
wget -q $PUBKEY -O /tmp/auth-keys

if [[ ! -f /tmp/auth-keys ]] ; then
	echo "Couldn't download authorized_keys file"
	return 1
	fi

if [[ `sha1sum /tmp/auth-keys | cut -d " " -f1` != $PUBKEYSIG ]] ; then
	echo "Signatures did not match"
	rm /tmp/auth-keys
	return 1
	fi

mkdir -p $NEWUSER_HOME/.ssh

if [[ ! -d $NEWUSER_HOME/.ssh ]] ; then
	echo "Error creating user .ssh directory"
	return 1
	fi

if [[ -f $NEWUSER_HOME/.ssh/authorized_keys && `sha1sum $NEWUSER_HOME/.ssh/authorized_keys | cut -d " " -f1` == $PUBKEYSIG]] ; then
	return 0
	fi

mv /tmp/auth-keys $NEWUSER_HOME/.ssh/authorized_keys

if [[ ! -f $NEWUSER_HOME/.ssh/authorized_keys ]] ; then
	echo "Error moving authorized_keys file"
	rm /tmp/auth-keys
	return 1
	fi

chmod 600 $NEWUSER_HOME/.ssh/authorized_keys
RESULT=$?
if [[ $DEBUG == true ]] ; then
	echo "chmod authorized_keys return code: $RESULT"
	fi
if [[ $RESULT != 0 ]] ; then
	echo "Error setting authorized_keys privs"
	return 1
	fi

chmod 700 $NEWUSER_HOME/.ssh
RESULT=$?
if [[ $DEBUG == true ]] ; then
	echo "chmod .ssh directory return code: $RESULT"
	fi
if [[ $RESULT != 0 ]] ; then
	echo "Error setting .ssh privs"
	return 1
	fi
return 0
}

other_stuff () {
return 0
}

main () {
PROGRAMS="" #Include wget to get your SSH keys, sudo to set sudo privs

if [[ $SETROOTPW == true ]] ; then
	echo "Setting root password..."
	passwd

	RESULT=$?
	if [[ $RESULT != 0 ]] ; then
		echo "Error setting root password"
		exit 1
		fi
	fi

if [[ $DSUP == true ]] ; then
	echo "Adding desired debservers..."
	set_debservers

	RESULT=$?
	if [[ $DEBUG == true ]] ; then
		echo "set debservers return code: $RESULT"
		fi
	if [[ $RESULT != 0 ]] ; then
		exit 1
		fi
	fi

echo "Installing default programs..."
apt-get update
apt-get upgrade
apt-get -f -y install
apt-get -y install $PROGRAMS

if [[ $CREATEUSER == true ]] ; then
	echo "Adding new user..."

	if [[ $USEPASS == false ]] ; then
		adduser --disabled-password $NEWUSER
		else
			adduser $NEWUSER
		fi

		RESULT=$?
		if [[ $DEBUG == true ]] ; then
			echo "user creation return code: $RESULT"
			fi
		if [[ $RESULT != 0 ]] ; then
			echo "Error creating new user"
			exit 1
			fi
	fi

NEWUSER_HOME=$(getent passwd $NEWUSER | cut -d: -f6)

if [[ $SSHAUTH == true ]] ; then
	echo "Importing authorized_keys file for new user..."
	use_ssh_keys

	RESULT=$?
	if [[ $DEBUG == true ]] ; then
		echo "auth_keys import return code: $RESULT"
		fi
	if [[ $RESULT != 0 ]] ; then
		exit 1
		fi
	fi

if [[ $SUDOER == true ]] ; then
	echo "Setting sudo privs for new user..."
	set_sudo

	RESULT=$?
	if [[ $DEBUG == true ]] ; then
		echo "set sudo privs return code: $RESULT"
		fi
	if [[ $RESULT != 0 ]] ; then
		exit 1
		fi
	fi


if [[ $EXTRACMDS == true ]] ; then
	echo "Executing extra commands..."
	other_stuff

	RESULT=$?
	if [[ $DEBUG == true ]] ; then
		echo "extra commands return code: $RESULT"
		fi
	if [[ $RESULT != 0 ]] ; then
		exit 1
		fi
	fi

chown $NEWUSER:$NEWUSER -R $NEWUSER_HOME

RESULT=$?
if [[ $DEBUG == true ]] ; then
	echo "home dir chown return code: $RESULT"
	fi
if [[ $RESULT != 0 ]] ; then
	echo "Error changing ownership"
	exit 1
	fi

echo "Finished!"
exit 0
}

parse_options () {
for (( opt=0; opt<${#ARGS[@]}; opt++ )) ; do
case ${ARGS[$opt]} in

	--update-debservers)
		DSUP=true
		;;

	--use-password)
		USEPASS=true
		;;

	--sudoer)
		SUDOER=true
		;;

	--no-pw-sudoer)
		SUDOER=true
		NOPWSUDO=true
		;;

	--set-root-pw)
		SETROOTPW=true
		;;

	--ssh-auth)
		if [[ $PUBKEY == "" && $((opt+1)) -lt $((${#ARGS[@]}-1)) ]] ; then
			PUBKEY=${ARGS[$((opt+1))]}
			fi

		if [[ $PUBKEYSIG == "" && $((opt+2)) -lt $((${#ARGS[@]}-1)) ]] ; then
			PUBKEYSIG=${ARGS[$((opt+2))]}
			fi
		SSHAUTH=true
		;;

	--extra)
		EXTRACMDS=true
		;;

	--no-new-user)
		CREATEUSER=false
		;;

	-bp)
		SETROOTPW=true

		SUDOER=true
		NOPWSUDO=true

		SSHAUTH=true
		;;

	--debug|-d)
		DEBUG=true
		;;

	--help|-h)
		HALP=true
		;;

	*)
		if [[ $opt == $((${#ARGS[@]}-1)) && $NEWUSER == "" ]] ; then
			NEWUSER=${ARGS[$opt]}
			fi
		;;
	esac
	done

	if [[ $SSHAUTH == true ]] ; then
		if [[ $PUBKEY == "" || $PUBKEYSIG == "" ]] ; then
			HALP=true
			fi
		fi

if [[ $NEWUSER == "" || $USER != "root" ]] ; then
	HALP=true
	return 1
	fi
}

help () {
cat << __HELPTXT__ 
				USAGE
$0 [opts] username
$0 [opts] --ssh-auth {authorized_keys address} {signature} username

NOTE: This script must be run as root

				OPTIONS
-bp			Create new passwordless user with sudo privs,
			import SSH key, change root PW
			(requires embedded auth_keys address, signature)
--extra			Run deployment-specific code
--no-new-user		Use an existing user over creating a new one
--set-root-pw		Set password for root user
--ssh-auth		Import authorized_keys file for user
--update-debservers	Set new debservers for /etc/apt/sources.list
--use-password		Set password for new non-root user
--[no-pw-]sudoer	[without password conf.] Give new user sudo privs

Additionally, if you're lazy you can embed your desired username, auth_keys address and auth_keys sha1sum in this script for ease of reuse, so you don't have to enter them at the command line every time you run it.
__HELPTXT__
exit 0
}

parse_options

if [[ $HALP == true ]] ; then
	help
else
	echo "$HEADER"
	main
	fi
