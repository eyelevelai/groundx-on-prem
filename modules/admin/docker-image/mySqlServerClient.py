import mysql.connector
from mysql.connector import Error
import os

class MySQLServerConnector:
    def __init__(self):
        self.host = os.getenv('MYSQL_HOST', 'localhost')
        self.port = os.getenv('MYSQL_PORT', '3306')
        self.user = os.getenv('MYSQL_USER', 'testuser1')
        self.password = os.getenv('MYSQL_PASSWORD', 'testpassword1')
        self.connection = mysql.connector.connect(
            host=self.host,
            port=self.port,
            user=self.user,
            password=self.password
        )

    def health_check(self):
        if not self.connection:
            print("MySQL connection failed")
            return
        if not self.connection.is_connected():
            print("MySQL connection is closed")
            return
        print("MySQL connection is open")

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
                for db in databases:
                    print(db)
        except Error as e:
            print(f"Error listing databases: {e}")
        finally:
            if self.connection.is_connected():
                self.connection.close()
                print("MySQL connection is closed")
