--Probar sp Validar_usuario
SELECT validar_usuario('usuario1', 'contrasena1');

--Probar sp UsuarioRutaSp
-- Obtener la ruta asignada a ese id del usuario 
SELECT * FROM UsuarioRuta(1); 

--Probar SpRutaLecturaMovilz
-- Obtener informacion de acometidas relacionadas con id del usuario
SELECT * FROM RutaLecturaMovil(1);

--Probar spSincronizarLecturas
-- Probar SincronizarLecturasMasivas
DO $$
DECLARE
    lecturas tipo_lectura[];
BEGIN
    lecturas := ARRAY[
        -- Caso sin motivo e imagen (dejar NULL)
        ROW('12345', 'M12345', 'CLAVE123', '500', 'Observación de prueba 1', '-78.5243, -0.2293, 1234', NULL, NULL)::tipo_lectura,
        
        -- Caso con motivo y sin imagen
        ROW('67890', 'M67890', 'CLAVE678', '600', 'Observación de prueba 2', '-78.5243, -0.2293, 1234', 'Motivo de prueba 1', NULL)::tipo_lectura
        
        -- Caso con motivo e imagen (proporciona una imagen en formato binario)
        --GRANT EXECUTE ON FUNCTION pg_read_binary_file TO tu_usuario;
      --  ROW('54321', 'M54321', 'CLAVE543', '700', 'Observación de prueba 3', '-78.5243, -0.2293, 1234', 'Motivo de prueba 2', pg_read_binary_file('/ruta/a/la/imagen.png'))::tipo_lectura
    ];

    CALL SincronizarLecturasMasivas(1, lecturas);
END $$;


--Funcion para obtenerUsuarios
SELECT * FROM ObtenerUsuarios();

--Funcion para obtenerRutas
SELECT * FROM ObtenerRutas();

-- Asignar la ruta con ID 1 al usuario con ID 5
SELECT AsignarRutaAUsuario(1, 4);


--Obtener los datos de la tabla aapplectorruta junto con el nombre de usuario y el nombre de la ruta
SELECT * FROM obtener_datos_lectorruta();

--Eliminar la asignación de la ruta con ID 1 a la tabla aapplectorruta
SELECT eliminar_lectorruta(1);

--Obtener los datos de la ID Lector Ruta 1
SELECT * FROM  obtener_lectorruta(1);


-- Para ejecutar el procedimiento almacenado
SELECT copiar_registros_a_evidencia();



--AUN NO IMPLEMENTADO 
--Tabalas temporales entre appmovillecturas y tabla lecturas 
SELECT crear_tablas_temporales();

--Actualizar e insertar lecturas en la tabla aapplectura desde la tabla temporal
SELECT actualizar_insertar_lecturas();

-- Verificar actualizaciones en aapplectura
SELECT * FROM aapplectura WHERE numcuenta IN ('12345', '67890');

-- Verificar inserciones en aapplectura
SELECT * FROM aapplectura WHERE numcuenta = '11111';


