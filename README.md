# Password Set
.pgpass is a common way to store connection information in PostgreSQL instead of typing password every time your login to your database using psql.


**host:port:db_name:user_name:password**
Example:
localhost:5432:postgres:myadmin:Str0ngP@ssw0rd

`nano ~/.pgpass

127.0.0.1:5432:*:username:password

chmod 0600 ~/.pgpass`


##Crontab 
55 2 * * * /home/ubuntu/backup/backup-postgres.sh >> /tmp/myjob.log 2>&1
