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
