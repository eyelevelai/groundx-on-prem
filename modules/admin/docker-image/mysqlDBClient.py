import mysql.connector
from mysql.connector import Error
import os

class MySQLDBConnector:
    def __init__(self, database):
        self.host = os.getenv('MYSQL_HOST', 'localhost')
        self.port = os.getenv('MYSQL_PORT', '3306')
        self.user = 'root'
        self.password = 'rootpassword'
        self.database = database
        self.connection = None

    def connect(self):
        try:
            self.connection = mysql.connector.connect(
                host=self.host,
                port=self.port,
                user=self.user,
                password=self.password,
                database=self.database
            )
            if self.connection.is_connected():
                print("MySQL connection established")
        except Error as e:
            print(f"Error connecting to MySQL: {e}")
            self.connection = None

    def execute_query(self, query):
        if not self.connection or not self.connection.is_connected():
            print("MySQL connection is not open")
            return None
        try:
            cursor = self.connection.cursor()
            cursor.execute(query)

            # Fetch all results to avoid "Unread result found" error
            if query.strip().lower().startswith("select") or "show" in query.lower():
                result = cursor.fetchall()
                return result

            self.connection.commit()
            print("Query executed successfully")
            return cursor.rowcount  # return the number of affected rows for non-SELECT queries

        except Error as e:
            print(f"Error executing query: {e}")
            return None
        finally:
            cursor.close()

    def close_connection(self):
        if self.connection and self.connection.is_connected():
            self.connection.close()
            print("MySQL connection is closed")

    def __enter__(self):
        self.connect()
        return self

    def __exit__(self, exc_type, exc_value, traceback):
        self.close_connection()
