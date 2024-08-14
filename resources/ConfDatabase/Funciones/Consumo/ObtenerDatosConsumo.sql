CREATE OR REPLACE FUNCTION obtener_datos_consumo(
    fecha_consulta DATE DEFAULT CURRENT_DATE,
    limite_registros INTEGER DEFAULT NULL
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
DECLARE
    v_limite_promedio INTEGER;
    v_rango_unidades NUMERIC;
BEGIN
    -- Obtener los parámetros de la tabla
    SELECT limite_promedio, rango_unidades
    INTO v_limite_promedio, v_rango_unidades
    FROM parametros_consumo
    ORDER BY fecha_actualizacion DESC
    LIMIT 1;

    -- Validaciones
    IF fecha_consulta > CURRENT_DATE THEN
        RAISE EXCEPTION 'La fecha de consulta no puede ser futura';
    END IF;
    IF limite_registros IS NOT NULL AND limite_registros <= 0 THEN
        RAISE EXCEPTION 'El límite de registros debe ser un número positivo';
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
            ROUND(AVG(consumo_apl) + v_rango_unidades, 2)::NUMERIC(15,2) as rango_superior,
            ROUND(GREATEST(AVG(consumo_apl) - v_rango_unidades, 0), 2)::NUMERIC(15,2) as rango_inferior,
            COUNT(*) as registros_usados
        FROM ultimos_registros
        WHERE rn <= v_limite_promedio
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
            WHEN p.registros_usados < v_limite_promedio THEN 'Advertencia: Promedio calculado con menos registros de los solicitados'
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