import json
from common.ydb_client import get_ydb_pool, handle_options, json_response, error_response

def handler(event, context):
    if event.get('httpMethod') == 'OPTIONS':
        return handle_options()
    
    try:
        print("=== DELETE TASK ===")
        
        # Получаем task_id из pathParams (как в update_task)
        task_id = None
        
        if event.get('pathParams') and 'taskId' in event['pathParams']:
            task_id = event['pathParams']['taskId']
            print(f"Got from pathParams: {task_id}")
        elif event.get('params') and 'taskId' in event['params']:
            task_id = event['params']['taskId']
            print(f"Got from params: {task_id}")
        elif event.get('pathParameters') and 'taskId' in event['pathParameters']:
            task_id = event['pathParameters']['taskId']
            print(f"Got from pathParameters: {task_id}")
        
        print(f"Task to delete: {task_id}")
        
        if not task_id:
            print(f"ERROR: No task_id found. Event keys: {list(event.keys())}")
            return error_response(400, 'Task ID is required in path')
        
        pool = get_ydb_pool()
        
        query = f'DELETE FROM tasks WHERE id = "{task_id}"'
        print(f"Delete query: {query}")
        
        def delete_task(session):
            session.transaction().execute(query, commit_tx=True)
            print("Delete successful")
        
        pool.retry_operation_sync(delete_task)
        
        return json_response(200, {
            'message': 'Task deleted successfully',
            'id': task_id
        })
        
    except Exception as e:
        import traceback
        print(f"Error in delete_task: {str(e)}")
        traceback.print_exc()
        return error_response(500, str(e))
