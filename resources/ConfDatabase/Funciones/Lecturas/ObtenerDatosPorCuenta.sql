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
