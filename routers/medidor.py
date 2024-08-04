from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from database import database
from routers.auth import get_current_user

router = APIRouter()

@router.get("/obtener_datos_medidor/{cuenta}")
async def obtener_datos_medidor(cuenta: str, current_user: dict = Depends(get_current_user)):
    try:
        # Preparar la consulta para llamar al procedimiento almacenado
        query_str = """
        SELECT * FROM obtener_datos_medidor(:cuenta_param);
        """
        query = text(query_str).bindparams(
            cuenta_param=cuenta
        )
        # Ejecutar la consulta
        result = await database.fetch_one(query)
        
        if not result:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontraron registros para la cuenta proporcionada.")
        
        # Convertir resultado a un diccionario
        result_dict = dict(result)
        
        return result_dict
    except SQLAlchemyError as e:
        print("SQLAlchemyError:", str(e))
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error en la base de datos: " + str(e)
        ) from e
    except Exception as e:
        print("Exception:", str(e))
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Error: " + str(e)
        ) from e
