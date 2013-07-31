#
# slave.sh - by Doug Dobies <doug.dobies@gmail.com>
# Gathers info to configure MySQL Slave node.
#

#!/bin/bash
clear


# verify root is running the script.
if [ $UID != 0 ]
	then
		echo "Sorry, you must be root to execute this script.";
		exit 
	fi

echo "Before you will be able to successfully configure the Slave MySQL Server,"
echo "you will need the Master SQL Server's IP Address, the replication user/password,"
echo "and the binary log file, and position number."
echo
echo "Additionally, you should import the databases to be replicated before running"
echo "this script, that .sql file should have been copied to this server, in /tmp"
echo
echo "Most importantly, you must be able to connect to the Master from this host."
echo
echo "If you have all of the required information, and the databases have been imported"
echo -n "then press a key to continue, otherwish CTRL-C to abort. "
read READYTOGO

echo "We will now search for your my.cnf file...";
echo

# search for common paths to my.cnf
if test -s /etc/my.cnf 
	then
		echo "[FOUND] /etc/my.cnf and will use this as the default configuration file.";     
		CFGFILE="/etc/my.cnf";
		echo
	else
		echo "[NOT FOUND] /etc/my.cnf";
		echo
fi

if test -s /etc/mysql/my.cnf
	then
		echo "[FOUND] /etc/mysql/my.cnf and will use this as the default configuration file.";
		CFGFILE="/etc/mysql/my.cnf";
		echo 
	else
		echo "[NOT FOUND] /etc/mysql/my.cnf";
		echo
		echo "Did NOT find a default mysql configuration file.";
		sleep 2;
		echo

		# ask user to supply the path to their my.cnf
		echo -n "Please enter the location of your mysql configuration file:";
		read CFGFILE

		# verify that file exists.
		if [[ ! -z $CFGFILE ]]
			then
				echo "$CFGFILE Not found, exiting!";
				exit
			fi
fi
echo 

# next, search the my.cnf for existing replication info.
echo
echo "---------------------------------------------------------------";
echo
echo
echo "Next we will query $CFGFILE for pre-existing replication data..";
echo "Press a key to continue.";

read PAUSE

echo "Searching for server-id";
if [ `grep -c "^server-id" $CFGFILE` -gt 0 ]
	then
		LNUM=`grep -n "^server-id" $CFGFILE|cut -d: -f1`
		echo "You already have a 'server-id' declared at line $LNUM if $CFGFILE";
		echo "Script will now exit.";
		exit
	else
		echo "Did not find a pre-existing 'server-id' value.";
		echo
	fi




# now we actually gather replication info to write to the configuration.
echo
echo "---------------------------------------------------------------";
echo
echo "Now we will declare some configuration settings.";
echo

echo -n "Please enter a unique numerical value (ex: 2) for your server-id: " 
read SERVERID;
echo


# last chance before writing the changes to disk.
echo
echo -n "Write these changes to $CFGFILE now? [Y/N]: ";
read WRITECFG


if [[ `echo $WRITECFG | awk '{print tolower($0)}'` == "y" ]]
	then
		echo "Writing changes to $CFGFILE...";
		SARGS="-i 's/^\[mysqld\]/\[mysqld\]\nserver-id=\"$SERVERID\"\n/' $CFGFILE"
		eval sed "$SARGS" 
	fi


echo
echo "[SUCCESS] Your replication updates to $CFGFILE are complete."


	# if they choose not to write the changes..	
	else
		echo "Changes not written to $CFGFILE..";
		exit
fi

##
## Phase 2: restart the DB to read the config changes
##
echo
echo
echo "The next step requires you to supply the root password for your MySQL DB."
echo "This is needed to restart the database, which will use the new configuration file."
echo
echo "Press any key to continue.."

read BLAH


GetPass() {
echo -n "Please enter the root password for this MySQL instance: "
read PW1

echo -n "Please re-type the password to confirm: "
read PW2

if [[ $PW1 != $PW2 ]]
        then
                echo "Passwords do not match, try again."
                GetPass
        fi
}

GetPass



echo 
echo -n "Enter the replication user's name: "
read REPUSER

GetRPass() {
echo
echo -n "Please enter the replication user's password: "
read RPW1

echo
echo -n "Please retype the password to confirm: "
read RPW2

if [[ $RPW1 != $RPW2 ]]
        then
                echo "Passwords do not match, try again."
                GetRPass
        fi
}

GetRPass

echo 
echo -n "Enter the binary log filename: "
read BINLOG

echo -n "Enter the position number of the binary log: "
read BINLOGPOS

echo
echo -n "What is the IP Address of your Master MySQL Server?: "
read MASTERIP

echo
echo "Review the following:"
echo "Replication user: $REPUSER"
echo "Replication user password: $RPW1"
echo "Master MySQL Host: $MASTERIP"
echo "Binary Log filename: $BINLOG"
echo "Binary Log Position: $BINLOGPOS"

echo
echo -n "Is this correct [Y/N]? ";
read REPOK


if [[ `echo $REPOK |awk '{print tolower($0)}'` == "y" ]]
        then
	echo "Restarting mysqld.."
	service mysqld restart

        echo "Configuring Slave.."
        mysql -u root --password="$PW1" -e "CHANGE MASTER TO MASTER_HOST='$MASTERIP', MASTER_USER='$REPUSER', MASTER_PASSWORD='$RPW1', MASTER_LOG_FILE='$BINLOG', MASTER_LOG_POS=$BINLOGPOS;"
	echo "Starting Slave.."
	mysql -u root --password="$PW1" -e "START SLAVE;"

	echo "Slave Status.."
	mysql -u root --password="$PW1" -e "SHOW SLAVE STATUS;"
        fi


echo
echo 
echo "[SUCCESS] You have successfully configured this MySQL Database as a Slave.."
echo 
exit
