CREATE OR REPLACE FUNCTION eliminar_lectorruta(p_login VARCHAR, p_idruta INT)
RETURNS VOID AS $$
BEGIN
    DELETE FROM aapplectorruta
    WHERE login = p_login AND ruta = (
        SELECT nombre FROM aappbario WHERE id = p_idruta
    );
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se encontró la ruta con login % y ID de ruta %', p_login, p_idruta;
    END IF;
END;
$$ LANGUAGE plpgsql;
