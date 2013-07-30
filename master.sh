#
# master.sh - by Doug Dobies <doug.dobies@gmail.com>
# Gathers info to configure MySQL Master node.
#

#!/bin/bash
clear


# verify root is running the script.
if [ $UID != 0 ]
	then
		echo "Sorry, you must be root to execute this script.";
		exit 
	fi

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
		echo "Did not find a pre-existing 'server-id' value, proceeding with the next check.";
		echo
	fi




echo "Searching for log_bin"
if [ `grep -c "^log_bin" $CFGFILE` -gt 0 ]
        then
                LNUM=`grep -n "^server-id" $CFGFILE|cut -d: -f1`
                echo "You already have a 'log_bin' declared at line $LNUM if $CFGFILE";
                echo "Script will now exit.";
                exit
        else
                echo "Did not find a pre-existing 'log_bin' value, proceeding with the next check.";
		echo
        fi


echo "Searching for binlog_do_db"
if [ `grep -c "^binlog_do_db" $CFGFILE` -gt 0 ]
        then
                LNUM=`grep -n "^binlog_do_db" $CFGFILE|cut -d: -f1`
                echo "You already have a 'binlog_do_db' declared at line $LNUM if $CFGFILE";
                echo "Script will now exit.";
                exit
        else
                echo "Did not find a pre-existing 'binlog_do_db' value, proceeding with the next check.";
		echo
        fi


echo "Searching for binlog_ignore_db"
if [ `grep -c "^binlog_ignore_db" $CFGFILE` -gt 0 ]
        then
                LNUM=`grep -n "^binlog_ignore_db" $CFGFILE|cut -d: -f1`
                echo "You already have a 'binlog_ignore_db' declared at line $LNUM if $CFGFILE";
                echo "Script will now exit.";
                exit
        else
                echo "Did not find a pre-existing 'binlog_ignore_db' value, all checks completed.";
		echo
        fi



# now we actually gather replication info to write to the configuration.
echo
echo "---------------------------------------------------------------";
echo
echo "Now we will declare some configuration settings.";
echo

echo -n "Please enter a unique numerical value (ex: 1) for your server-id: " 
read SERVERID;
echo

echo -n "Please enter the binary log file (ex: mysql-bin.log): ";
read BINLOG;

echo
echo
echo "You have the option of replicating a single database, or all databases within this MySQL instance.";
echo
echo -n "Do you want to replicate all databases? [Y/N]: ";
read ALLDB



if [[ `echo $ALLDB |awk '{print tolower($0)}'` == "y" ]]
	then
		echo "You have opted to replicate all databases, the internal 'mysql' db will be ignored.";
		BINLOGIGNOREDB="mysql";
	fi



# only ask for specific db ot replicate if user has not opted to replicate all dbs
if [[ -z $BINLOGIGNOREDB ]]
	then
		echo
		echo
		echo "You have opted to replicate a single database.";
		echo 
		echo -n "Enter the database you wish to replicate (case-sensitive): ";
		read BINLOGDODB
	fi

# give user a quick look at what will be added to their my.cnf
echo
echo "---------------------------------------------------------------";
echo
echo "Here are the changes we will make:";
echo "server-id = $SERVERID";
echo "log_bin = $BINLOG";


# if all dbs are being replicated.
if [[ ! -z $BINLOGIGNOREDB ]]
	then
		echo "binlog_ignore_db = mysql";
	fi


# if only specific db is being replicated.
if [[ ! -z $BINLOGDODB ]]
	then
		echo "binlog_do_db = $BINLOGDODB";
	fi


# last chance before writing the changes to disk.
echo
echo -n "Write these changes to $CFGFILE now? [Y/N]: ";
read WRITECFG


if [[ `echo $WRITECFG | awk '{print tolower($0)}'` == "y" ]]
	then
		echo "Writing changes to $CFGFILE...";


# this version for all db replication.
if [[ ! -z $BINLOGIGNOREDB ]]
        then
	SARGS="-i 's/^\[mysqld\]/\[mysqld\]\nserver-id=\"$SERVERID\"\nlog-bin=\"$BINLOG\"\nbinlog_ignore_db=\"mysql\"/' $CFGFILE"
	eval sed "$SARGS" 
	fi


# this version for specific db replication.
if [[ ! -z $BINLOGDODB ]]
        then
	SARGS="-i 's/^\[mysqld\]/\[mysqld\]\nserver-id=\"$SERVERID\"\nlog-bin=\"$BINLOG\"\nbinlog_do_db=\"$BINLOGDODB\"/' $CFGFILE"
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
## Phase 2: restart the DB to read the config changes, lock the tables, verify binary logfile and position, dump the db(s)
## unlock the db.
##
echo
echo
echo "The next step requires you to supply the root password for your MySQL DB."
echo "This is needed to restart the database, which will use the new configuration file,"
echo "and to query the staus of the DB, showing the binary logfile, and it's position."
echo "Finally, we'll take a dump of the database(s) and unloack the DB."
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



GetPass

echo "Restarting MySQL"
service mysql restart

# lock the db tables to create a current dump of the data.
mysql -u root --password="$PW1" -e  'FLUSH TABLES WITH READ LOCK'

# capture binary log filename, and current position ot a text file.
mysql -u root --password="$PW1" -e 'show master status'>/tmp/binlog.txt

echo "Your binary log filename, and it's current position have been saved to /tmp/binlog.txt"
echo "You will NEED this information when configuring your Slave MySQL server."

# make a dump of the specific DB to replicate if one exists.
if [[ ! -z $BINLOGDODB ]]
 then
	mysqldump -u root --password="$PW1" $BINLOGDODB >/tmp/$BINLOGDODB.sql
	echo 
	echo "A SQL Dump of TestDB has been created and is located at /tmp/$BINLOGDODB.sql"
	echo "You will need to copy this file onto the Slave MySQL Server."
	echo "It can be copied to /tmp and can be deleted AFTER you have imported the data."
 fi

#
# need to create dumps of ALL existing DB's if replication exists for all DB's
# This is NOT yet implemented.

# unlock previously locked db tables
mysql -u root --password="$PW1" -e "unlock tables"
echo "The MySQL tables have been unlocked and writes may once again occur."


echo
echo
echo "We need to create a special database user for replication.."
echo
echo -n "Please enter a replication username (ex: repl): "
read REPUSER

GetRPass

echo 
echo
echo -n "What is the IP Address of your Slave MySQL Server?: "
read SLAVEIP

echo
echo "Review the following:"
echo "Replication user: $REPUSER"
echo "Replication user password: $RPW1"
echo "Slave MySQL Host: $SLAVEIP"
echo
echo -n "Is this correct [Y/N]? ";
read REPOK


if [[ `echo $REPOK |awk '{print tolower($0)}'` == "y" ]]
        then
        echo "Creating the replication user.."
        mysql -u root --password="$PW1" -e "GRANT REPLICATION SLAVE ON *.* to $REPUSER@$SLAVEIP IDENTIFIED BY '$RPW1'"
        fi


echo
echo 
echo "[SUCCESS] You have successfully configured this MySQL Database as a Master.."
echo 
echo "You will now have to login to the Slave MySQL Server ($SLAVEIP) and execute the slave.sh script there."
exit
