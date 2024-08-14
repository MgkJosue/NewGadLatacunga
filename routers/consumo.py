from fastapi import APIRouter, HTTPException, status, Depends, Query
from sqlalchemy import text, bindparam
from sqlalchemy.exc import SQLAlchemyError
from database import database
from typing import  Optional
from routers.auth import get_current_user
import base64
import datetime 


router = APIRouter()

@router.post("/parametros-consumo")
async def actualizar_parametros_consumo(
    limite_promedio: int = Query(..., gt=0, description="Nuevo límite de promedio"),
    rango_unidades: float = Query(..., gt=0, description="Nuevo rango de unidades"),
    current_user: dict = Depends(get_current_user)
):
    try:
        query = text("SELECT actualizar_parametros_consumo(:limite_promedio, :rango_unidades)").bindparams(
            bindparam("limite_promedio", value=limite_promedio),
            bindparam("rango_unidades", value=rango_unidades)
        )
        await database.execute(query)
        return {"message": "Parámetros de consumo actualizados correctamente"}
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
@router.get("/parametros-consumo")
async def obtener_parametros_consumo(
    current_user: dict = Depends(get_current_user)
):
    try:
        query = text("""
            SELECT limite_promedio, rango_unidades
            FROM parametros_consumo
            ORDER BY fecha_actualizacion DESC
            LIMIT 1
        """)
        result = await database.fetch_one(query)
        
        if not result:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontraron parámetros de consumo.")
        
        return {
            "limite_promedio": result['limite_promedio'],
            "rango_unidades": float(result['rango_unidades'])
        }
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
    
@router.get("/lecturas")
async def obtener_datos_consumo(
    fecha_consulta: Optional[str] = Query(None, description="Fecha de consulta en formato 'YYYY-MM-DD'. Por defecto, se utiliza la fecha actual."),
    limite_registros: Optional[int] = Query(None, description="Número máximo de registros a devolver. Por defecto, no hay límite."),
    current_user: dict = Depends(get_current_user)
):
    try:
        # Si fecha_consulta es None, usar la fecha actual
        if fecha_consulta is None:
            fecha_consulta = datetime.date.today()
        else:
            fecha_consulta = datetime.datetime.strptime(fecha_consulta, "%Y-%m-%d").date()

        # Preparar la consulta para llamar al procedimiento almacenado
        query_str = """
        SELECT * FROM obtener_datos_consumo(
            :fecha_consulta, 
            :limite_registros
        );
        """
        query = text(query_str).bindparams(
            fecha_consulta=fecha_consulta,  
            limite_registros=limite_registros
        )   
        result = await database.fetch_all(query)
        
        if not result:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No se encontraron registros.")
        
        # Convertir resultados a una lista de diccionarios y convertir datos binarios a base64
        result_dicts = []
        for row in result:
            row_dict = dict(row)
            if 'imagen' in row_dict and row_dict['imagen'] is not None:
                row_dict['imagen'] = base64.b64encode(row_dict['imagen']).decode('utf-8')
            result_dicts.append(row_dict)
        
        return result_dicts
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