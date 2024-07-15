-- Función para Validar Usuario
CREATE OR REPLACE FUNCTION validar_usuario(
    p_login VARCHAR(255),
    p_clave VARCHAR(255)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_clave_almacenada VARCHAR(255);
BEGIN
    -- Obtener la clave del usuario
    SELECT clave INTO v_clave_almacenada
    FROM csebase1
    WHERE login = p_login;

    IF v_clave_almacenada IS NULL THEN
        RETURN FALSE;    -- Devolvemos FALSE si no se encuentra el usuario
    ELSIF v_clave_almacenada = p_clave THEN
        RETURN TRUE;     -- Devolvemos TRUE si la clave es correcta
    ELSE
        RETURN FALSE;    -- Devolvemos FALSE si la clave es incorrecta
    END IF;
END;
$$ LANGUAGE plpgsql;
