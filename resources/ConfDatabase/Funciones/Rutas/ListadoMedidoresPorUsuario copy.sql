-- Función para obtener información de acometidas relacionadas con login del usuario
CREATE OR REPLACE FUNCTION RutaLecturaMovil(p_login VARCHAR(255))
RETURNS TABLE (
    id_usuario INTEGER,
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
        usu.id AS id_usuario,
        ap.id AS id_ruta,
        a.numcuenta,
        a.no_medidor,
        a.clave,
        a.ruta,
        a.direccion,
        COALESCE(
            (SELECT CAST(CONCAT(ciud.Nombre, ' ', ciud.Apellido) AS VARCHAR(255))
             FROM aapplectura aplect
             INNER JOIN vct002 ciud ON aplect.ciu = ciud.numide_d AND aplect.numcuenta = a.numcuenta
             LIMIT 1),
            (SELECT appmov.abonado 
             FROM public.aappMovilLectura appmov
             WHERE appmov.cuenta = a.numcuenta
             LIMIT 1)
        ) AS abonado
    FROM aappcometidas a
    INNER JOIN aapplectorruta apl ON a.ruta = apl.ruta
    INNER JOIN csebase1 usu ON apl.login = usu.login
    INNER JOIN aappbario ap ON apl.ruta = ap.nombre
    WHERE apl.login = p_login;
END;
$$ LANGUAGE plpgsql;
