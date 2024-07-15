=CREATE OR REPLACE FUNCTION actualizar_lectorruta(
    p_login VARCHAR,
    p_idruta INT,
    new_login VARCHAR,
    new_idruta INT
) RETURNS TEXT AS $$
DECLARE
    existing_record_id INTEGER;
    user_name VARCHAR(255);
    route_name VARCHAR(255);
    mensaje TEXT;
BEGIN
    -- Verificar si el registro con el login y id de ruta proporcionados existe
    IF NOT EXISTS (SELECT 1 FROM aapplectorruta WHERE login = p_login AND ruta = (SELECT nombre FROM aappbario WHERE id = p_idruta)) THEN
        mensaje := format('El registro con login %s y ID de ruta %s no existe', p_login, p_idruta);
        RETURN mensaje;
    END IF;

    -- Verificar si el nuevo usuario y la nueva ruta existen
    IF NOT EXISTS (SELECT 1 FROM csebase1 WHERE login = new_login) THEN
        mensaje := format('El usuario con login %s no existe', new_login);
        RETURN mensaje;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM aappbario WHERE id = new_idruta) THEN
        mensaje := format('La ruta con ID %s no existe', new_idruta);
        RETURN mensaje;
    END IF;

    -- Obtener el nombre del usuario
    SELECT nombre INTO user_name FROM csebase1 WHERE login = new_login;

    -- Obtener el nombre de la ruta
    SELECT nombre INTO route_name FROM aappbario WHERE id = new_idruta;

    -- Verificar si la misma combinación de usuario y ruta ya existe en otro registro
    IF EXISTS (SELECT 1 FROM aapplectorruta WHERE login = new_login AND ruta = (SELECT nombre FROM aappbario WHERE id = new_idruta) AND NOT (login = p_login AND ruta = (SELECT nombre FROM aappbario WHERE id = p_idruta))) THEN
        mensaje := format('La combinación de usuario %s y ruta %s ya existe en otro registro.', user_name, route_name);
        RETURN mensaje;
    END IF;

    -- Actualizar el registro en la tabla aapplectorruta
    UPDATE aapplectorruta
    SET login = new_login, ruta = (SELECT nombre FROM aappbario WHERE id = new_idruta)
    WHERE login = p_login AND ruta = (SELECT nombre FROM aappbario WHERE id = p_idruta);

    mensaje := format('Registro con login %s y ID de ruta %s actualizado correctamente. Nueva ruta %s asignada al usuario %s.', p_login, p_idruta, route_name, user_name);
    RETURN mensaje;
END;
$$ LANGUAGE plpgsql;
