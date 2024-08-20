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
            -- Primera subconsulta: Intentar obtener el abonado desde aapplectura y vct002
            (SELECT CONCAT(ciud.nombre, ' ', ciud.apellido)::VARCHAR
             FROM aapplectura aplect
             INNER JOIN vct002 ciud ON aplect.ciu = ciud.numide_d
             WHERE aplect.numcuenta = a.numcuenta
             LIMIT 1),
             
            -- Segunda subconsulta: Intentar obtener el abonado desde aappMovilLectura
            (SELECT appmov.abonado::VARCHAR 
             FROM aappMovilLectura appmov
             WHERE appmov.cuenta = a.numcuenta
             LIMIT 1),

            -- Tercera subconsulta: Buscar directamente en vct002 cuando no se encuentre en las anteriores
            (SELECT CONCAT(ciud.nombre, ' ', ciud.apellido)::VARCHAR
             FROM vct002 ciud
             WHERE ciud.numide_d = (
                SELECT aplect.ciu 
                FROM aapplectura aplect 
                WHERE aplect.numcuenta = a.numcuenta 
                LIMIT 1)
             LIMIT 1),

            -- Cuarta subconsulta: Buscar abonado según la dirección
            (SELECT CONCAT(ciud.nombre, ' ', ciud.apellido)::VARCHAR
             FROM vct002 ciud
             WHERE ciud.direccion = a.direccion
             LIMIT 1),

            'No encontrado'
        ) AS abonado
    FROM aappcometidas a
    INNER JOIN aapplectorruta apl ON a.ruta = apl.ruta
    INNER JOIN csebase1 usu ON apl.login = usu.login
    INNER JOIN aappbario b ON apl.ruta = b.nombre
    WHERE apl.login = p_login; 
END;
$$ LANGUAGE plpgsql;
