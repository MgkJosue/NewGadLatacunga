CREATE OR REPLACE FUNCTION copiar_a_evidencia_masivo_con_temporal(p_procesado_por VARCHAR)
RETURNS TABLE(cuenta_result VARCHAR, medidor_result VARCHAR, accion_result VARCHAR, resultado_bool BOOLEAN) AS $$
DECLARE
    v_registro RECORD;
    v_cuenta VARCHAR;
    v_medidor VARCHAR;
    v_accion VARCHAR;
    v_ultima_fecha_registro TIMESTAMP;
    v_nueva_fecha_registro TIMESTAMP;
    v_registros_copiados INTEGER := 0;
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
            
            v_registros_copiados := v_registros_copiados + 1;
        END LOOP;

        -- Si se copiaron registros con éxito, eliminar los datos de aappMovilLectura
        IF v_registros_copiados > 0 THEN
            DELETE FROM aappMovilLectura;
            RAISE NOTICE 'Se eliminaron % registros de aappMovilLectura', v_registros_copiados;
        END IF;
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
            
            v_registros_copiados := v_registros_copiados + 1;
        END LOOP;

        -- Si se copiaron registros con éxito, eliminar los datos procesados de aappMovilLectura
        IF v_registros_copiados > 0 THEN
            DELETE FROM aappMovilLectura
            WHERE (cuenta, medidor) IN (SELECT cuenta, medidor FROM temp_cambios_lectura);
            RAISE NOTICE 'Se eliminaron % registros de aappMovilLectura', v_registros_copiados;
        END IF;
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


-- Función para Validar Usuario
CREATE OR REPLACE FUNCTION validar_usuario(
    p_login VARCHAR(255),
    p_clave VARCHAR(255)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_clave_almacenada VARCHAR(255);
BEGIN
    -- Obtener la clave del usuario
    SELECT clave INTO v_clave_almacenada
    FROM csebase1
    WHERE login = p_login;

    IF v_clave_almacenada IS NULL THEN
        RETURN FALSE;    -- Devolvemos FALSE si no se encuentra el usuario
    ELSIF v_clave_almacenada = p_clave THEN
        RETURN TRUE;     -- Devolvemos TRUE si la clave es correcta
    ELSE
        RETURN FALSE;    -- Devolvemos FALSE si la clave es incorrecta
    END IF;
END;
$$ LANGUAGE plpgsql;


-- Crear tablas temporales
CREATE OR REPLACE FUNCTION crear_tablas_temporales()
RETURNS void AS $$
BEGIN
    -- Crear la tabla temporal para registros que necesitan actualización
    CREATE TEMP TABLE temp_actualizar AS
    SELECT DISTINCT aml.*
    FROM aappMovilLectura aml
    INNER JOIN aapplectura al ON aml.cuenta = al.numcuenta
    WHERE EXTRACT(MONTH FROM CURRENT_DATE) = al.mes
      AND EXTRACT(YEAR FROM CURRENT_DATE) = al.anio;

    -- Crear la tabla temporal para registros que necesitan inserción
    CREATE TEMP TABLE temp_insertar AS
    SELECT DISTINCT aml.*
    FROM aappMovilLectura aml
    WHERE NOT EXISTS (
        SELECT 1
        FROM aapplectura al
        WHERE aml.cuenta = al.numcuenta
          AND EXTRACT(MONTH FROM CURRENT_DATE) = al.mes
          AND EXTRACT(YEAR FROM CURRENT_DATE) = al.anio
    );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION editar_lectura_movil(
	p_cuenta VARCHAR,
	p_nueva_lectura VARCHAR,
	p_nueva_observacion TEXT DEFAULT NULL,
	p_nuevo_motivo TEXT DEFAULT NULL,
	p_modificado_por VARCHAR DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
	v_updated INTEGER;
	v_datos JSONB;
	v_medidor VARCHAR;
	v_coordenadas_originales VARCHAR;
BEGIN
	-- Validaciones
	IF p_cuenta IS NULL OR p_nueva_lectura IS NULL THEN
    	RAISE EXCEPTION 'La cuenta y la nueva lectura no pueden ser nulas';
	END IF;
    
	IF p_nueva_lectura ~ '^-?\d+(\.\d+)?$' THEN
    	IF CAST(p_nueva_lectura AS NUMERIC) < 0 THEN
        	RAISE EXCEPTION 'La lectura no puede ser negativa';
    	END IF;
	ELSE
    	RAISE EXCEPTION 'La lectura debe ser un número válido';
	END IF;

	-- Obtener datos anteriores, el medidor y las coordenadas
	SELECT jsonb_build_object(
    	'cuenta', cuenta,
    	'medidor', medidor,
    	'clave', clave,
    	'abonado', abonado,
    	'lectura', lectura,
    	'observacion', observacion,
    	'coordenadasXYZ', coordenadasXYZ,
    	'direccion', direccion,
    	'motivo', motivo,
    	'imagen', encode(imagen, 'base64'),
    	'fecha_hora_registro', fecha_hora_registro,
    	'fecha_hora_edicion', fecha_hora_edicion,
    	'modificado_por', modificado_por
	), medidor, coordenadasXYZ
	INTO v_datos, v_medidor, v_coordenadas_originales
	FROM aappMovilLectura
	WHERE cuenta = p_cuenta;
    
	IF v_datos IS NULL THEN
    	RAISE EXCEPTION 'No se encontró la lectura para la cuenta especificada';
	END IF;
    
	-- Actualizar la lectura
	UPDATE aappMovilLectura
	SET lectura = p_nueva_lectura,
    	observacion = COALESCE(p_nueva_observacion, observacion),
    	motivo = COALESCE(p_nuevo_motivo, motivo),
    	fecha_hora_edicion = CURRENT_TIMESTAMP,
    	modificado_por = COALESCE(p_modificado_por, modificado_por)
	WHERE cuenta = p_cuenta;
    
	GET DIAGNOSTICS v_updated = ROW_COUNT;
    
	IF v_updated = 1 THEN
    	-- Asegurarse de que las coordenadas se almacenen como VARCHAR en el JSON
    	v_datos = jsonb_set(v_datos, '{coordenadasXYZ}', to_jsonb(v_coordenadas_originales::VARCHAR));
   	 
    	-- Insertar en tabla temporal
    	INSERT INTO temp_cambios_lectura (cuenta, medidor, accion, datos, modificado_por)
    	VALUES (p_cuenta, v_medidor, 'EDITAR', v_datos, COALESCE(p_modificado_por, 'Sistema'));
   	 
    	RETURN TRUE;
	ELSE
    	RETURN FALSE;
	END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION eliminar_lectura_movil(
    p_cuenta VARCHAR,
    p_modificado_por VARCHAR
) RETURNS BOOLEAN AS $$
DECLARE
    v_deleted INTEGER;
    v_datos JSONB;
    v_medidor VARCHAR;
BEGIN
    -- Asegurarse de que la tabla temp_cambios_lectura existe
    CREATE TABLE IF NOT EXISTS temp_cambios_lectura (
        id SERIAL PRIMARY KEY,
        cuenta VARCHAR(20),
        medidor VARCHAR(20),
        accion VARCHAR(20),
        datos JSONB,
        modificado_por VARCHAR(50),
        fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

    -- Obtener datos antes de eliminar
    SELECT jsonb_build_object(
        'cuenta', cuenta,
        'medidor', medidor,
        'clave', clave,
        'abonado', abonado,
        'lectura', lectura,
        'observacion', observacion,
        'coordenadasXYZ', coordenadasXYZ,
        'direccion', direccion,
        'motivo', motivo,
        'imagen', encode(imagen, 'base64'),
        'fecha_hora_registro', fecha_hora_registro,
        'fecha_hora_edicion', fecha_hora_edicion,
        'modificado_por', modificado_por
    ), medidor
    INTO v_datos, v_medidor
    FROM aappMovilLectura
    WHERE cuenta = p_cuenta;

    IF v_datos IS NULL THEN
        RAISE EXCEPTION 'No se encontró la lectura para la cuenta especificada';
    END IF;

    -- Eliminar la lectura
    DELETE FROM aappMovilLectura
    WHERE cuenta = p_cuenta;
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    IF v_deleted > 0 THEN
        -- Asegurarse de que las coordenadas se almacenen como VARCHAR en el JSON
        v_datos = jsonb_set(v_datos, '{coordenadasXYZ}', to_jsonb(v_datos->>'coordenadasXYZ'::VARCHAR));
        
        -- Insertar en tabla temporal
        INSERT INTO temp_cambios_lectura (cuenta, medidor, accion, datos, modificado_por, fecha_modificacion)
        VALUES (p_cuenta, v_medidor, 'ELIMINAR', v_datos, p_modificado_por, CURRENT_TIMESTAMP);
        
        RETURN TRUE;
    ELSE
        RETURN FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Actualizar e insertar lecturas en la tabla aapplectura desde las tablas temporales
CREATE OR REPLACE FUNCTION actualizar_insertar_lecturas()
RETURNS void AS $$
DECLARE
    max_id INTEGER;
BEGIN
    -- Ajustar la secuencia del id para evitar duplicados
    SELECT MAX(id) INTO max_id FROM aapplectura;
    IF max_id IS NOT NULL THEN
        PERFORM setval('aapplectura_id_seq', max_id);
    END IF;

    -- Actualizar registros existentes en aapplectura usando la tabla temporal temp_actualizar
    UPDATE aapplectura al
    SET
        lectura = tmp.lectura::INTEGER,
        observacion = tmp.observacion,
        nromedidor = tmp.medidor,
        lecturaanterior = COALESCE(
            (SELECT al_prev.lectura
             FROM aapplectura al_prev
             WHERE al_prev.numcuenta = tmp.cuenta
               AND al_prev.nromedidor = tmp.medidor
               AND (al_prev.anio < EXTRACT(YEAR FROM CURRENT_DATE)
                   OR (al_prev.anio = EXTRACT(YEAR FROM CURRENT_DATE)
                       AND al_prev.mes < EXTRACT(MONTH FROM CURRENT_DATE)))
             ORDER BY al_prev.anio DESC, al_prev.mes DESC
             LIMIT 1),
            0
        ),
        consumo = GREATEST(tmp.lectura::INTEGER - COALESCE(
            (SELECT al_prev.lectura
             FROM aapplectura al_prev
             WHERE al_prev.numcuenta = tmp.cuenta
               AND al_prev.nromedidor = tmp.medidor
               AND (al_prev.anio < EXTRACT(YEAR FROM CURRENT_DATE)
                   OR (al_prev.anio = EXTRACT(YEAR FROM CURRENT_DATE)
                       AND al_prev.mes < EXTRACT(MONTH FROM CURRENT_DATE)))
             ORDER BY al_prev.anio DESC, al_prev.mes DESC
             LIMIT 1),
            0
        ), 0)
    FROM temp_actualizar tmp
    WHERE al.numcuenta = tmp.cuenta
      AND al.nromedidor = tmp.medidor
      AND EXTRACT(MONTH FROM CURRENT_DATE) = al.mes
      AND EXTRACT(YEAR FROM CURRENT_DATE) = al.anio;

    -- Insertar nuevos registros en aapplectura desde la tabla temporal temp_insertar
    INSERT INTO aapplectura (numcuenta, anio, mes, lectura, observacion, lecturaanterior, consumo, nromedidor, ciu)
    SELECT
        tmp.cuenta,
        EXTRACT(YEAR FROM CURRENT_DATE) AS anio,
        EXTRACT(MONTH FROM CURRENT_DATE) AS mes,
        tmp.lectura::INTEGER,
        tmp.observacion,
        COALESCE(
            (SELECT al_prev.lectura
             FROM aapplectura al_prev
             WHERE al_prev.numcuenta = tmp.cuenta
               AND al_prev.nromedidor = tmp.medidor
               AND (al_prev.anio < EXTRACT(YEAR FROM CURRENT_DATE)
                   OR (al_prev.anio = EXTRACT(YEAR FROM CURRENT_DATE)
                       AND al_prev.mes < EXTRACT(MONTH FROM CURRENT_DATE)))
             ORDER BY al_prev.anio DESC, al_prev.mes DESC
             LIMIT 1),
            0
        ) AS lecturaanterior,
        GREATEST(tmp.lectura::INTEGER - COALESCE(
            (SELECT al_prev.lectura
             FROM aapplectura al_prev
             WHERE al_prev.numcuenta = tmp.cuenta
               AND al_prev.nromedidor = tmp.medidor
               AND (al_prev.anio < EXTRACT(YEAR FROM CURRENT_DATE)
                   OR (al_prev.anio = EXTRACT(YEAR FROM CURRENT_DATE)
                       AND al_prev.mes < EXTRACT(MONTH FROM CURRENT_DATE)))
             ORDER BY al_prev.anio DESC, al_prev.mes DESC
             LIMIT 1),
            0
        ), 0) AS consumo,
        tmp.medidor,
        (SELECT ci.numide_d FROM vct002 ci WHERE ci.Nombre || ' ' || ci.Apellido = tmp.abonado) -- Obtener el id del ciudadano
    FROM temp_insertar tmp;

    -- Ajustar la secuencia del id después de insertar nuevos registros
    SELECT MAX(id) INTO max_id FROM aapplectura;
    IF max_id IS NOT NULL THEN
        PERFORM setval('aapplectura_id_seq', max_id + 1);
    END IF;

    -- Eliminar las tablas temporales
    DROP TABLE IF EXISTS temp_actualizar;
    DROP TABLE IF EXISTS temp_insertar;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION llenar_aappMovilLectura(
    p_cuenta VARCHAR(20),
    p_lectura VARCHAR(10),
    p_observacion TEXT
) RETURNS TEXT AS $$
DECLARE
    v_medidor VARCHAR(20);
    v_clave VARCHAR(20);
    v_abonado VARCHAR(100);
    v_direccion VARCHAR(255);
    v_existe BOOLEAN;
    v_mensaje TEXT;
BEGIN
    -- Comprobar si la cuenta existe en aappcometidas
    SELECT EXISTS(SELECT 1 FROM aappcometidas WHERE numcuenta = p_cuenta) INTO v_existe;
    
    IF NOT v_existe THEN
        -- Si la cuenta no existe, devolver un mensaje
        RETURN 'La cuenta ' || p_cuenta || ' no existe en aappcometidas.';
    END IF;

    -- Comprobar si la cuenta ya existe en aappMovilLectura
    SELECT EXISTS(SELECT 1 FROM aappMovilLectura WHERE cuenta = p_cuenta) INTO v_existe;
    
    IF v_existe THEN
        -- Si el registro ya existe, devolver un mensaje
        RETURN 'El registro para la cuenta ' || p_cuenta || ' ya existe en aappMovilLectura. No se realizaron cambios.';
    END IF;

    -- Obtener información de aappcometidas
    SELECT no_medidor, clave, direccion
    INTO v_medidor, v_clave, v_direccion
    FROM aappcometidas
    WHERE numcuenta = p_cuenta;

    -- Verificar si se encontraron los datos básicos
    IF v_medidor IS NULL OR v_clave IS NULL OR v_direccion IS NULL THEN
        RETURN 'No se encontraron todos los datos necesarios para la cuenta ' || p_cuenta || ' en aappcometidas.';
    END IF;

    -- Buscar el abonado en vct002 basado en la dirección
    SELECT CONCAT(Nombre, ' ', Apellido)
    INTO v_abonado
    FROM vct002
    WHERE Direccion = v_direccion
    LIMIT 1;

    -- Si no se encuentra un abonado, establecer como 'Abonado no identificado'
    IF v_abonado IS NULL THEN
        v_abonado := 'Abonado no identificado';
    END IF;

    -- Insertar nuevo registro en aappMovilLectura
    INSERT INTO aappMovilLectura (
        cuenta, 
        medidor, 
        clave, 
        abonado, 
        lectura, 
        observacion,
        coordenadasXYZ, 
        direccion
    ) VALUES (
        p_cuenta,
        v_medidor,
        v_clave,
        v_abonado,
        p_lectura,
        p_observacion,
        '0.0.0,0.0.0,0.0.0',
        v_direccion
    );

    RETURN 'Se ha insertado un nuevo registro para la cuenta ' || p_cuenta || '.';
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION obtener_datos_consumo(
    fecha_consulta DATE DEFAULT CURRENT_DATE,
    limite_registros INTEGER DEFAULT NULL,
    rango_unidades NUMERIC DEFAULT 2,
    limite_promedio INTEGER DEFAULT 3
) RETURNS TABLE (
    cuenta VARCHAR,
    medidor VARCHAR,
    clave VARCHAR,
    abonado VARCHAR,
    ruta VARCHAR,
    lectura_actual INTEGER,
    promedio NUMERIC(10,2),
    observacion TEXT,
    coordenadas VARCHAR,
    rango_superior NUMERIC,
    rango_inferior NUMERIC,
    lectura_aplectura INTEGER,
    diferencia NUMERIC,
    observacion_movil TEXT,
    motivo TEXT,
    imagen BYTEA,
    registros_usados INTEGER
) AS $$
BEGIN
    -- Validaciones
    IF fecha_consulta > CURRENT_DATE THEN
        RAISE EXCEPTION 'La fecha de consulta no puede ser futura';
    END IF;
    IF limite_registros IS NOT NULL AND limite_registros <= 0 THEN
        RAISE EXCEPTION 'El límite de registros debe ser un número positivo';
    END IF;
    IF rango_unidades <= 0 THEN
        RAISE EXCEPTION 'El rango de unidades debe ser un número positivo';
    END IF;
    IF limite_promedio <= 0 THEN
        RAISE EXCEPTION 'El límite para el cálculo del promedio debe ser un número positivo';
    END IF;
    
    RETURN QUERY
    WITH fecha_actual AS (
        SELECT EXTRACT(YEAR FROM fecha_consulta)::INTEGER AS anio_actual,
               EXTRACT(MONTH FROM fecha_consulta)::INTEGER AS mes_actual
    ),
    ultimos_registros AS (
        SELECT apl.numcuenta, apl.consumo AS consumo_apl, apl.lecturaanterior, apl.lectura,
               apl.anio, apl.mes,
               ROW_NUMBER() OVER (PARTITION BY apl.numcuenta ORDER BY apl.anio DESC, apl.mes DESC) as rn
        FROM aapplectura apl, fecha_actual fa
        WHERE (apl.anio < fa.anio_actual) OR (apl.anio = fa.anio_actual AND apl.mes <= fa.mes_actual)
    ),
    promedios AS (
        SELECT 
            numcuenta,
            ROUND(AVG(consumo_apl), 2)::NUMERIC(15,2) as promedio_consumo,
            ROUND(AVG(consumo_apl) + rango_unidades, 2)::NUMERIC(15,2) as rango_superior,
            ROUND(GREATEST(AVG(consumo_apl) - rango_unidades, 0), 2)::NUMERIC(15,2) as rango_inferior,
            COUNT(*) as registros_usados
        FROM ultimos_registros
        WHERE rn <= limite_promedio
        GROUP BY numcuenta
    ),
    diferencia_lecturas AS (
        SELECT amv.cuenta, amv.abonado, CAST(amv.lectura AS INTEGER) as lectura_movillectura,
               ur.lectura as lectura_aplectura,
               CAST(amv.lectura AS INTEGER) - ur.lectura as diferencia,
               amv.coordenadasXYZ, amv.observacion AS observacion_movil, amv.motivo, amv.imagen
        FROM aappMovilLectura amv
        JOIN (SELECT numcuenta, lectura FROM ultimos_registros WHERE rn = 1) ur
        ON amv.cuenta = ur.numcuenta
        WHERE amv.lectura IS NOT NULL AND ur.lectura IS NOT NULL
    )
    SELECT 
        dl.cuenta::VARCHAR, 
        ac.no_medidor::VARCHAR AS medidor, 
        ac.clave::VARCHAR, 
        dl.abonado::VARCHAR,
        ac.ruta::VARCHAR, 
        dl.lectura_movillectura::INTEGER AS lectura_actual, 
        p.promedio_consumo::NUMERIC(15,2) AS promedio,
        CASE
            WHEN dl.lectura_movillectura < dl.lectura_aplectura THEN 'Posible error: Lectura menor a la anterior'
            WHEN dl.diferencia > p.rango_superior THEN 'Alto consumo'
            WHEN dl.diferencia < p.rango_inferior THEN 'Bajo consumo'
            WHEN dl.lectura_aplectura IS NULL THEN 'Pendiente de sincronizar'
            WHEN p.registros_usados < limite_promedio THEN 'Advertencia: Promedio calculado con menos registros de los solicitados'
            ELSE 'Normal'
        END::TEXT as observacion,
        dl.coordenadasXYZ::VARCHAR AS coordenadas, 
        p.rango_superior::NUMERIC(15,2), 
        p.rango_inferior::NUMERIC(15,2),
        dl.lectura_aplectura::INTEGER, 
        GREATEST(dl.diferencia, 0)::NUMERIC(15,2),
        dl.observacion_movil::TEXT, 
        dl.motivo::TEXT, 
        dl.imagen::BYTEA,
        p.registros_usados::INTEGER
    FROM diferencia_lecturas dl
    JOIN promedios p ON dl.cuenta = p.numcuenta
    JOIN aappcometidas ac ON dl.cuenta = ac.numcuenta
    WHERE dl.cuenta IS NOT NULL AND ac.no_medidor IS NOT NULL AND ac.clave IS NOT NULL AND dl.abonado IS NOT NULL AND ac.ruta IS NOT NULL
    ORDER BY dl.cuenta
    LIMIT CASE WHEN limite_registros IS NOT NULL THEN limite_registros ELSE NULL END;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION obtener_datos_por_cuenta(cuenta_input VARCHAR)
RETURNS TABLE (
    id INT,
    cuenta VARCHAR,
    medidor VARCHAR,
    clave VARCHAR,
    abonado VARCHAR,
    lectura VARCHAR,
    observacion TEXT,
    coordenadasXYZ VARCHAR,
    direccion VARCHAR,
    motivo TEXT,
    imagen BYTEA,
    fecha_hora_registro TIMESTAMP,
    fecha_hora_edicion TIMESTAMP
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        aappMovilLectura.id,
        aappMovilLectura.cuenta,
        aappMovilLectura.medidor,
        aappMovilLectura.clave,
        aappMovilLectura.abonado,
        aappMovilLectura.lectura,
        aappMovilLectura.observacion,
        aappMovilLectura.coordenadasXYZ,
        aappMovilLectura.direccion,
        aappMovilLectura.motivo,
        aappMovilLectura.imagen,
        aappMovilLectura.fecha_hora_registro,
        aappMovilLectura.fecha_hora_edicion
    FROM 
        aappMovilLectura
    WHERE 
        aappMovilLectura.cuenta = cuenta_input;
END;
$$ LANGUAGE plpgsql;

-- Eliminar el tipo compuesto si ya existe
DROP TYPE IF EXISTS tipo_lectura;

-- Crear el tipo compuesto tipo_lectura con las nuevas columnas
CREATE TYPE tipo_lectura AS (
    numcuenta VARCHAR(255),
    no_medidor VARCHAR(255),
    clave VARCHAR(255),
    lectura VARCHAR(10),
    observacion TEXT,
    coordenadasXYZ TEXT,
    motivo TEXT,   -- Nueva columna para motivo
    imagen BYTEA,  -- Nueva columna para imagen
    fecha_actualizacion TIMESTAMP   -- Nueva columna para fecha de actualización
);

-- Modificar el procedimiento almacenado SincronizarLecturasMasivas
CREATE OR REPLACE PROCEDURE SincronizarLecturasMasivas(
    p_login_usuario VARCHAR(255),
    p_lecturas tipo_lectura[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_lectura tipo_lectura;
    v_anio INTEGER;
    v_mes INTEGER;
    v_lectura_anterior VARCHAR(10);
    v_consumo INTEGER;
    v_abonado VARCHAR(255);
    v_direccion VARCHAR(255);
    v_ruta VARCHAR(255);
BEGIN
    -- Obtener año y mes actuales
    SELECT EXTRACT(YEAR FROM NOW()), EXTRACT(MONTH FROM NOW())
    INTO v_anio, v_mes;

    -- Loop a través del array de lecturas
    FOREACH v_lectura IN ARRAY p_lecturas
    LOOP
        -- Obtener la ruta de la cuenta y verificar si está asignada al usuario
        SELECT a.ruta
        INTO v_ruta
        FROM aappcometidas a
        INNER JOIN aapplectorruta apl ON a.ruta = apl.ruta
        WHERE apl.login = p_login_usuario AND a.numcuenta = v_lectura.numcuenta
        LIMIT 1;
        
        -- Si no se encuentra la ruta o no está asignada al usuario, saltar a la siguiente iteración
        IF v_ruta IS NULL THEN
            CONTINUE;
        END IF;

        -- Obtener la lectura anterior y otros datos (con manejo de nulos) desde aappmovillectura
        SELECT lectura, abonado, direccion
        INTO v_lectura_anterior, v_abonado, v_direccion
        FROM aappmovillectura
        WHERE cuenta = v_lectura.numcuenta
        ORDER BY id DESC
        LIMIT 1;

        -- Calcular consumo SOLO si hay lectura anterior y es un valor numérico
        IF v_lectura_anterior IS NOT NULL AND v_lectura_anterior ~ '^[0-9]+$' THEN
            v_consumo := v_lectura.lectura::INTEGER - v_lectura_anterior::INTEGER;
        ELSE
            v_consumo := 0;
        END IF;

        -- Verificar si ya existe una lectura para el mes y año actual
        IF EXISTS (
            SELECT 1
            FROM aappmovillectura
            WHERE cuenta = v_lectura.numcuenta
              AND EXTRACT(YEAR FROM fecha_hora_registro) = v_anio
              AND EXTRACT(MONTH FROM fecha_hora_registro) = v_mes
        ) THEN
            -- Actualizar la lectura existente (sin cambiar la dirección)
            UPDATE aappmovillectura
            SET lectura = v_lectura.lectura,
                observacion = v_lectura.observacion,
                coordenadasXYZ = v_lectura.coordenadasXYZ,
                motivo = COALESCE(v_lectura.motivo, motivo),
                imagen = COALESCE(v_lectura.imagen, imagen),
                fecha_hora_edicion = v_lectura.fecha_actualizacion,
                modificado_por = p_login_usuario
            WHERE cuenta = v_lectura.numcuenta
              AND EXTRACT(YEAR FROM fecha_hora_registro) = v_anio
              AND EXTRACT(MONTH FROM fecha_hora_registro) = v_mes;
        ELSE
            -- Insertar una nueva lectura (manteniendo la dirección y abonado)
            INSERT INTO aappmovillectura (cuenta, medidor, clave, abonado, lectura, observacion, coordenadasXYZ, direccion, motivo, imagen, fecha_hora_registro, modificado_por)
            VALUES (v_lectura.numcuenta, v_lectura.no_medidor, v_lectura.clave, v_abonado, v_lectura.lectura, v_lectura.observacion, v_lectura.coordenadasXYZ, v_direccion, v_lectura.motivo, v_lectura.imagen, CURRENT_TIMESTAMP, p_login_usuario);
        END IF;
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION actualizar_lectorruta(
    p_login VARCHAR,
    p_idruta INT,
    new_login VARCHAR,
    new_idruta INT,
    p_fecha DATE
) RETURNS TEXT AS $$
DECLARE
    user_name VARCHAR(255);
    route_name VARCHAR(255);
    mensaje TEXT;
    nombre_ruta_original VARCHAR(255);
BEGIN
    -- Verificar si el registro con el login y id de ruta proporcionados existe
    SELECT nombre INTO nombre_ruta_original FROM aappbario WHERE id = p_idruta;
    IF NOT EXISTS (SELECT 1 FROM aapplectorruta WHERE login = p_login AND ruta = nombre_ruta_original) THEN
        mensaje := format('El registro con login %s y ID de ruta %s no existe', p_login, p_idruta);
        RETURN mensaje;
    END IF;

    -- Verificar si el nuevo usuario y la nueva ruta existen
    IF NOT EXISTS (SELECT 1 FROM csebase1 WHERE login = new_login) THEN
        mensaje := format('El usuario con login %s no existe', new_login);
        RETURN mensaje;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM aappbario WHERE id = new_idruta) THEN
        mensaje := format('La ruta con ID %s no existe', new_idruta);
        RETURN mensaje;
    END IF;

    -- Validar la fecha
    IF p_fecha <> CURRENT_DATE AND p_fecha <> CURRENT_DATE + INTERVAL '1 day' THEN
        mensaje := 'La fecha debe ser la actual o la del próximo día.';
        RETURN mensaje;
    END IF;

    -- Obtener el nombre del usuario
    SELECT nombre INTO user_name FROM csebase1 WHERE login = new_login;

    -- Obtener el nombre de la ruta
    SELECT nombre INTO route_name FROM aappbario WHERE id = new_idruta;

    -- Verificar si la misma combinación de usuario y ruta ya existe en otro registro
    IF EXISTS (SELECT 1 FROM aapplectorruta WHERE login = new_login AND ruta = route_name AND NOT (login = p_login AND ruta = nombre_ruta_original)) THEN
        mensaje := format('La combinación de usuario %s y ruta %s ya existe en otro registro.', user_name, route_name);
        RETURN mensaje;
    END IF;

    -- Verificar si la nueva ruta ya está asignada a otro usuario
    IF EXISTS (SELECT 1 FROM aapplectorruta WHERE ruta = route_name AND login <> new_login) THEN
        mensaje := format('La ruta %s ya está asignada a otro usuario.', route_name);
        RETURN mensaje;
    END IF;

    -- Actualizar el registro en la tabla aapplectorruta con la nueva fecha
    UPDATE aapplectorruta
    SET login = new_login, ruta = route_name, fecha = p_fecha
    WHERE login = p_login AND ruta = nombre_ruta_original;

    -- Verificar si la actualización fue exitosa
    IF NOT FOUND THEN
        mensaje := 'No se encontró el registro para actualizar.';
        RETURN mensaje;
    END IF;

    -- Verificar la fecha actualizada
    PERFORM 1 FROM aapplectorruta WHERE login = new_login AND ruta = route_name AND fecha = p_fecha;
    IF NOT FOUND THEN
        mensaje := 'La fecha no se actualizó correctamente.';
        RETURN mensaje;
    END IF;

    mensaje := format('Registro con login %s y ID de ruta %s actualizado correctamente. Nueva ruta %s asignada al usuario %s.', p_login, p_idruta, route_name, user_name);
    RETURN mensaje;
END;
$$ LANGUAGE plpgsql;

-- Procedimiento para asignar o actualizar una ruta a un usuario por login y id de la ruta
CREATE OR REPLACE FUNCTION AsignarRutaAUsuario(
    p_login VARCHAR(255),
    p_route_id INTEGER,
    p_fecha DATE
) RETURNS TEXT AS $$
DECLARE
    user_name VARCHAR(255);
    route_name VARCHAR(255);
    mensaje TEXT;
BEGIN
    -- Verificar si el usuario y la ruta existen
    IF NOT EXISTS (SELECT 1 FROM csebase1 WHERE login = p_login) THEN
        mensaje := format('El usuario con login %s no existe', p_login);
        RETURN mensaje;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM aappbario WHERE id = p_route_id) THEN
        mensaje := format('La ruta con ID %s no existe', p_route_id);
        RETURN mensaje;
    END IF;

    -- Validar la fecha
    IF p_fecha <> CURRENT_DATE AND p_fecha <> CURRENT_DATE + INTERVAL '1 day' THEN
        mensaje := 'La fecha debe ser la actual o la del próximo día.';
        RETURN mensaje;
    END IF;

    -- Obtener el nombre del usuario
    SELECT nombre || ' ' || apellido INTO user_name FROM csebase1 WHERE login = p_login;

    -- Obtener el nombre de la ruta
    SELECT nombre INTO route_name FROM aappbario WHERE id = p_route_id;

    -- Verificar si la ruta ya está asignada a otro usuario
    IF EXISTS (SELECT 1 FROM aapplectorruta WHERE ruta = route_name AND login <> p_login) THEN
        mensaje := format('La ruta con nombre %s ya está asignada a otro usuario.', route_name);
        RETURN mensaje;
    END IF;

    -- Verificar si el usuario ya tiene la ruta asignada
    IF EXISTS (SELECT 1 FROM aapplectorruta WHERE login = p_login AND ruta = route_name) THEN
        mensaje := format('La ruta %s ya está asignada al usuario %s.', route_name, user_name);
    ELSE
        -- Asignar la ruta al usuario con la fecha proporcionada
        INSERT INTO aapplectorruta (login, ruta, anio, mes, fechatoma, fecha, lector)
        VALUES (p_login, route_name, EXTRACT(YEAR FROM p_fecha), EXTRACT(MONTH FROM p_fecha), p_fecha, CURRENT_TIMESTAMP, p_login);
        mensaje := format('Ruta %s asignada correctamente al usuario %s.', route_name, user_name);
    END IF;

    RETURN mensaje;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION eliminar_lectorruta(p_login VARCHAR, p_idruta INT)
RETURNS VOID AS $$
BEGIN
    DELETE FROM aapplectorruta
    WHERE login = p_login AND ruta = (
        SELECT nombre FROM aappbario WHERE id = p_idruta
    );
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se encontró la ruta con login % y ID de ruta %', p_login, p_idruta;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener los datos de lectorruta basado en login y id de ruta
CREATE OR REPLACE FUNCTION obtener_lectorruta(
    p_login VARCHAR,
    p_idruta INT
)
RETURNS TABLE (
    login_usuario VARCHAR,
    id_ruta INT,
    nombre_usuario VARCHAR,
    nombre_ruta VARCHAR,
    fecha TIMESTAMP  -- Agregar el campo fecha aquí
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        alr.login AS login_usuario,
        ar.id AS id_ruta,
        (cl.nombre || ' ' || cl.apellido)::VARCHAR AS nombre_usuario,  -- Concatena nombre y apellido y convierte a VARCHAR
        ar.nombre AS nombre_ruta,
        alr.fecha  -- Agregar el campo fecha aquí
    FROM 
        aapplectorruta alr
    JOIN 
        csebase1 cl ON alr.login = cl.login
    JOIN 
        aappbario ar ON alr.ruta = ar.nombre
    WHERE 
        alr.login = p_login AND
        ar.id = p_idruta;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se encontró el Lector-Ruta con login % y ID de ruta %', p_login, p_idruta;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener información de acometidas relacionadas con el login del usuario
CREATE OR REPLACE FUNCTION RutaLecturaMovil(p_login VARCHAR(255))
RETURNS TABLE (
    id_ruta INTEGER,
    numcuenta VARCHAR(255),
    no_medidor VARCHAR(255),
    clave VARCHAR(255),
    ruta VARCHAR(255),
    direccion VARCHAR(255),
    abonado VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.id AS id_ruta,
        a.numcuenta,
        a.no_medidor,
        a.clave,
        a.ruta,
        a.direccion,
        COALESCE(
            (SELECT CONCAT(ciud.Nombre, ' ', ciud.Apellido)::VARCHAR
             FROM aapplectura aplect
             INNER JOIN vct002 ciud ON aplect.ciu = ciud.numide_d AND aplect.numcuenta = a.numcuenta
             LIMIT 1),
            (SELECT appmov.abonado::VARCHAR 
             FROM aappMovilLectura appmov
             WHERE appmov.cuenta = a.numcuenta
             LIMIT 1)
        ) AS abonado
    FROM aappcometidas a
    INNER JOIN aapplectorruta apl ON a.ruta = apl.ruta
    INNER JOIN csebase1 usu ON apl.login = usu.login
    INNER JOIN aappbario b ON apl.ruta = b.nombre
    WHERE apl.login = p_login; 
END;
$$ LANGUAGE plpgsql;

-- Función para obtener los datos de lectorruta
CREATE OR REPLACE FUNCTION obtener_datos_lectorruta()
RETURNS TABLE(
    login_usuario VARCHAR,
    nombre_usuario VARCHAR,
    id_ruta INT,
    nombre_ruta VARCHAR,
    fecha TIMESTAMP  -- Agregar el campo fecha aquí
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cl.login AS login_usuario,
        (cl.nombre || ' ' || cl.apellido)::VARCHAR AS nombre_usuario,  -- Concatena nombre y apellido y convierte a VARCHAR
        ar.id AS id_ruta,
        ar.nombre AS nombre_ruta,
        alr.fecha  -- Agregar el campo fecha aquí
    FROM 
        aapplectorruta alr
    JOIN 
        csebase1 cl ON alr.login = cl.login
    JOIN 
        aappbario ar ON alr.ruta = ar.nombre;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener todas las rutas
CREATE OR REPLACE FUNCTION ObtenerRutas()
RETURNS TABLE (
    id INTEGER,
    nombreruta VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT r.id, r.nombre
    FROM aappbario r;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener todos los usuarios
CREATE OR REPLACE FUNCTION ObtenerUsuarios()
RETURNS TABLE (
    login VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT u.login 
    FROM csebase1 u;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION UsuarioRuta(p_login VARCHAR)
RETURNS TABLE (
  nombre_ruta VARCHAR(255),
  login VARCHAR(255),
  id_ruta INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ap.nombre AS nombre_ruta, 
    usu.login AS login, 
    ap.id AS id_ruta
  FROM aapplectorruta apl 
  INNER JOIN aappbario ap ON apl.ruta = ap.nombre
  INNER JOIN csebase1 usu ON apl.login = usu.login
  WHERE usu.login = p_login;
END;
$$ LANGUAGE plpgsql;
