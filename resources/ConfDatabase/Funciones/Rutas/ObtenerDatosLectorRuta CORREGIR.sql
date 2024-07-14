-- Función para obtener los datos de lectorruta
CREATE OR REPLACE FUNCTION obtener_datos_lectorruta()
RETURNS TABLE(
    id_lectorruta INT,
    login_usuario VARCHAR,
    nombre_usuario VARCHAR,
    id_ruta INT,
    nombre_ruta VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ROW_NUMBER() OVER () AS id_lectorruta,  -- Genera un ID secuencial para cada fila
        cl.login AS login_usuario,
        cl.nombre AS nombre_usuario,
        ar.id AS id_ruta,
        ar.nombre AS nombre_ruta
    FROM 
        aapplectorruta alr
    JOIN 
        csebase1 cl ON alr.login = cl.login
    JOIN 
        aappbario ar ON alr.ruta = ar.nombre;
END;
$$ LANGUAGE plpgsql;
