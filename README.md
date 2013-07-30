mars
====

MySQL Automatic Replication Scripts

This project was born after failing to complete a web-based MySQL replication tutorial,
I decided just making the replication configuration script-based might be a simpler
solution for many folks.

There are two scripts included in this project:

master.sh - This script configures a Master MySQL node, you will have the option to
replicate a single database, or ALL databases.

slave.sh - This script configures a Slave MySQL node, you will have to provide some
configuration information from the Master (dont worry, the script saves that to a text
file on the Master) and actually copy the db dumps from the Master manually, but this
script will largely automate all other steps to complete a functioning replicated pair.


DISCLAIMER:
I take no responsibility if these scripts break your server, melt it down, cause it to 
stop functioning, or any other possible or impossible bad result. Using these scripts
should be done at your own risk. 
