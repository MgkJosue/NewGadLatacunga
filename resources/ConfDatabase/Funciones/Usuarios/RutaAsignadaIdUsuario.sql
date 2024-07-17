CREATE OR REPLACE FUNCTION UsuarioRuta(p_login VARCHAR)
RETURNS TABLE (
  nombre_ruta VARCHAR(255),
  login VARCHAR(255),
  id_ruta INTEGER
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ap.nombre AS nombre_ruta, 
    usu.login AS login, 
    ap.id AS id_ruta
  FROM aapplectorruta apl 
  INNER JOIN aappbario ap ON apl.ruta = ap.nombre
  INNER JOIN csebase1 usu ON apl.login = usu.login
  WHERE usu.login = p_login;
END;
$$ LANGUAGE plpgsql;
