-- Función para Validar Usuario
CREATE OR REPLACE FUNCTION validar_usuario(
    p_login VARCHAR(255),
    p_clave VARCHAR(255)
)
RETURNS RECORD AS $$
DECLARE
    v_clave_almacenada VARCHAR(255);
    v_usuario_id INT;             -- Variable para almacenar el ID del usuario
BEGIN
    -- Obtener la clave y el ID del usuario
    SELECT clave, id INTO v_clave_almacenada, v_usuario_id
    FROM csebase1
    WHERE login = p_login;

    IF v_clave_almacenada IS NULL THEN
        RETURN (FALSE, NULL);    -- Devolvemos FALSE y un ID nulo si no se encuentra el usuario
    ELSIF v_clave_almacenada = p_clave THEN
        RETURN (TRUE, v_usuario_id); -- Devolvemos TRUE y el ID si la clave es correcta
    ELSE
        RETURN (FALSE, NULL);    -- Devolvemos FALSE y un ID nulo si la clave es incorrecta
    END IF;
END;
$$ LANGUAGE plpgsql;
