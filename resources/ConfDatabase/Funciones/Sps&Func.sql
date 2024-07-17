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

-- Crear tablas temporales
CREATE OR REPLACE FUNCTION crear_tablas_temporales()
RETURNS void AS $$
BEGIN
    -- Crear la tabla temporal para registros que necesitan actualización
    CREATE TEMP TABLE temp_actualizar AS
    SELECT DISTINCT aml.*
    FROM aappMovilLectura aml
    INNER JOIN aapplectura al ON aml.cuenta = al.numcuenta
    WHERE EXTRACT(MONTH FROM CURRENT_DATE) = al.mes
      AND EXTRACT(YEAR FROM CURRENT_DATE) = al.anio;

    -- Crear la tabla temporal para registros que necesitan inserción
    CREATE TEMP TABLE temp_insertar AS
    SELECT DISTINCT aml.*
    FROM aappMovilLectura aml
    WHERE NOT EXISTS (
        SELECT 1
        FROM aapplectura al
        WHERE aml.cuenta = al.numcuenta
          AND EXTRACT(MONTH FROM CURRENT_DATE) = al.mes
          AND EXTRACT(YEAR FROM CURRENT_DATE) = al.anio
    );
END;
$$ LANGUAGE plpgsql;

-- Modificar el procedimiento almacenado copiar_registros_a_evidencia
CREATE OR REPLACE FUNCTION copiar_registros_a_evidencia()
RETURNS VOID AS $$
BEGIN
    INSERT INTO aappEvidencia (cuenta, medidor, clave, abonado, lectura, observacion, coordenadasXYZ, direccion, motivo, imagen, fecha_hora_registro, fecha_hora_edicion)
    SELECT cuenta, medidor, clave, abonado, lectura, observacion, coordenadasXYZ, direccion, motivo, imagen, fecha_hora_registro, fecha_hora_edicion
    FROM aappMovilLectura
    ON CONFLICT (cuenta, medidor)
    DO UPDATE SET
        clave = EXCLUDED.clave,
        abonado = EXCLUDED.abonado,
        lectura = EXCLUDED.lectura,
        observacion = EXCLUDED.observacion,
        coordenadasXYZ = EXCLUDED.coordenadasXYZ,
        direccion = EXCLUDED.direccion,
        motivo = EXCLUDED.motivo,
        imagen = EXCLUDED.imagen,
        fecha_hora_registro = EXCLUDED.fecha_hora_registro,
        fecha_hora_edicion = EXCLUDED.fecha_hora_edicion;
END;
$$ LANGUAGE plpgsql;

-- Actualizar e insertar lecturas en la tabla aapplectura desde las tablas temporales
CREATE OR REPLACE FUNCTION actualizar_insertar_lecturas()
RETURNS void AS $$
DECLARE
    max_id INTEGER;
BEGIN
    -- Ajustar la secuencia del id para evitar duplicados
    SELECT MAX(id) INTO max_id FROM aapplectura;
    IF max_id IS NOT NULL THEN
        PERFORM setval('aapplectura_id_seq', max_id);
    END IF;

    -- Actualizar registros existentes en aapplectura usando la tabla temporal temp_actualizar
    UPDATE aapplectura al
    SET
        lectura = tmp.lectura::INTEGER,
        observacion = tmp.observacion,
        nromedidor = tmp.medidor,
        lecturaanterior = COALESCE(
            (SELECT al_prev.lectura
             FROM aapplectura al_prev
             WHERE al_prev.numcuenta = tmp.cuenta
               AND al_prev.nromedidor = tmp.medidor
               AND (al_prev.anio < EXTRACT(YEAR FROM CURRENT_DATE)
                   OR (al_prev.anio = EXTRACT(YEAR FROM CURRENT_DATE)
                       AND al_prev.mes < EXTRACT(MONTH FROM CURRENT_DATE)))
             ORDER BY al_prev.anio DESC, al_prev.mes DESC
             LIMIT 1),
            0
        ),
        consumo = GREATEST(tmp.lectura::INTEGER - COALESCE(
            (SELECT al_prev.lectura
             FROM aapplectura al_prev
             WHERE al_prev.numcuenta = tmp.cuenta
               AND al_prev.nromedidor = tmp.medidor
               AND (al_prev.anio < EXTRACT(YEAR FROM CURRENT_DATE)
                   OR (al_prev.anio = EXTRACT(YEAR FROM CURRENT_DATE)
                       AND al_prev.mes < EXTRACT(MONTH FROM CURRENT_DATE)))
             ORDER BY al_prev.anio DESC, al_prev.mes DESC
             LIMIT 1),
            0
        ), 0)
    FROM temp_actualizar tmp
    WHERE al.numcuenta = tmp.cuenta
      AND al.nromedidor = tmp.medidor
      AND EXTRACT(MONTH FROM CURRENT_DATE) = al.mes
      AND EXTRACT(YEAR FROM CURRENT_DATE) = al.anio;

    -- Insertar nuevos registros en aapplectura desde la tabla temporal temp_insertar
    INSERT INTO aapplectura (numcuenta, anio, mes, lectura, observacion, lecturaanterior, consumo, nromedidor, ciu)
    SELECT
        tmp.cuenta,
        EXTRACT(YEAR FROM CURRENT_DATE) AS anio,
        EXTRACT(MONTH FROM CURRENT_DATE) AS mes,
        tmp.lectura::INTEGER,
        tmp.observacion,
        COALESCE(
            (SELECT al_prev.lectura
             FROM aapplectura al_prev
             WHERE al_prev.numcuenta = tmp.cuenta
               AND al_prev.nromedidor = tmp.medidor
               AND (al_prev.anio < EXTRACT(YEAR FROM CURRENT_DATE)
                   OR (al_prev.anio = EXTRACT(YEAR FROM CURRENT_DATE)
                       AND al_prev.mes < EXTRACT(MONTH FROM CURRENT_DATE)))
             ORDER BY al_prev.anio DESC, al_prev.mes DESC
             LIMIT 1),
            0
        ) AS lecturaanterior,
        GREATEST(tmp.lectura::INTEGER - COALESCE(
            (SELECT al_prev.lectura
             FROM aapplectura al_prev
             WHERE al_prev.numcuenta = tmp.cuenta
               AND al_prev.nromedidor = tmp.medidor
               AND (al_prev.anio < EXTRACT(YEAR FROM CURRENT_DATE)
                   OR (al_prev.anio = EXTRACT(YEAR FROM CURRENT_DATE)
                       AND al_prev.mes < EXTRACT(MONTH FROM CURRENT_DATE)))
             ORDER BY al_prev.anio DESC, al_prev.mes DESC
             LIMIT 1),
            0
        ), 0) AS consumo,
        tmp.medidor,
        (SELECT ci.numide_d FROM vct002 ci WHERE ci.Nombre || ' ' || ci.Apellido = tmp.abonado) -- Obtener el id del ciudadano
    FROM temp_insertar tmp;

    -- Ajustar la secuencia del id después de insertar nuevos registros
    SELECT MAX(id) INTO max_id FROM aapplectura;
    IF max_id IS NOT NULL THEN
        PERFORM setval('aapplectura_id_seq', max_id + 1);
    END IF;

    -- Eliminar las tablas temporales
    DROP TABLE IF EXISTS temp_actualizar;
    DROP TABLE IF EXISTS temp_insertar;
END;
$$ LANGUAGE plpgsql;


-- Eliminar el tipo compuesto si ya existe
DROP TYPE IF EXISTS tipo_lectura;

-- Crear el tipo compuesto tipo_lectura con las nuevas columnas
CREATE TYPE tipo_lectura AS (
    numcuenta VARCHAR(255),
    no_medidor VARCHAR(255),
    clave VARCHAR(255),
    lectura VARCHAR(10),
    observacion TEXT,
    coordenadasXYZ TEXT,
    motivo TEXT,   -- Nueva columna para motivo
    imagen BYTEA,  -- Nueva columna para imagen
    fecha_actualizacion TIMESTAMP   -- Nueva columna para fecha de actualización
);

-- Modificar el procedimiento almacenado SincronizarLecturasMasivas
CREATE OR REPLACE PROCEDURE SincronizarLecturasMasivas(
    p_login_usuario VARCHAR(255),
    p_lecturas tipo_lectura[]
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_lectura tipo_lectura;
    v_anio INTEGER;
    v_mes INTEGER;
    v_lectura_anterior VARCHAR(10);
    v_consumo INTEGER;
    v_abonado VARCHAR(255);
    v_direccion VARCHAR(255);
    v_ruta VARCHAR(255);
BEGIN
    -- Obtener año y mes actuales
    SELECT EXTRACT(YEAR FROM NOW()), EXTRACT(MONTH FROM NOW())
    INTO v_anio, v_mes;

    -- Loop a través del array de lecturas
    FOREACH v_lectura IN ARRAY p_lecturas
    LOOP
        -- Obtener la ruta de la cuenta y verificar si está asignada al usuario
        SELECT a.ruta
        INTO v_ruta
        FROM aappcometidas a
        INNER JOIN aapplectorruta apl ON a.ruta = apl.ruta
        WHERE apl.login = p_login_usuario AND a.numcuenta = v_lectura.numcuenta
        LIMIT 1;
        
        -- Si no se encuentra la ruta o no está asignada al usuario, saltar a la siguiente iteración
        IF v_ruta IS NULL THEN
            CONTINUE;
        END IF;

        -- Obtener la lectura anterior y otros datos (con manejo de nulos) desde aappmovillectura
        SELECT lectura, abonado, direccion
        INTO v_lectura_anterior, v_abonado, v_direccion
        FROM aappmovillectura
        WHERE cuenta = v_lectura.numcuenta
        ORDER BY id DESC
        LIMIT 1;

        -- Calcular consumo SOLO si hay lectura anterior y es un valor numérico
        IF v_lectura_anterior IS NOT NULL AND v_lectura_anterior ~ '^[0-9]+$' THEN
            v_consumo := v_lectura.lectura::INTEGER - v_lectura_anterior::INTEGER;
        ELSE
            v_consumo := 0;
        END IF;

        -- Verificar si ya existe una lectura para el mes y año actual
        IF EXISTS (
            SELECT 1
            FROM aappmovillectura
            WHERE cuenta = v_lectura.numcuenta
              AND EXTRACT(YEAR FROM fecha_hora_registro) = v_anio
              AND EXTRACT(MONTH FROM fecha_hora_registro) = v_mes
        ) THEN
            -- Actualizar la lectura existente (sin cambiar la dirección)
            UPDATE aappmovillectura
            SET lectura = v_lectura.lectura,
                observacion = v_lectura.observacion,
                coordenadasXYZ = v_lectura.coordenadasXYZ,
                motivo = COALESCE(v_lectura.motivo, motivo),
                imagen = COALESCE(v_lectura.imagen, imagen),
                fecha_hora_edicion = v_lectura.fecha_actualizacion
            WHERE cuenta = v_lectura.numcuenta
              AND EXTRACT(YEAR FROM fecha_hora_registro) = v_anio
              AND EXTRACT(MONTH FROM fecha_hora_registro) = v_mes;
        ELSE
            -- Insertar una nueva lectura (manteniendo la dirección y abonado)
            INSERT INTO aappmovillectura (cuenta, medidor, clave, abonado, lectura, observacion, coordenadasXYZ, direccion, motivo, imagen, fecha_hora_registro)
            VALUES (v_lectura.numcuenta, v_lectura.no_medidor, v_lectura.clave, v_abonado, v_lectura.lectura, v_lectura.observacion, v_lectura.coordenadasXYZ, v_direccion, v_lectura.motivo, v_lectura.imagen, CURRENT_TIMESTAMP);
        END IF;
    END LOOP;
END;
$$;


CREATE OR REPLACE FUNCTION actualizar_lectorruta(
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

-- Procedimiento para asignar o actualizar una ruta a un usuario por login y id de la ruta
CREATE OR REPLACE FUNCTION AsignarRutaAUsuario(
    p_login VARCHAR(255),
    p_route_id INTEGER
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
        -- Asignar la ruta al usuario
        INSERT INTO aapplectorruta (login, ruta, anio, mes, fechatoma, fecha, lector)
        VALUES (p_login, route_name, EXTRACT(YEAR FROM CURRENT_DATE), EXTRACT(MONTH FROM CURRENT_DATE), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, p_login);
        mensaje := format('Ruta %s asignada correctamente al usuario %s.', route_name, user_name);
    END IF;

    RETURN mensaje;
END;
$$ LANGUAGE plpgsql;

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



-- Función para obtener información de acometidas relacionadas con el login del usuario
CREATE OR REPLACE FUNCTION RutaLecturaMovil(p_login VARCHAR(255))
RETURNS TABLE (
    id_ruta INTEGER,
    numcuenta VARCHAR(255),
    no_medidor VARCHAR(255),
    clave VARCHAR(255),
    ruta VARCHAR(255),
    direccion VARCHAR(255),
    abonado VARCHAR(255)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        b.id AS id_ruta,
        a.numcuenta,
        a.no_medidor,
        a.clave,
        a.ruta,
        a.direccion,
        COALESCE(
            (SELECT CONCAT(ciud.Nombre, ' ', ciud.Apellido)::VARCHAR
             FROM aapplectura aplect
             INNER JOIN vct002 ciud ON aplect.ciu = ciud.numide_d AND aplect.numcuenta = a.numcuenta
             LIMIT 1),
            (SELECT appmov.abonado::VARCHAR 
             FROM aappMovilLectura appmov
             WHERE appmov.cuenta = a.numcuenta
             LIMIT 1)
        ) AS abonado
    FROM aappcometidas a
    INNER JOIN aapplectorruta apl ON a.ruta = apl.ruta
    INNER JOIN csebase1 usu ON apl.login = usu.login
    INNER JOIN aappbario b ON apl.ruta = b.nombre
    WHERE apl.login = p_login; 
END;
$$ LANGUAGE plpgsql;

-- Función para obtener los datos de lectorruta
CREATE OR REPLACE FUNCTION obtener_datos_lectorruta()
RETURNS TABLE(
    login_usuario VARCHAR,
    nombre_usuario VARCHAR,
    id_ruta INT,
    nombre_ruta VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cl.login AS login_usuario,
        (cl.nombre || ' ' || cl.apellido)::VARCHAR AS nombre_usuario,  -- Concatena nombre y apellido y convierte a VARCHAR
        ar.id AS id_ruta,
        ar.nombre AS nombre_ruta
    FROM 
        aapplectorruta alr
    JOIN 
        csebase1 cl ON alr.login = cl.login
    JOIN 
        aappbario ar ON alr.ruta = ar.nombre;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener todas las rutas
CREATE OR REPLACE FUNCTION ObtenerRutas()
RETURNS TABLE (
    id INTEGER,
    nombreruta VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT r.id, r.nombre
    FROM aappbario r;
END;
$$ LANGUAGE plpgsql;


-- Función para obtener todos los usuarios
CREATE OR REPLACE FUNCTION ObtenerUsuarios()
RETURNS TABLE (
    login VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT u.login 
    FROM csebase1 u;
END;
$$ LANGUAGE plpgsql;


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
