#!/usr/bin/python
import psycopg2

hostname = 'localhost'
username = 'rahmanr'
password = 'saif@4200'
database = 'cucumber_db'

print("Using psycopg2")


# Simple routine to run a query on a database and print the results:
def doQuery(conn, query: str):
    cur = conn.cursor()

    cur.execute(query)

    return cur.fetchall()


if __name__ == '__main__':
    myConnection = psycopg2.connect(host=hostname, user=username, password=password, dbname=database)
    results = doQuery(myConnection, 'SELECT first_name, last_name FROM sandpit_rahmanr.customer')
    for firstname, lastname in results:
        print(firstname, lastname)
    myConnection.close()

##print "Using PyGreSQL"
##import pgdb
##myConnection = pgdb.connect( host=hostname, user=username, password=password, database=database )
##doQuery( myConnection )
##myConnection.close()
