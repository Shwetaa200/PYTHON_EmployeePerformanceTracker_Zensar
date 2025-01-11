import cx_Oracle # type: ignore

# Oracle database connection details
DB_USERNAME = "system"
DB_PASSWORD = "root"
DB_DSN = "localhost/8080"  # e.g., "localhost/XEPDB1"

# Queries to fetch data from tables
QUERIES = {
    "Employees": "SELECT * FROM Employees",
    "Performance_Reviews": "SELECT * FROM Performance_Reviews",
    "Goals": "SELECT * FROM Goals",
    "Departments": "SELECT * FROM Departments",
    "Performance_Review_Log": "SELECT * FROM Performance_Review_Log",
    "Notifications": "SELECT * FROM Notifications",
}

def fetch_and_print_data():
    try:
        # Connect to the Oracle database
        connection = cx_Oracle.connect(DB_USERNAME, DB_PASSWORD, DB_DSN)
        cursor = connection.cursor()

        for table_name, query in QUERIES.items():
            print(f"\n--- Data from {table_name} ---")
            cursor.execute(query)

            # Fetch column names
            columns = [col[0] for col in cursor.description]

            # Print column names
            print(" | ".join(columns))
            print("-" * (len(columns) * 20))

            # Fetch and print data rows
            rows = cursor.fetchall()
            for row in rows:
                print(" | ".join(map(str, row)))

    except cx_Oracle.DatabaseError as e:
        print(f"Database error occurred: {e}")

    finally:
        # Clean up and close the database connection
        if cursor:
            cursor.close()
        if connection:
            connection.close()

if __name__ == "__main__":
    fetch_and_print_data()
