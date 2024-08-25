import mysql.connector
from mysql.connector import Error
import os

class MySQLServerConnector:
    def __init__(self):
        self.host = os.getenv('MYSQL_HOST', 'localhost')
        self.port = os.getenv('MYSQL_PORT', '3306')
        self.user = 'root'
        self.password = 'rootpassword'
        self.connection = mysql.connector.connect(
            host=self.host,
            port=self.port,
            user=self.user,
            password=self.password
        )

    def health_check(self):
        if not self.connection:
            return False
        if not self.connection.is_connected():
            return False
        return True

    def create_database(self, database):
        try:
            if not self.connection.is_connected():
                print("MySQL connection is not open")
            else:
                cursor = self.connection.cursor()
                cursor.execute(f"CREATE DATABASE IF NOT EXISTS {database}")
                print(f"Database {database} created successfully")
        except Error as e:
            print(f"Error creating database: {e}")
        finally:
            if self.connection.is_connected():
                self.connection.close()
                print("MySQL connection is closed")

    def delete_database(self, database):
        try:
            if not self.connection.is_connected():
                print("MySQL connection is not open")
            else:
                cursor = self.connection.cursor()
                cursor.execute(f"DROP DATABASE IF EXISTS {database}")
                print(f"Database {database} deleted successfully")
        except Error as e:
            print(f"Error deleting database: {e}")
        finally:
            if self.connection.is_connected():
                self.connection.close()
                print("MySQL connection is closed")

    def list_database(self):
        try:
            if not self.connection.is_connected():
                print("MySQL connection is not open")
            else:
                cursor = self.connection.cursor()
                cursor.execute("SHOW DATABASES")
                databases = cursor.fetchall()
                print("List of databases:")
                res = []
                for db in databases:
                    res.append(db[0])
                return res
        except Error as e:
            print(f"Error listing databases: {e}")
        finally:
            if self.connection.is_connected():
                self.connection.close()
                print("MySQL connection is closed")
