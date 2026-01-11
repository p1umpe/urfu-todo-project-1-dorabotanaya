import json
import datetime
from common.ydb_client import get_ydb_pool, handle_options, json_response, error_response

def handler(event, context):
    if event.get('httpMethod') == 'OPTIONS':
        return handle_options()
    
    try:
        print("=== UPDATE FIXED ===")
        
        task_id = None
        
        if event.get('pathParams') and 'taskId' in event['pathParams']:
            task_id = event['pathParams']['taskId']
            print(f"Got task_id from pathParams: {task_id}")
        
        if not task_id and event.get('params') and 'taskId' in event['params']:
            task_id = event['params']['taskId']
            print(f"Got task_id from params: {task_id}")
        
        if not task_id and event.get('pathParameters') and 'taskId' in event['pathParameters']:
            task_id = event['pathParameters']['taskId']
            print(f"Got task_id from pathParameters: {task_id}")
        
        print(f"Final task_id: {task_id}")
        
        if not task_id:
            print(f"ERROR: No task_id found. Available keys: {list(event.keys())}")
            return error_response(400, 'Task ID is required in path')
        
        body = json.loads(event['body'])
        print(f"Body: {body}")
        
        title = body.get('title')
        description = body.get('description')
        status = body.get('status')
        
        if title is None and description is None and status is None:
            return error_response(400, 'No fields to update')
        
        if status is not None and status not in ['active', 'completed']:
            return error_response(400, 'Status must be "active" or "completed"')
        
        pool = get_ydb_pool()
        
        now = datetime.datetime.now(datetime.timezone.utc)
        now_ydb = now.strftime("%Y-%m-%dT%H:%M:%SZ")
        
        updates = []
        
        if title is not None:
            updates.append(f'title = "{title}"')
        
        if description is not None:
            updates.append(f'description = "{description}"')
        
        if status is not None:
            updates.append(f'status = "{status}"')
        
        updates.append(f'updated_at = Datetime("{now_ydb}")')
        
        query = f'''
        UPDATE tasks
        SET {', '.join(updates)}
        WHERE id = "{task_id}"
        '''
        
        print(f"Query: {query}")
        
        def update_task(session):
            session.transaction().execute(query, commit_tx=True)
            print("Update successful")
        
        pool.retry_operation_sync(update_task)
        
        return json_response(200, {
            'id': task_id,
            'updated_at': now.isoformat(),
            'message': 'Task updated successfully'
        })
        
    except Exception as e:
        import traceback
        print(f"Error: {str(e)}")
        traceback.print_exc()
        return error_response(500, str(e))
