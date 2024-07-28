CREATE OR REPLACE FUNCTION copiar_a_evidencia_masivo_con_temporal(p_procesado_por VARCHAR)
RETURNS TABLE(cuenta_result VARCHAR, medidor_result VARCHAR, accion_result VARCHAR, resultado_bool BOOLEAN) AS $$
DECLARE
    v_registro RECORD;
    v_cuenta VARCHAR;
    v_medidor VARCHAR;
    v_accion VARCHAR;
    v_ultima_fecha_registro TIMESTAMP;
    v_nueva_fecha_registro TIMESTAMP;
BEGIN
    -- Crear una tabla temporal para almacenar los resultados
    CREATE TEMPORARY TABLE IF NOT EXISTS resultado_temp (
        cuenta_temp VARCHAR,
        medidor_temp VARCHAR,
        accion_temp VARCHAR,
        resultado_temp BOOLEAN
    ) ON COMMIT DROP;

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
                p_procesado_por, CURRENT_TIMESTAMP, 'COPIAR'
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
            INSERT INTO resultado_temp (cuenta_temp, medidor_temp, accion_temp, resultado_temp)
            VALUES (v_registro.cuenta, v_registro.medidor, 'COPIAR', TRUE);
        END LOOP;
    ELSE
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
                v_registro.datos->>'lectura',
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
            INSERT INTO resultado_temp (cuenta_temp, medidor_temp, accion_temp, resultado_temp)
            VALUES (v_cuenta, v_medidor, v_accion, TRUE);
        END LOOP;
    END IF;

    -- Limpiar la tabla temporal después de procesar todos los cambios
    TRUNCATE TABLE temp_cambios_lectura;

    -- Retornar los resultados
    RETURN QUERY 
    SELECT 
        cuenta_temp AS cuenta_result, 
        medidor_temp AS medidor_result, 
        accion_temp AS accion_result, 
        resultado_temp AS resultado_bool 
    FROM resultado_temp;
END;
$$ LANGUAGE plpgsql;
