import json
import os
import logging
from datetime import datetime
import xgboost as xgb
import numpy as np
import joblib

logger = logging.getLogger()
logger.setLevel(logging.INFO)

import json

def handler(event, context):
    """
    Lambda simple que retorna Hola Mundo
    """
    try:
        # Respuesta simple
        response = {
            "statusCode": 200,
            "headers": {
                "Content-Type": "application/json"
            },
            "body": json.dumps({
                "message": "¡Hola Mundo desde Lambda!",
                "success": True,
                "timestamp": "2024-01-25T06:30:00Z"
            })
        }
        
        return response
        
    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e),
                "success": False
            })
        }