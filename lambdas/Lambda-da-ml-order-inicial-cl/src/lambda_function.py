import json
import os
import logging
from datetime import datetime
import xgboost as xgb
import numpy as np
import joblib

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    """
    Lambda de prueba para validar despliegues
    """
    try:
        logger.info(f"Event received: {json.dumps(event)}")
        
        # Información de la función
        function_info = {
            "function_name": context.function_name,
            "function_version": context.function_version,
            "memory_limit": context.memory_limit_in_mb,
            "remaining_time": context.get_remaining_time_in_millis(),
            "aws_request_id": context.aws_request_id
        }
        
        # Información del entorno
        env_vars = {
            "stage": os.getenv("STAGE", "dev"),
            "region": os.getenv("AWS_REGION", "unknown"),
            "deployment_id": os.getenv("DEPLOYMENT_ID", "unknown")
        }
        
        # Información del sistema
        system_info = {
            "timestamp": datetime.utcnow().isoformat(),
            "python_version": os.sys.version,
            "environment_variables": dict(os.environ)
        }
        
        response = {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": json.dumps({
                "message": "Test Lambda funcionando correctamente",
                "function_info": function_info,
                "environment": env_vars,
                "system_info": system_info,
                "event_received": event,
                "success": True
            })
        }
        
        logger.info(f"Response: {json.dumps(response)}")
        return response
        
    except Exception as e:
        logger.error(f"Error en test-lambda: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e),
                "success": False
            })
        }