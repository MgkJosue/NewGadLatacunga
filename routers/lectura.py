from fastapi import APIRouter, HTTPException, status, Depends, Query
from sqlalchemy import text, bindparam
from sqlalchemy.exc import SQLAlchemyError
from database import database
from typing import List, Optional
from models import Lectura, LecturaRequest, WebLecturaRequest
from routers.auth import get_current_user
import base64
import os
import datetime 
from asyncpg.exceptions import RaiseError, PostgresError

router = APIRouter()

@router.post("/sincronizar_lecturas/{login}")
async def sincronizar_lecturas(
    login: str, 
    lecturas: List[Lectura], 
    current_user: dict = Depends(get_current_user)
):
    try:
        formatted_lecturas = []
        for lectura in lecturas:
            motivo = f"'{lectura.motivo}'" if lectura.motivo is not None else 'NULL'
            
            imagen = f"decode('{lectura.imagen_ruta}', 'base64')" if lectura.imagen_ruta else 'NULL'
            
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


@router.post("/lecturas/copiar-evidencias")
async def copiar_evidencias(current_user: dict = Depends(get_current_user)):
    try:
        query = text("SELECT * FROM copiar_a_evidencia_masivo_con_temporal(:procesado_por);").bindparams(
            procesado_por=current_user['username']
        )
        results = await database.fetch_all(query)

        if not results:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="No se obtuvieron resultados del procedimiento almacenado"
            )

        return {"mensaje": "Registros copiados a aappEvidencia exitosamente", "resultados": results}
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error en la base de datos: " + str(e)
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
    limite_promedio: Optional[int] = Query(3, description="Número máximo de registros a considerar para calcular el promedio. Por defecto, se utiliza 3."),
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
            :limite_registros, 
            :rango_unidades,
            :limite_promedio
        );
        """
        query = text(query_str).bindparams(
            fecha_consulta=fecha_consulta,  
            limite_registros=limite_registros,
            rango_unidades=rango_unidades,
            limite_promedio=limite_promedio
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

@router.put("/lecturas/{cuenta}")
async def editar_lectura_movil(
    cuenta: str, 
    lectura: LecturaRequest, 
    current_user: dict = Depends(get_current_user)
):
    try:
        if not cuenta.strip() or not lectura.nueva_lectura.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La cuenta y la nueva lectura no pueden estar vacías"
            )

        query = text("""
            SELECT editar_lectura_movil(:cuenta, :nueva_lectura, :nueva_observacion, :nuevo_motivo, :modificado_por);
        """).bindparams(
            cuenta=cuenta,
            nueva_lectura=lectura.nueva_lectura,
            nueva_observacion=lectura.nueva_observacion,
            nuevo_motivo=lectura.nuevo_motivo,
            modificado_por=current_user['username']  
        )

        result = await database.fetch_one(query)

        
        if result is None or not result[0]:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No se pudo actualizar la lectura móvil"
            )

        return {"mensaje": "Lectura móvil actualizada correctamente"}
    
    except RaiseError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        ) from e
    
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error en la base de datos: " + str(e)
        ) from e

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error desconocido: " + str(e)
        ) from e

@router.delete("/lecturas/{cuenta}")
async def eliminar_lectura_movil(
    cuenta: str, 
    current_user: dict = Depends(get_current_user)
):
    try:
        # Mejorar la validación de entrada
        if not cuenta.strip():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La cuenta es requerida y no puede estar vacía"
            )

        query = text("""
            SELECT eliminar_lectura_movil(:cuenta, :modificado_por);
        """).bindparams(
            cuenta=cuenta,
            modificado_por=current_user['username']  # O el campo apropiado que identifique al usuario
        )

        result = await database.fetch_one(query)

        # Manejar el resultado de la función más detalladamente
        if result is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="No se obtuvo respuesta de la base de datos"
            )
        if not result[0]:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No se encontró una lectura móvil para la cuenta especificada o no se pudo eliminar"
            )

        return {"mensaje": "Lectura móvil eliminada correctamente"}
    
    except PostgresError as e:
        # Capturar errores específicos del procedimiento almacenado
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(e)
        ) from e
    
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error en la base de datos: " + str(e)
        ) from e

    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error desconocido: " + str(e)
        ) from e


@router.get("/lecturas/{cuenta}", response_model=dict)
async def obtener_lectura_por_cuenta(cuenta: str, current_user: dict = Depends(get_current_user)):
    try:
        query = text("""
            SELECT * FROM obtener_datos_por_cuenta(:cuenta);
        """).bindparams(
            bindparam("cuenta", cuenta)
        )
        
        result = await database.fetch_one(query)
        
        if result:
            # Convertir el resultado a un diccionario y convertir el campo imagen a base64
            row_dict = dict(result)
            if 'imagen' in row_dict and row_dict['imagen'] is not None:
                row_dict['imagen'] = base64.b64encode(row_dict['imagen']).decode('utf-8')
            return row_dict
        else:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="No se encontró la lectura para la cuenta especificada"
            )
    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Error en la base de datos: " + str(e)
        ) from e


@router.post("/movil-lectura", response_model=dict)
async def movil_lectura(
    lectura_data: WebLecturaRequest, 
    current_user: dict = Depends(get_current_user)
):
    try:
        if not lectura_data.cuenta or not lectura_data.lectura or not lectura_data.observacion:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Faltan parámetros requeridos: cuenta, lectura y observacion son obligatorios"
            )

        query = text("""
            SELECT llenar_aappMovilLectura(:cuenta, :lectura, :observacion);
        """).bindparams(
            cuenta=lectura_data.cuenta,
            lectura=lectura_data.lectura,
            observacion=lectura_data.observacion
        )

        result = await database.fetch_one(query)

        if result is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="No se obtuvo respuesta de la base de datos"
            )

        mensaje = result[0]

        if "ya existe" in mensaje:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=mensaje
            )
        elif "no existe" in mensaje:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=mensaje
            )
        elif "No se encontraron todos los datos" in mensaje:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=mensaje
            )

        return {"mensaje": mensaje}

    except SQLAlchemyError as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Error en la base de datos: " + str(e)
        ) from e
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Error: " + str(e)
        ) from e