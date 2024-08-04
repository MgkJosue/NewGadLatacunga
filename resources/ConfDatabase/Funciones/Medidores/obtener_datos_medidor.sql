CREATE OR REPLACE FUNCTION obtener_datos_medidor(cuenta_param VARCHAR)
RETURNS TABLE (
    medidor VARCHAR,
    clave VARCHAR,
    abonado VARCHAR,
    direccion VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        acometidas.no_medidor::VARCHAR, 
        acometidas.clave::VARCHAR, 
        (ciudadano.Nombre || ' ' || ciudadano.Apellido)::VARCHAR AS abonado, 
        acometidas.direccion::VARCHAR
    FROM 
        aappcometidas acometidas
    JOIN 
        vct002 ciudadano ON ciudadano.Direccion = acometidas.direccion
    WHERE 
        acometidas.numcuenta = cuenta_param;
END;
$$ LANGUAGE plpgsql;
