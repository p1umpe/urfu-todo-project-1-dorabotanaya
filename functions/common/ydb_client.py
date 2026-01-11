import os
import json
import ydb
import ydb.iam

_ydb_pool = None

def get_ydb_pool():
    global _ydb_pool
    if _ydb_pool is None:
        endpoint = os.environ['YDB_ENDPOINT']
        database = os.environ['YDB_DATABASE']
        creds = ydb.iam.MetadataUrlCredentials()
        driver = ydb.Driver(endpoint=endpoint, database=database, credentials=creds)
        driver.wait(fail_fast=True, timeout=5)
        _ydb_pool = ydb.SessionPool(driver, size=5)
    return _ydb_pool

CORS_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '3600'
}

def handle_options():
    return {
        'statusCode': 200,
        'body': '',
        'headers': {**CORS_HEADERS, 'Content-Type': 'application/json'}
    }

def json_response(status_code, body):
    return {
        'statusCode': status_code,
        'body': body if isinstance(body, str) else json.dumps(body, ensure_ascii=False),
        'headers': {**CORS_HEADERS, 'Content-Type': 'application/json'}
    }

def error_response(status_code, message):
    return {
        'statusCode': status_code,
        'body': json.dumps({'error': message}, ensure_ascii=False),
        'headers': {**CORS_HEADERS, 'Content-Type': 'application/json'}
    }