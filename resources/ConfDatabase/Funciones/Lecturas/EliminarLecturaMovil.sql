CREATE OR REPLACE FUNCTION eliminar_lectura_movil(
    p_cuenta VARCHAR
)
RETURNS BOOLEAN AS $$
DECLARE
    v_deleted INTEGER;
BEGIN
    -- Validaciones
    IF p_cuenta IS NULL THEN
        RAISE EXCEPTION 'La cuenta no puede ser nula';
    END IF;

    -- Eliminar la lectura
    DELETE FROM aappMovilLectura
    WHERE cuenta = p_cuenta;
    
    GET DIAGNOSTICS v_deleted = ROW_COUNT;

    RETURN v_deleted > 0;
END;
$$ LANGUAGE plpgsql;
