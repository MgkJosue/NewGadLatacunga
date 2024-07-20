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