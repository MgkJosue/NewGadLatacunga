--Probar sp Validar_usuario
SELECT validar_usuario('usuario1', 'contrasena1');

--Probar sp UsuarioRutaSp
-- Obtener informacion de rutas relacionadas con loguin del usuario
SELECT * FROM UsuarioRuta('jalvarez'); 

--Probar SpRutaLecturaMovilz
-- Obtener informacion de rutas relacionadas con loguin del usuario
SELECT * FROM RutaLecturaMovil('jalvarez');

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

    CALL SincronizarLecturasMasivas('jalvarez', lecturas);
END $$;


--Funcion para obtenerUsuarios
SELECT * FROM ObtenerUsuarios();

--Funcion para obtenerRutas
SELECT * FROM ObtenerRutas();

-- Asignar la ruta con ID a  usuario logueado
SELECT AsignarRutaAUsuario('jalvarez', 4);


--Obtener los datos de la tabla aapplectorruta junto con el nombre de usuario y el nombre de la ruta
SELECT * FROM obtener_datos_lectorruta();

--Eliminar los datos de la tabla aapplectorruta
SELECT eliminar_lectorruta('jalvarez', 1);

--Obtener los datos de la tabla aapplectorruta junto con el nombre de usuario y el nombre de la ruta
SELECT * FROM  obtener_lectorruta('jalvarez', 2);


-- Para ejecutar el procedimiento almacenado
SELECT copiar_registros_a_evidencia();

--Tabalas temporales entre appmovillecturas y tabla lecturas 
SELECT crear_tablas_temporales();

--Actualizar e insertar lecturas en la tabla aapplectura desde la tabla temporal
SELECT actualizar_insertar_lecturas();

-- Llamar al procedimiento almacenado sin parámetros para utilizar los valores por defecto
SELECT * FROM obtener_datos_consumo();

-- Llamar al procedimiento almacenado con parámetros específicos
SELECT * FROM obtener_datos_consumo('2024-06-30', 10, 1.5);


--Funcion para poder editar la lectura movil
SELECT editar_lectura_movil('11111', '225', 'Lectura corregida', 'Cambio de medidor');

--Funcion para poder eliminar la lectura movil
SELECT eliminar_lectura_movil('33333');
