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
    v_lectura_anterior VARCHAR;
    v_coordenadas_originales VARCHAR;
BEGIN
    -- Validaciones (se mantienen igual)
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
    ), medidor, lectura, coordenadasXYZ
    INTO v_datos, v_medidor, v_lectura_anterior, v_coordenadas_originales
    FROM aappMovilLectura
    WHERE cuenta = p_cuenta;
    
    IF v_datos IS NULL THEN
        RAISE EXCEPTION 'No se encontró la lectura para la cuenta especificada';
    END IF;
    
    -- Verificar que la nueva lectura sea mayor o igual a la anterior
    IF CAST(p_nueva_lectura AS NUMERIC) < CAST(v_lectura_anterior AS NUMERIC) THEN
        RAISE EXCEPTION 'La nueva lectura no puede ser menor que la lectura anterior';
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
