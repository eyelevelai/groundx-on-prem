from mySqlServerClient import MySQLServerConnector

def list_database():
    mysql = MySQLServerConnector()
    mysql.health_check()
    mysql.list_database()

def create_database():
    mysql = MySQLServerConnector()
    mysql.health_check()
    mysql.create_database('testdb1')

list_database()
create_database()
