-- Función para obtener todos los usuarios
CREATE OR REPLACE FUNCTION ObtenerUsuarios()
RETURNS TABLE (
    id INTEGER,
    login VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT u.id, u.login
    FROM csebase1 u;
END;
$$ LANGUAGE plpgsql;
