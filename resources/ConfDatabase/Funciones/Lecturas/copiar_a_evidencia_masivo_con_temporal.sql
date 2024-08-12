CREATE OR REPLACE FUNCTION copiar_a_evidencia_masivo_con_temporal(p_procesado_por VARCHAR)
RETURNS TABLE(cuenta_result VARCHAR, medidor_result VARCHAR, accion_result VARCHAR, resultado_bool BOOLEAN, mensaje VARCHAR) AS $$
DECLARE
    v_registro RECORD;
    v_cuenta VARCHAR;
    v_medidor VARCHAR;
    v_accion VARCHAR;
    v_ultima_fecha_registro TIMESTAMP;
    v_nueva_fecha_registro TIMESTAMP;
    v_registros_copiados INTEGER := 0;
    v_mensaje VARCHAR;
BEGIN
    -- Crear una tabla temporal para almacenar los resultados
    CREATE TEMPORARY TABLE IF NOT EXISTS resultado_temp (
        cuenta_temp VARCHAR,
        medidor_temp VARCHAR,
        accion_temp VARCHAR,
        resultado_temp BOOLEAN,
        mensaje_temp VARCHAR
    ) ON COMMIT DROP;

    -- Verificar si aappMovilLectura está vacía
    IF NOT EXISTS (SELECT 1 FROM aappMovilLectura LIMIT 1) THEN
        v_mensaje := 'La tabla aappMovilLectura está vacía. No hay datos para procesar.';
        INSERT INTO resultado_temp VALUES (NULL, NULL, 'NO_ACTION', FALSE, v_mensaje);
        RETURN QUERY SELECT * FROM resultado_temp;
        RETURN;
    END IF;

    -- Obtener la última fecha de registro en aappEvidencia
    SELECT MAX(fecha_hora_registro) INTO v_ultima_fecha_registro FROM aappEvidencia;

    -- Obtener la nueva fecha de registro de aappMovilLectura
    SELECT MAX(fecha_hora_registro) INTO v_nueva_fecha_registro FROM aappMovilLectura;

    -- Si la fecha de registro es diferente o no hay registros previos, actualizar o insertar todos los datos
    IF v_ultima_fecha_registro IS NULL OR v_ultima_fecha_registro < v_nueva_fecha_registro THEN
        FOR v_registro IN SELECT * FROM aappMovilLectura LOOP
            INSERT INTO aappEvidencia (
                cuenta, medidor, clave, abonado, lectura, observacion, 
                coordenadasXYZ, direccion, motivo, imagen, 
                fecha_hora_registro, fecha_hora_edicion, modificado_por,
                procesado_por, fecha_de_procesamiento, accion
            ) VALUES (
                v_registro.cuenta, v_registro.medidor, v_registro.clave, 
                v_registro.abonado, v_registro.lectura, v_registro.observacion, 
                v_registro.coordenadasXYZ, v_registro.direccion, v_registro.motivo, 
                v_registro.imagen, v_registro.fecha_hora_registro, 
                v_registro.fecha_hora_edicion, v_registro.modificado_por,
                p_procesado_por, CURRENT_TIMESTAMP, 'PROCESADO'
            )
            ON CONFLICT (cuenta, medidor) DO UPDATE SET
                clave = EXCLUDED.clave,
                abonado = EXCLUDED.abonado,
                lectura = EXCLUDED.lectura,
                observacion = EXCLUDED.observacion,
                coordenadasXYZ = EXCLUDED.coordenadasXYZ,
                direccion = EXCLUDED.direccion,
                motivo = EXCLUDED.motivo,
                imagen = EXCLUDED.imagen,
                fecha_hora_registro = EXCLUDED.fecha_hora_registro,
                fecha_hora_edicion = EXCLUDED.fecha_hora_edicion,
                modificado_por = EXCLUDED.modificado_por,
                procesado_por = EXCLUDED.procesado_por,
                fecha_de_procesamiento = EXCLUDED.fecha_de_procesamiento,
                accion = EXCLUDED.accion;

            -- Insertar resultado en la tabla temporal
            INSERT INTO resultado_temp (cuenta_temp, medidor_temp, accion_temp, resultado_temp, mensaje_temp)
            VALUES (v_registro.cuenta, v_registro.medidor, 'PROCESADO', TRUE, 'Registro procesado con éxito');
            
            v_registros_copiados := v_registros_copiados + 1;
        END LOOP;

        -- Si se copiaron registros con éxito, eliminar los datos de aappMovilLectura
        IF v_registros_copiados > 0 THEN
            DELETE FROM aappMovilLectura;
            v_mensaje := 'Se eliminaron ' || v_registros_copiados || ' registros de aappMovilLectura';
            INSERT INTO resultado_temp VALUES (NULL, NULL, 'ELIMINAR', TRUE, v_mensaje);
        END IF;
    ELSE
        -- Verificar si temp_cambios_lectura está vacía
        IF NOT EXISTS (SELECT 1 FROM temp_cambios_lectura LIMIT 1) THEN
            v_mensaje := 'La tabla temp_cambios_lectura está vacía. No hay cambios para procesar.';
            INSERT INTO resultado_temp VALUES (NULL, NULL, 'NO_ACTION', FALSE, v_mensaje);
            RETURN QUERY SELECT * FROM resultado_temp;
            RETURN;
        END IF;

        -- Procesar solo los cambios de temp_cambios_lectura
        FOR v_registro IN SELECT * FROM temp_cambios_lectura LOOP
            v_cuenta := v_registro.cuenta;
            v_medidor := v_registro.medidor;
            v_accion := v_registro.accion;

            -- Insertar o actualizar en aappEvidencia
            INSERT INTO aappEvidencia (
                cuenta, medidor, clave, abonado, lectura, observacion, 
                coordenadasXYZ, direccion, motivo, imagen, 
                fecha_hora_registro, fecha_hora_edicion, modificado_por,
                procesado_por, fecha_de_procesamiento, accion
            ) VALUES (
                v_cuenta,
                v_medidor,
                v_registro.datos->>'clave',
                v_registro.datos->>'abonado',
                (v_registro.datos->>'lectura')::NUMERIC,
                v_registro.datos->>'observacion',
                v_registro.datos->>'coordenadasXYZ',
                v_registro.datos->>'direccion',
                v_registro.datos->>'motivo',
                CASE 
                    WHEN v_registro.datos->>'imagen' IS NULL THEN NULL
                    ELSE decode(v_registro.datos->>'imagen', 'base64')::bytea
                END,
                (v_registro.datos->>'fecha_hora_registro')::TIMESTAMP,
                v_registro.fecha_modificacion,
                v_registro.modificado_por,
                p_procesado_por,
                CURRENT_TIMESTAMP,
                v_accion
            )
            ON CONFLICT (cuenta, medidor) DO UPDATE SET
                lectura = EXCLUDED.lectura,
                observacion = EXCLUDED.observacion,
                motivo = EXCLUDED.motivo,
                fecha_hora_edicion = EXCLUDED.fecha_hora_edicion,
                modificado_por = EXCLUDED.modificado_por,
                procesado_por = EXCLUDED.procesado_por,
                fecha_de_procesamiento = EXCLUDED.fecha_de_procesamiento,
                accion = EXCLUDED.accion;

            -- Insertar resultado en la tabla temporal
            INSERT INTO resultado_temp (cuenta_temp, medidor_temp, accion_temp, resultado_temp, mensaje_temp)
            VALUES (v_cuenta, v_medidor, v_accion, TRUE, 'Cambio procesado con éxito');
            
            v_registros_copiados := v_registros_copiados + 1;
        END LOOP;

        -- Si se procesaron registros con éxito, eliminar los datos procesados de aappMovilLectura
        IF v_registros_copiados > 0 THEN
            DELETE FROM aappMovilLectura
            WHERE (cuenta, medidor) IN (SELECT cuenta, medidor FROM temp_cambios_lectura);
            v_mensaje := 'Se eliminaron ' || v_registros_copiados || ' registros de aappMovilLectura';
            INSERT INTO resultado_temp VALUES (NULL, NULL, 'ELIMINAR', TRUE, v_mensaje);
        END IF;
    END IF;

    -- Limpiar la tabla temporal después de procesar todos los cambios
    TRUNCATE TABLE temp_cambios_lectura;

    -- Si no se procesaron registros, agregar un mensaje de resumen
    IF v_registros_copiados = 0 THEN
        v_mensaje := 'No se procesaron registros.';
        INSERT INTO resultado_temp VALUES (NULL, NULL, 'RESUMEN', FALSE, v_mensaje);
    ELSE
        v_mensaje := 'Se procesaron ' || v_registros_copiados || ' registros en total.';
        INSERT INTO resultado_temp VALUES (NULL, NULL, 'RESUMEN', TRUE, v_mensaje);
    END IF;

    -- Retornar los resultados
    RETURN QUERY 
    SELECT 
        cuenta_temp AS cuenta_result, 
        medidor_temp AS medidor_result, 
        accion_temp AS accion_result, 
        resultado_temp AS resultado_bool,
        mensaje_temp AS mensaje
    FROM resultado_temp;
END;
$$ LANGUAGE plpgsql;