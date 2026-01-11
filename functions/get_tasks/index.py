import json
import datetime
from common.ydb_client import get_ydb_pool, handle_options, json_response, error_response

def handler(event, context):
    if event.get('httpMethod') == 'OPTIONS':
        return handle_options()
    
    try:
        query_params = event.get('queryStringParameters', {}) or {}
        status_filter = query_params.get('status', 'all')
        
        pool = get_ydb_pool()
        
        if status_filter in ['active', 'completed']:
            query = '''
            SELECT id, title, description, status, created_at, updated_at
            FROM tasks
            WHERE status = "{}"
            ORDER BY created_at DESC
            '''.format(status_filter)
        else:
            query = '''
            SELECT id, title, description, status, created_at, updated_at
            FROM tasks
            ORDER BY created_at DESC
            '''
        
        print(f"Query: {query[:100]}...")
        print(f"Status filter: {status_filter}")
        
        def execute_query(session):
            result = session.transaction().execute(query, commit_tx=True)
            tasks = []
            for row in result[0].rows:
                task = {
                    'id': row['id'],
                    'title': row['title'],
                    'description': row['description'],
                    'status': row['status'],
                    'created_at': row['created_at'].isoformat() if hasattr(row['created_at'], 'isoformat') else str(row['created_at']),
                    'updated_at': row['updated_at'].isoformat() if hasattr(row['updated_at'], 'isoformat') else str(row['updated_at'])
                }
                tasks.append(task)
            return tasks
        
        tasks = pool.retry_operation_sync(execute_query)
        
        print(f"Found {len(tasks)} tasks")
        return json_response(200, {'tasks': tasks})
        
    except Exception as e:
        import traceback
        print(f"Error in get_tasks: {str(e)}")
        traceback.print_exc()
        return error_response(500, str(e))
