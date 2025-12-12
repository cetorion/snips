
import boto3
import psycopg2

DB_ADMIN_USER = "admin"
DB_ADMIN_PASSWORD = ""

def write_to_file(identifier,dbs):
        with open("result_success.text", "a") as file:
            file.write(f"{identifier} \n")
            file.write("==================\n")
            file.write(f"{dbs} \n")
        print("File created successfully.")


def get_all_databases(dbname, dbuser, HOST, PORT):
      conn = psycopg2.connect(dbname=dbname, user=DB_ADMIN_USER , password=DB_ADMIN_PASSWORD, host=HOST, port=PORT, connect_timeout=5)
      cur = conn.cursor()
      #get all dbs except system DBS

      cur.execute("""
        SELECT datname FROM pg_database
        WHERE datistemplate = false AND datname NOT in ('postgres', 'template0', 'template1')
      """)

      databases=[row[0] for row in cur.fetchall()]
      cur.close()
      conn.close()
      return databases
    except Exception as e:
      print(e)
    else:
      print("****************************")

      conn = psycopg2.connect(dbname=dbname, user=DB_ADMIN_USER , password=DB_ADMIN_PASSWORD, host=HOST, port=PORT, connect_timeout=5)
      cur = conn.cursor()
      #get all dbs except system DBS

      cur.execute("""
        SELECT datname FROM pg_database
        WHERE datistemplate = false AND datname NOT in ('postgres', 'template0', 'template1')
      """)

      databases=[row[0] for row in cur.fetchall()]
      cur.close()
      conn.close()
      return databases

def get_all_endpoints():

    client = boto3.client('rds')

    #get all rds instance
    instances = client.describe_db_instances()
    clusters = client.describe_db_clusters()


    for db in instances['DBInstances']:
        identifier = db['DBInstanceIdentifier']
        print("============")
        # print(f"JSON Dump: {db}")
        endpoint = db['Endpoint']['Address']
        engine = db['Engine']
        port = db['Endpoint']['Port']
        dbname= db['DBName']
        dbuser = db['MasterUsername']
        print(identifier)
        dbs=get_all_databases(dbname, dbuser, endpoint, port)
        print(dbs)
        print("=================================================================================================")
        write_to_file(identifier, dbs)
       
get_all_endpoints()

