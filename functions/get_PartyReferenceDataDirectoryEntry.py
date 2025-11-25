import os
import json
import boto3
import time

redshift = boto3.client("redshift-data")

def lambda_handler(event, context):
    # Variables de ambiente
    schema = os.environ.get("SCHEMA_NAME")
    table = os.environ.get("TABLE_NAME")
    external_database = os.environ.get("EXTERNAL_DATABASE")
    database = os.environ.get("REDSHIFT_DATABASE")
    workgroup = os.environ.get("REDSHIFT_WORKGROUP")

    if not schema or not table or not external_database:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Missing required environment variables"})
        }

    # Obtener ID del path parameter
    party_id = event.get("pathParameters", {}).get("id")
    if not party_id:
        return {
            "statusCode": 400,
            "body": json.dumps({"error": "Missing party ID parameter"})
        }

    # Cross-database query desde la base de datos local
    sql = (
        f"SELECT "
        f"    cod_cliente_crm as partyReferenceIdentifier, "
        f"    nombre_legal as partyLegalName, "
        f"    genero as gender, "
        f"    fecha_nacimiento as dateOfBirth, "
        f"    ocupacion as employmentOccupation, "
        f"    peps as pepIndicator, "
        f"    cliente_fatca as fatcaStatus, "
        f"    ciudad as city, "
        f"    municipio as district, "
        f"    departamento as locality, "
        f"    tipo_cliente as customerType "
        f"FROM {schema}.{external_database}.{table} "
        f"WHERE cod_cliente_crm = '{party_id}' "
        f"LIMIT 10;"
    )

    try:
        # Ejecuta la consulta conectándose a la base de datos local
        response = redshift.execute_statement(
            WorkgroupName=workgroup,
            Database=database,  # Conectar a base de datos local de Redshift
            Sql=sql
        )
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": f"Failed to execute query: {str(e)}"})
        }

    statement_id = response["Id"]
    
    # Espera a que termine
    while True:
        status = redshift.describe_statement(Id=statement_id)
        if status["Status"] in ["FINISHED", "FAILED", "ABORTED"]:
            break
        time.sleep(0.2)
    
    if status["Status"] != "FINISHED":
        error_msg = status.get("Error", "Unknown error")
        print("Query failed:", redshift.describe_statement(Id=statement_id))
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": "Query failed",
                "status": status["Status"],
                "details": error_msg
            })
        }

    # Obtiene los resultados
    result = redshift.get_statement_result(Id=statement_id)

    # Convierte a JSON limpio
    rows = []
    for record in result["Records"]:
        row = {}
        for i, col in enumerate(record):
            col_name = result["ColumnMetadata"][i]["name"]
            col_value = list(col.values())[0]  # extrae valor
            row[col_name] = col_value
        rows.append(row)

    return {
        "statusCode": 200,
        "body": json.dumps(rows)
    }
