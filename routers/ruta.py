from fastapi import APIRouter, HTTPException, status, Depends
from sqlalchemy import text, bindparam
from sqlalchemy.exc import SQLAlchemyError
from database import database
from models import RutaLecturaMovilResult, Ruta, LectorRutaDetail, ActualizarLectorRuta
from routers.auth import get_current_user

router = APIRouter()

@router.get("/ruta_lectura/{login}", response_model=list[RutaLecturaMovilResult])
async def obtener_ruta_lectura(login: str, current_user: dict = Depends(get_current_user)):
    try:
        query = text("SELECT * FROM RutaLecturaMovil(:login)").bindparams(
            bindparam("login", login)
        )
        result = await database.fetch_all(query)
        if not result:
            raise HTTPException(status_code=404, detail="No se encontraron lecturas para este usuario")
        return result
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error en la base de datos"
        ) from e


@router.get("/obtenerRutas/")
async def obtener_rutas(current_user: dict = Depends(get_current_user)):
    try:
        query = text("SELECT * FROM ObtenerRutas()")
        result = await database.fetch_all(query)
        return result
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error en la base de datos"
        ) from e
    
@router.get("/lectorruta")
async def obtener_lectorruta(current_user: dict = Depends(get_current_user)):
    query = "SELECT * FROM obtener_datos_lectorruta();"
    results = await database.fetch_all(query)
    return results

@router.post("/asignarRuta/")
async def asignar_ruta_a_usuario(asignacion: Ruta, current_user: dict = Depends(get_current_user)):
    try:
        query = text("""
            SELECT AsignarRutaAUsuario(:username, :ruta_id) AS mensaje;
        """).bindparams(
            bindparam("ruta_id", asignacion.ruta_id),
            bindparam("username", asignacion.username)
        )
        
        result = await database.fetch_one(query)
        
        if result:
            return {"mensaje": result["mensaje"]}
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error al asignar la ruta"
            )

    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error en la base de datos"
        ) from e
    

@router.get("/lectorruta/{username}/{id_ruta}", response_model=LectorRutaDetail)
async def get_lectorruta(username: str, id_ruta: int, current_user: dict = Depends(get_current_user)):
    try:
        query = text("SELECT * FROM obtener_lectorruta(:username, :id_ruta)").bindparams(
            bindparam("username", username),
            bindparam("id_ruta", id_ruta)
        )
        result = await database.fetch_one(query)
        if not result:
            raise HTTPException(status_code=404, detail="Lector-Ruta no encontrado")
        return LectorRutaDetail(
            login_usuario=result["login_usuario"],
            nombre_usuario=result["nombre_usuario"],
            id_ruta=result["id_ruta"],
            nombre_ruta=result["nombre_ruta"]
        )
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error en la base de datos"
        ) from e
    


@router.delete("/lectorruta/{username}/{id_ruta}")
async def eliminar_lectorruta(username: str, id_ruta: int, current_user: dict = Depends(get_current_user)):
    try:
        query = text("SELECT eliminar_lectorruta(:username, :id_ruta)").bindparams(
            bindparam("username", username),
            bindparam("id_ruta", id_ruta)
        )
        await database.execute(query)
        return {"message": f"Lectorruta con login {username} y ID de ruta {id_ruta} eliminada"}
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))
    

@router.put("/lectorruta/{username}/{id_ruta}", response_model=dict)
async def actualizar_lectorruta(username: str, id_ruta: int, detalles: ActualizarLectorRuta, current_user: dict = Depends(get_current_user)):
    try:
        query = text("""
            SELECT actualizar_lectorruta(:username, :id_ruta, :new_username, :new_id_ruta) AS mensaje;
        """).bindparams(
            bindparam("username", username),
            bindparam("id_ruta", id_ruta),
            bindparam("new_username", detalles.new_username),
            bindparam("new_id_ruta", detalles.new_id_ruta)
        )
        
        result = await database.fetch_one(query)
        
        if result:
            return {"mensaje": result["mensaje"]}
        else:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error al actualizar el lector-ruta"
            )
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error en la base de datos"
        ) from e