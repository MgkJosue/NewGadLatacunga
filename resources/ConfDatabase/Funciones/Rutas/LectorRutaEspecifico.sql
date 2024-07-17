-- Función para obtener los datos de lectorruta basado en login y id de ruta
CREATE OR REPLACE FUNCTION obtener_lectorruta(
    p_login VARCHAR,
    p_idruta INT
)
RETURNS TABLE (
    login_usuario VARCHAR,
    id_ruta INT,
    nombre_usuario VARCHAR,
    nombre_ruta VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        alr.login AS login_usuario,
        ar.id AS id_ruta,
        (cl.nombre || ' ' || cl.apellido)::VARCHAR AS nombre_usuario,  -- Concatena nombre y apellido y convierte a VARCHAR
        ar.nombre AS nombre_ruta
    FROM 
        aapplectorruta alr
    JOIN 
        csebase1 cl ON alr.login = cl.login
    JOIN 
        aappbario ar ON alr.ruta = ar.nombre
    WHERE 
        alr.login = p_login AND
        ar.id = p_idruta;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se encontró el Lector-Ruta con login % y ID de ruta %', p_login, p_idruta;
    END IF;
END;
$$ LANGUAGE plpgsql;
