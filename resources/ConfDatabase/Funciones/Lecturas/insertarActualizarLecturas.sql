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
