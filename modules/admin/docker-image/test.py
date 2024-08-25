from mySqlServerClient import MySQLServerConnector
from mySqlDBClient import MySQLDBConnector

def list_database():
    mysql = MySQLServerConnector()
    mysql.health_check()
    mysql.list_database()

def create_database():
    mysql = MySQLServerConnector()
    mysql.health_check()
    mysql.create_database('testdb1')

def create_table():
    with MySQLDBConnector('testdb1') as mysql:
        res = mysql.execute_query('CREATE TABLE test_table (id INT PRIMARY KEY, name VARCHAR(50), age INT)')
        print(f"Result: {res}")

def list_table():
    with MySQLDBConnector('testdb1') as mysql:
        res = mysql.execute_query('SHOW TABLES')
        print(f"Result: {res}")

def insert_data():
    data = [
        (1, 'John', 25),
        (2, 'Jane', 30),
        (3, 'Doe', 35)
    ]
    with MySQLDBConnector('testdb1') as mysql:
        for d in data:
            res = mysql.execute_query(f"INSERT INTO test_table VALUES {d}")
            print(f"Result: {res}")

def select_data():
    with MySQLDBConnector('testdb1') as mysql:
        res = mysql.execute_query('SELECT * FROM test_table')
        print(f"Result: {res}")
