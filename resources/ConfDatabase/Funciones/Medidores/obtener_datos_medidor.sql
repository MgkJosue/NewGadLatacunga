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
        acometidas.no_medidor, 
        acometidas.clave, 
        ciudadano.Nombre || ' ' || ciudadano.Apellido AS abonado, 
        acometidas.direccion
    FROM 
        aappcometidas acometidas
    JOIN 
        vct002 ciudadano ON ciudadano.Direccion = acometidas.direccion
    WHERE 
        acometidas.numcuenta = cuenta_param;
END;
$$ LANGUAGE plpgsql;