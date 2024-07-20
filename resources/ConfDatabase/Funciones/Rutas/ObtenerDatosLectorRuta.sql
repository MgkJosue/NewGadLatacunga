-- Función para obtener los datos de lectorruta
CREATE OR REPLACE FUNCTION obtener_datos_lectorruta()
RETURNS TABLE(
    login_usuario VARCHAR,
    nombre_usuario VARCHAR,
    id_ruta INT,
    nombre_ruta VARCHAR,
    fecha TIMESTAMP  -- Agregar el campo fecha aquí
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cl.login AS login_usuario,
        (cl.nombre || ' ' || cl.apellido)::VARCHAR AS nombre_usuario,  -- Concatena nombre y apellido y convierte a VARCHAR
        ar.id AS id_ruta,
        ar.nombre AS nombre_ruta,
        alr.fecha  -- Agregar el campo fecha aquí
    FROM 
        aapplectorruta alr
    JOIN 
        csebase1 cl ON alr.login = cl.login
    JOIN 
        aappbario ar ON alr.ruta = ar.nombre;
END;
$$ LANGUAGE plpgsql;