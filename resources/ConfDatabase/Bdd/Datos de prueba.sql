-- Insertar datos en la tabla csebase1 (equivalente a usuarios)
INSERT INTO csebase1 (login, nombre, apellido, clave) VALUES
('jalvarez', 'Josue', 'Alvarez', 'jalvarez'),
('igalarza', 'Israel', 'Galarza', 'igalarza');
('admin', 'Israel', 'Galarza', 'admin');

-- Insertar datos en la tabla aappbario (equivalente a aappruta)
INSERT INTO aappbario (nombre) VALUES
('Ruta Norte'),
('Ruta Sur'),
('Ruta Este'),
('Ruta Oeste'),
('Ruta Centro'),
('Ruta Periférica');

-- Insertar datos en la tabla vct002 (equivalente a ciudadano)
INSERT INTO vct002 (Nombre, Apellido, Direccion) VALUES
('Juan', 'Pérez', 'Calle Principal 123'),
('María', 'Gómez', 'Avenida Central 456'),
('Carlos', 'Rodríguez', 'Calle Secundaria 789'),
('Ana', 'López', 'Avenida Libertad 101'),
('Luis', 'Martínez', 'Plaza Mayor 222'),
('Laura', 'Sánchez', 'Calle Rural 333'),
('Pedro', 'Sánchez', 'Calle Nueva 111');

-- Insertar datos en la tabla aapplectorruta (nuevo formato)
INSERT INTO aapplectorruta (anio, mes, ruta, fechatoma, fecha, login, lector) VALUES
(2024, 1, 'Ruta Norte', '2024-01-01 00:00:00', '2024-01-01 00:00:00', 'jalvarez', 'Lector 1'),
(2024, 1, 'Ruta Este', '2024-01-01 00:00:00', '2024-01-01 00:00:00', 'jalvarez', 'Lector 1'),
(2024, 1, 'Ruta Sur', '2024-01-01 00:00:00', '2024-01-01 00:00:00', 'igalarza', 'Lector 2'),
(2024, 1, 'Ruta Oeste', '2024-01-01 00:00:00', '2024-01-01 00:00:00', 'igalarza', 'Lector 2');

-- Insertar datos en la tabla aappcometidas (equivalente a acometidas)
INSERT INTO aappcometidas (numcuenta, no_medidor, clave, ruta, direccion) VALUES
('12345', 'M12345', 'CLAVE123', 'Ruta Norte', 'Calle Principal 123'),
('67890', 'M67890', 'CLAVE678', 'Ruta Norte', 'Avenida Central 456'),
('54321', 'M54321', 'CLAVE543', 'Ruta Sur', 'Calle Secundaria 789'),
('98765', 'M98765', 'CLAVE987', 'Ruta Sur', 'Avenida Libertad 101'),
('24680', 'M24680', 'CLAVE246', 'Ruta Centro', 'Plaza Mayor 222'),
('13579', 'M13579', 'CLAVE135', 'Ruta Periférica', 'Calle Rural 333'),
('11111', 'M11111', 'CLAVE111', 'Ruta Este', 'Calle Nueva 111');

-- Insertar datos en la tabla aapplectura (igual que antes, solo cambiaron nombres de columnas)
INSERT INTO aapplectura (numcuenta, anio, mes, lectura, observacion, lecturaanterior, consumo, nromedidor, ciu) VALUES
('12345', 2024, 1, 200, 'Sin observaciones', 190, 10, 'M12345', 1),
('12345', 2024, 2, 210, 'Sin observaciones', 200, 10, 'M12345', 1),
('12345', 2024, 3, 220, 'Sin observaciones', 210, 10, 'M12345', 1),
('67890', 2024, 1, 500, 'Sin observaciones', 490, 10, 'M67890', 2),
('67890', 2024, 2, 510, 'Sin observaciones', 500, 10, 'M67890', 2),
('24680', 2024, 1, 400, 'Sin observaciones', 390, 10, 'M24680', 3),
('24680', 2024, 2, 410, 'Sin observaciones', 400, 10, 'M24680', 3),
('54321', 2024, 1, 150, 'Sin observaciones', 140, 10, 'M54321', 3),
('54321', 2024, 2, 160, 'Sin observaciones', 150, 10, 'M54321', 3),
('98765', 2024, 1, 300, 'Sin observaciones', 290, 10, 'M98765', 4),
('98765', 2024, 2, 310, 'Sin observaciones', 300, 10, 'M98765', 4),
('13579', 2024, 1, 250, 'Sin observaciones', 240, 10, 'M13579', 6),
('13579', 2024, 2, 260, 'Sin observaciones', 250, 10, 'M13579', 6);

-- Insertar datos en la tabla aapMovilLectura (igual que antes)
INSERT INTO aappMovilLectura (cuenta, medidor, clave, abonado, lectura, observacion, coordenadasXYZ, direccion) VALUES
('12345', 'M12345', 'CLAVE123', 'Juan Pérez', '1234', 'Sin novedad', '-0.945758,-78.619934,2850', 'Calle Principal 123'),
('67890', 'M67890', 'CLAVE678', 'María Gómez', '5678', 'Fuga detectada', '-0.945758,-78.619934,2850', 'Avenida Central 456'),
('54321', 'M54321', 'CLAVE543', 'Carlos Rodríguez', '9012', 'Sin novedad', '-0.945758,-78.619934,2850', 'Calle Secundaria 789'),
('98765', 'M98765', 'CLAVE987', 'Ana López', '3456', 'Medidor dañado', '-0.945758,-78.619934,2850', 'Avenida Libertad 101'),
('24680', 'M24680', 'CLAVE246', 'Luis Martínez', '7890', 'Sin novedad', '-0.945758,-78.619934,2850', 'Plaza Mayor 222'),
('13579', 'M13579', 'CLAVE135', 'Laura Sánchez', '2345', 'Sin novedad', '-0.945758,-78.619934,2850', 'Calle Rural 333'),
('11111', 'M11111', 'CLAVE111', 'Pedro Sánchez', '1000', 'Nueva lectura', '-0.945758,-78.619934,2850', 'Calle Nueva 111'); --no esta en la tabla aapplectura


-- Insertar nuevos registros en la tabla aapMovilLectura
INSERT INTO aappMovilLectura (cuenta, medidor, clave, abonado, lectura, observacion, coordenadasXYZ, direccion) VALUES
('22222', 'M22222', 'CLAVE222', 'Pedro Sánchez', '4567', 'Sin novedad', '-0.123456,-78.654321,1500', 'Calle Nueva 222'),
('33333', 'M33333', 'CLAVE333', 'Juan Pérez', '7890', 'Lectura alta', '-0.654321,-78.123456,1500', 'Calle Principal 789');