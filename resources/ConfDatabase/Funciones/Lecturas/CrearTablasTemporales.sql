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
