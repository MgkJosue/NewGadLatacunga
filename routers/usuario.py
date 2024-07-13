from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy import text, bindparam
from sqlalchemy.exc import SQLAlchemyError
from database import database
from models import UsuarioRutaResult
from routers.auth import get_current_user

router = APIRouter()

@router.get("/usuario_ruta/{usuario_id}", response_model=list[UsuarioRutaResult])
async def obtener_ruta_usuario(usuario_id: int, current_user: dict = Depends(get_current_user)):
    try:
        query = text("SELECT * FROM UsuarioRuta(:usuario_id)").bindparams(
            bindparam("usuario_id", usuario_id)
        )
        result = await database.fetch_all(query)
        if not result:
            raise HTTPException(status_code=404, detail="No se encontraron rutas para este usuario")
        return result
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error en la base de datos"
        ) from e
    
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
