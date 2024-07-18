CREATE OR REPLACE FUNCTION editar_lectura_movil(
    p_cuenta VARCHAR,
    p_nueva_lectura VARCHAR,
    p_nueva_observacion TEXT,
    p_nuevo_motivo TEXT DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_updated INTEGER;
    v_lectura_anterior VARCHAR;
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

    -- Obtener la lectura anterior
    SELECT lectura INTO v_lectura_anterior
    FROM aappMovilLectura
    WHERE cuenta = p_cuenta;

    IF v_lectura_anterior IS NULL THEN
        RAISE EXCEPTION 'No se encontró la lectura para la cuenta especificada';
    END IF;

    -- Actualizar la lectura
    UPDATE aappMovilLectura
    SET lectura = p_nueva_lectura,
        observacion = COALESCE(p_nueva_observacion, observacion),
        motivo = COALESCE(p_nuevo_motivo, motivo),
        fecha_hora_edicion = CURRENT_TIMESTAMP
    WHERE cuenta = p_cuenta;
    
    GET DIAGNOSTICS v_updated = ROW_COUNT;

    RETURN v_updated > 0;
END;
$$ LANGUAGE plpgsql;
