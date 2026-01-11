import json
import uuid
import datetime
from common.ydb_client import get_ydb_pool, handle_options, json_response, error_response

def handler(event, context):
    if event.get('httpMethod') == 'OPTIONS':
        return handle_options()
    
    try:
        print("=== SIMPLE WORKING VERSION ===")
        body = json.loads(event['body'])
        title = body.get('title', '').strip()
        
        if not title:
            return error_response(400, 'Title is required')
        
        task_id = str(uuid.uuid4())
        now = datetime.datetime.now(datetime.timezone.utc)
        
        now_ydb = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        description = body.get('description', '').strip()
        
        print(f"Creating: {task_id}, {title}")
        print(f"YDB datetime format: {now_ydb}")
        
        pool = get_ydb_pool()
        
        query = f'''
        UPSERT INTO tasks (id, title, description, status, created_at, updated_at)
        VALUES ("{task_id}", "{title}", "{description}", "active", Datetime("{now_ydb}"), Datetime("{now_ydb}"))
        '''
        
        print(f"Query: {query[:150]}...")
        
        def execute_query(session):
            session.transaction().execute(query, commit_tx=True)
            print("SUCCESS: Task created!")
        
        pool.retry_operation_sync(execute_query)
        
        return json_response(201, {
            'id': task_id,
            'title': title,
            'description': description,
            'status': 'active',
            'created_at': now.isoformat(),
            'updated_at': now.isoformat()
        })
        
    except Exception as e:
        import traceback
        print(f"ERROR: {str(e)}")
        traceback.print_exc()
        return error_response(500, str(e))
