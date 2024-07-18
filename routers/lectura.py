from fastapi import APIRouter, HTTPException, status, Depends, Query
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from database import database
from typing import List, Optional
from models import Lectura, DatosConsumoRequest
from routers.auth import get_current_user
import base64
import os
import datetime 

router = APIRouter()

@router.post("/sincronizar_lecturas/{login}")
async def sincronizar_lecturas(login: str, lecturas: List[Lectura], current_user: dict = Depends(get_current_user)):
    try:
        formatted_lecturas = []
        for lectura in lecturas:
            motivo = f"'{lectura.motivo}'" if lectura.motivo is not None else 'NULL'
            
            imagen_base64 = leer_y_convertir_imagen(lectura.imagen_ruta)
            if imagen_base64:
                imagen = f"decode('{imagen_base64}', 'base64')"
            else:
                imagen = 'NULL'
            
            fecha_actualizacion = f"'{lectura.fecha_actualizacion}'" if lectura.fecha_actualizacion is not None else 'NULL'
            
            formatted_lecturas.append(
                f"ROW('{lectura.numcuenta}', '{lectura.no_medidor}', '{lectura.clave}', '{lectura.lectura}', "
                f"'{lectura.observacion}', '{lectura.coordenadas}', {motivo}, {imagen}, {fecha_actualizacion})::tipo_lectura"
            )
        
        query = text(f"""
        DO $$
        DECLARE
            lecturas tipo_lectura[];
        BEGIN
            lecturas := ARRAY[{", ".join(formatted_lecturas)}];
            CALL SincronizarLecturasMasivas('{login}', lecturas);
        END $$;
        """)

        await database.execute(query)
        return {"mensaje": "Lecturas sincronizadas exitosamente"}
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error en la base de datos"
        ) from e


@router.post("/copiar_evidencia")
async def copiar_evidencia(current_user: dict = Depends(get_current_user)):
    try:
        query = text("SELECT copiar_registros_a_evidencia();")
        await database.execute(query)
        return {"mensaje": "Registros copiados a aapEvidencia exitosamente"}
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error en la base de datos"
        ) from e


@router.post("/actualizar_lecturas")
async def actualizar_lecturas(current_user: dict = Depends(get_current_user)):
    try:
        # Crear tablas temporales
        query_crear_tablas_temporales = text("SELECT crear_tablas_temporales();")
        await database.execute(query_crear_tablas_temporales)
        
        # Actualizar e insertar lecturas
        query_actualizar_insertar_lecturas = text("SELECT actualizar_insertar_lecturas();")
        await database.execute(query_actualizar_insertar_lecturas)
        
        return {"mensaje": "Lecturas actualizadas e insertadas exitosamente"}
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error en la base de datos"
        ) from e
    

@router.get("/lecturas")
async def obtener_datos_consumo(
    fecha_consulta: Optional[str] = Query(None, description="Fecha de consulta en formato 'YYYY-MM-DD'. Por defecto, se utiliza la fecha actual."),
    limite_registros: Optional[int] = Query(None, description="Número máximo de registros a devolver. Por defecto, no hay límite."),
    rango_unidades: Optional[float] = Query(2, description="Rango de unidades para calcular los límites superior e inferior del consumo promedio. Por defecto, se utiliza 2."),
    current_user: dict = Depends(get_current_user)
):
    try:
        # Convertir fecha_consulta a un objeto de fecha si no es None
        if fecha_consulta is not None:
            fecha_consulta = datetime.datetime.strptime(fecha_consulta, "%Y-%m-%d").date()

        # Preparar la consulta para llamar al procedimiento almacenado
        if fecha_consulta is None and limite_registros is None and rango_unidades == 2:
            query_str = "SELECT * FROM obtener_datos_consumo();"
            query = text(query_str)
        else:
            query_str = """
            SELECT * FROM obtener_datos_consumo(
                :fecha_consulta, 
                :limite_registros, 
                :rango_unidades
            );
            """
            query = text(query_str).bindparams(
                fecha_consulta=fecha_consulta,  
                limite_registros=limite_registros,
                rango_unidades=rango_unidades
            )
        
        # Imprimir la consulta y los valores para depuración
        print("Query:", query_str)
        print("Params:", {
            "fecha_consulta": fecha_consulta,
            "limite_registros": limite_registros,
            "rango_unidades": rango_unidades
        })

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

def leer_y_convertir_imagen(imagen_ruta):
    if imagen_ruta and os.path.isfile(imagen_ruta):
        with open(imagen_ruta, "rb") as image_file:
            return base64.b64encode(image_file.read()).decode('utf-8')
    return None