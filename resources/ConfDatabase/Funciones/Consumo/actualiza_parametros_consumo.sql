CREATE OR REPLACE FUNCTION actualizar_parametros_consumo(
    nuevo_limite_promedio INTEGER,
    nuevo_rango_unidades NUMERIC
) RETURNS VOID AS $$
BEGIN
    -- Validaciones
    IF nuevo_limite_promedio <= 0 THEN
        RAISE EXCEPTION 'El límite de promedio debe ser un número positivo';
    END IF;

    IF nuevo_rango_unidades <= 0 THEN
        RAISE EXCEPTION 'El rango de unidades debe ser un número positivo';
    END IF;

    -- Insertar nuevos valores
    INSERT INTO parametros_consumo (limite_promedio, rango_unidades)
    VALUES (nuevo_limite_promedio, nuevo_rango_unidades);

    -- Opcionalmente, mantener solo un número limitado de registros históricos
    DELETE FROM parametros_consumo
    WHERE id NOT IN (
        SELECT id
        FROM parametros_consumo
        ORDER BY fecha_actualizacion DESC
        LIMIT 10
    );

    RAISE NOTICE 'Parámetros de consumo actualizados correctamente.';
END;
$$ LANGUAGE plpgsql;