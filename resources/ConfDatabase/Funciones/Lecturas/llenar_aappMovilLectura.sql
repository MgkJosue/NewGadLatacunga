CREATE OR REPLACE FUNCTION llenar_aappMovilLectura(
    p_cuenta VARCHAR(20),
    p_lectura VARCHAR(10),
    p_observacion TEXT
) RETURNS TEXT AS $$
DECLARE
    v_medidor VARCHAR(20);
    v_clave VARCHAR(20);
    v_abonado VARCHAR(100);
    v_direccion VARCHAR(255);
    v_existe BOOLEAN;
    v_mensaje TEXT;
BEGIN
    -- Comprobar si la cuenta existe en aappcometidas
    SELECT EXISTS(SELECT 1 FROM aappcometidas WHERE numcuenta = p_cuenta) INTO v_existe;
    
    IF NOT v_existe THEN
        -- Si la cuenta no existe, devolver un mensaje
        RETURN 'La cuenta ' || p_cuenta || ' no existe en aappcometidas.';
    END IF;

    -- Comprobar si la cuenta ya existe en aappMovilLectura
    SELECT EXISTS(SELECT 1 FROM aappMovilLectura WHERE cuenta = p_cuenta) INTO v_existe;
    
    IF v_existe THEN
        -- Si el registro ya existe, devolver un mensaje
        RETURN 'El registro para la cuenta ' || p_cuenta || ' ya existe en aappMovilLectura. No se realizaron cambios.';
    END IF;

    -- Obtener información de aappcometidas
    SELECT no_medidor, clave, direccion
    INTO v_medidor, v_clave, v_direccion
    FROM aappcometidas
    WHERE numcuenta = p_cuenta;

    -- Verificar si se encontraron los datos básicos
    IF v_medidor IS NULL OR v_clave IS NULL OR v_direccion IS NULL THEN
        RETURN 'No se encontraron todos los datos necesarios para la cuenta ' || p_cuenta || ' en aappcometidas.';
    END IF;

    -- Buscar el abonado en vct002 basado en la dirección
    SELECT CONCAT(Nombre, ' ', Apellido)
    INTO v_abonado
    FROM vct002
    WHERE Direccion = v_direccion
    LIMIT 1;

    -- Si no se encuentra un abonado, establecer como 'Abonado no identificado'
    IF v_abonado IS NULL THEN
        v_abonado := 'Abonado no identificado';
    END IF;

    -- Insertar nuevo registro en aappMovilLectura
    INSERT INTO aappMovilLectura (
        cuenta, 
        medidor, 
        clave, 
        abonado, 
        lectura, 
        observacion,
        coordenadasXYZ, 
        direccion
    ) VALUES (
        p_cuenta,
        v_medidor,
        v_clave,
        v_abonado,
        p_lectura,
        p_observacion,
        '0.0.0,0.0.0,0.0.0',
        v_direccion
    );

    RETURN 'Se ha insertado un nuevo registro para la cuenta ' || p_cuenta || '.';
END;
$$ LANGUAGE plpgsql;