from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy import text, bindparam
from sqlalchemy.exc import SQLAlchemyError
from database import database
from models import UsuarioRutaResult
from routers.auth import get_current_user

router = APIRouter()

@router.get("/usuario_ruta/{usuario_id}", response_model=list[UsuarioRutaResult])
async def obtener_ruta_usuario(usuario_id: int, current_user: dict = Depends(get_current_user)):
    query = "SELECT * FROM UsuarioRuta(:usuario_id)"
    values = {"usuario_id": int(usuario_id)}  # Asegurando que el valor se pase como string
    
    try:
        # Ejecuta la consulta pasando el parámetro correctamente
        result = await database.fetch_all(query=query, values=values)
        if not result:
            raise HTTPException(status_code=404, detail="No se encontraron rutas para este usuario")
        return result
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=500, detail="Error en la base de datos"
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=str(e)
        )
    
@router.get("/obtenerUsuarios/")
async def obtener_usuarios(current_user: dict = Depends(get_current_user)):
    try:
        query = text("SELECT * FROM ObtenerUsuarios()")
        result = await database.fetch_all(query)
        return result
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error en la base de datos"
        ) from e
