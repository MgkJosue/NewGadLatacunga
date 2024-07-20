-- Procedimiento para asignar o actualizar una ruta a un usuario por login y id de la ruta
CREATE OR REPLACE FUNCTION AsignarRutaAUsuario(
    p_login VARCHAR(255),
    p_route_id INTEGER,
    p_fecha DATE
) RETURNS TEXT AS $$
DECLARE
    user_name VARCHAR(255);
    route_name VARCHAR(255);
    mensaje TEXT;
BEGIN
    -- Verificar si el usuario y la ruta existen
    IF NOT EXISTS (SELECT 1 FROM csebase1 WHERE login = p_login) THEN
        mensaje := format('El usuario con login %s no existe', p_login);
        RETURN mensaje;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM aappbario WHERE id = p_route_id) THEN
        mensaje := format('La ruta con ID %s no existe', p_route_id);
        RETURN mensaje;
    END IF;

    -- Validar la fecha
    IF p_fecha <> CURRENT_DATE AND p_fecha <> CURRENT_DATE + INTERVAL '1 day' THEN
        mensaje := 'La fecha debe ser la actual o la del próximo día.';
        RETURN mensaje;
    END IF;

    -- Obtener el nombre del usuario
    SELECT nombre || ' ' || apellido INTO user_name FROM csebase1 WHERE login = p_login;

    -- Obtener el nombre de la ruta
    SELECT nombre INTO route_name FROM aappbario WHERE id = p_route_id;

    -- Verificar si la ruta ya está asignada a otro usuario
    IF EXISTS (SELECT 1 FROM aapplectorruta WHERE ruta = route_name AND login <> p_login) THEN
        mensaje := format('La ruta con nombre %s ya está asignada a otro usuario.', route_name);
        RETURN mensaje;
    END IF;

    -- Verificar si el usuario ya tiene la ruta asignada
    IF EXISTS (SELECT 1 FROM aapplectorruta WHERE login = p_login AND ruta = route_name) THEN
        mensaje := format('La ruta %s ya está asignada al usuario %s.', route_name, user_name);
    ELSE
        -- Asignar la ruta al usuario con la fecha proporcionada
        INSERT INTO aapplectorruta (login, ruta, anio, mes, fechatoma, fecha, lector)
        VALUES (p_login, route_name, EXTRACT(YEAR FROM p_fecha), EXTRACT(MONTH FROM p_fecha), p_fecha, CURRENT_TIMESTAMP, p_login);
        mensaje := format('Ruta %s asignada correctamente al usuario %s.', route_name, user_name);
    END IF;

    RETURN mensaje;
END;
$$ LANGUAGE plpgsql;
