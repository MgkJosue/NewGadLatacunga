CREATE OR REPLACE FUNCTION UsuarioRuta(p_idusuario INTEGER)
RETURNS TABLE (
  nombre_ruta VARCHAR(255),
  login VARCHAR(255),
  id_usuario INTEGER,
  id_ruta INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ap.nombre AS nombre_ruta, 
    usu.login AS login, 
    usu.id AS id_usuario, 
    ap.id AS id_ruta
  FROM aapplectorruta apl 
  INNER JOIN aappbario ap ON apl.ruta = ap.nombre
  INNER JOIN csebase1 usu ON apl.login = usu.login
  WHERE usu.id = p_idusuario;
END;
$$ LANGUAGE plpgsql;
