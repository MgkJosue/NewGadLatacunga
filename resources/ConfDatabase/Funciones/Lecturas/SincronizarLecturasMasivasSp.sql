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
