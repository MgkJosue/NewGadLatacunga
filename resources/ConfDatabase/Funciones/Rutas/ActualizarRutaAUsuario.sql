CREATE OR REPLACE FUNCTION actualizar_lectorruta(
    p_login VARCHAR,
    p_idruta INT,
    new_login VARCHAR,
    new_idruta INT,
    p_fecha DATE
) RETURNS TEXT AS $$
DECLARE
    user_name VARCHAR(255);
    route_name VARCHAR(255);
    mensaje TEXT;
    nombre_ruta_original VARCHAR(255);
BEGIN
    -- Verificar si el registro con el login y id de ruta proporcionados existe
    SELECT nombre INTO nombre_ruta_original FROM aappbario WHERE id = p_idruta;
    IF NOT EXISTS (SELECT 1 FROM aapplectorruta WHERE login = p_login AND ruta = nombre_ruta_original) THEN
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

    -- Validar la fecha
    IF p_fecha <> CURRENT_DATE AND p_fecha <> CURRENT_DATE + INTERVAL '1 day' THEN
        mensaje := 'La fecha debe ser la actual o la del próximo día.';
        RETURN mensaje;
    END IF;

    -- Obtener el nombre del usuario
    SELECT nombre INTO user_name FROM csebase1 WHERE login = new_login;

    -- Obtener el nombre de la ruta
    SELECT nombre INTO route_name FROM aappbario WHERE id = new_idruta;

    -- Verificar si la misma combinación de usuario y ruta ya existe en otro registro
    IF EXISTS (SELECT 1 FROM aapplectorruta WHERE login = new_login AND ruta = route_name AND NOT (login = p_login AND ruta = nombre_ruta_original)) THEN
        mensaje := format('La combinación de usuario %s y ruta %s ya existe en otro registro.', user_name, route_name);
        RETURN mensaje;
    END IF;

    -- Verificar si la nueva ruta ya está asignada a otro usuario
    IF EXISTS (SELECT 1 FROM aapplectorruta WHERE ruta = route_name AND login <> new_login) THEN
        mensaje := format('La ruta %s ya está asignada a otro usuario.', route_name);
        RETURN mensaje;
    END IF;

    -- Actualizar el registro en la tabla aapplectorruta con la nueva fecha
    UPDATE aapplectorruta
    SET login = new_login, ruta = route_name, fecha = p_fecha
    WHERE login = p_login AND ruta = nombre_ruta_original;

    -- Verificar si la actualización fue exitosa
    IF NOT FOUND THEN
        mensaje := 'No se encontró el registro para actualizar.';
        RETURN mensaje;
    END IF;

    -- Verificar la fecha actualizada
    PERFORM 1 FROM aapplectorruta WHERE login = new_login AND ruta = route_name AND fecha = p_fecha;
    IF NOT FOUND THEN
        mensaje := 'La fecha no se actualizó correctamente.';
        RETURN mensaje;
    END IF;

    mensaje := format('Registro con login %s y ID de ruta %s actualizado correctamente. Nueva ruta %s asignada al usuario %s.', p_login, p_idruta, route_name, user_name);
    RETURN mensaje;
END;
$$ LANGUAGE plpgsql;
