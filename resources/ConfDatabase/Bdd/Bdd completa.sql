-- TABLAS DEL MUNICIPIO

-- Crear la nueva tabla csebase1 HACE REFERENCIA A LA TABLA USUARIOS
CREATE TABLE csebase1 (
    login VARCHAR(255) UNIQUE NOT NULL,
    nombre VARCHAR(255) NOT NULL,
    apellido VARCHAR(255) NOT NULL,
    clave VARCHAR(255) NOT NULL
);


-- Crear la tabla de rutas HACE REFERENCIA A LA TABLA AAPPRUTA
CREATE TABLE aappbario(
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(255) NOT NULL
);


-- Crear la nueva tabla vct002 HACE REFERENCIA A LA TABLA CIUDADANO
CREATE TABLE vct002 (
    numide_d SERIAL PRIMARY KEY,
    Nombre VARCHAR(255) NOT NULL,
    Apellido VARCHAR(255) NOT NULL,
    Direccion VARCHAR(255) NOT NULL
);

-- Creartabla aapplectorruta  AQUI ME CAMBIARON LA LOGICA 
CREATE TABLE aapplectorruta (
    anio INTEGER NOT NULL,
    mes INTEGER NOT NULL,
    ruta VARCHAR(255) NOT NULL,
    fechatoma TIMESTAMP NOT NULL,
    fecha TIMESTAMP NOT NULL,
    login VARCHAR(255) NOT NULL,
    lector VARCHAR(255) NOT NULL
);

-- Crear la tabla de acometidas
CREATE TABLE aappcometidas (
    id SERIAL PRIMARY KEY,
    numcuenta VARCHAR(255) UNIQUE NOT NULL,
    no_medidor VARCHAR(255) UNIQUE NOT NULL,
    clave VARCHAR(255) UNIQUE NOT NULL,
    ruta VARCHAR(255) NOT NULL,
    direccion VARCHAR(255) UNIQUE NOT NULL
);

-- Crear la tabla de lecturas
CREATE TABLE aapplectura (
    id SERIAL PRIMARY KEY,
    numcuenta VARCHAR(255) NOT NULL,
    anio INTEGER NOT NULL,
    mes INTEGER NOT NULL,
    lectura INTEGER NOT NULL,
    observacion TEXT,
    lecturaanterior INTEGER NOT NULL,
    consumo INTEGER NOT NULL,
    nromedidor VARCHAR(255),
    ciu INTEGER NOT NULL
);


--TABLAS LOCALES NO ESTAN EN EL MUNICIPIO
-- Crear la tabla aapMovilLectura 
CREATE TABLE aappmovillectura (
    id SERIAL PRIMARY KEY,
    cuenta VARCHAR(20),
    medidor VARCHAR(20),
    clave VARCHAR(20),
    abonado VARCHAR(100),
    lectura VARCHAR(10),
    observacion TEXT,
    coordenadasXYZ VARCHAR(50),
    direccion VARCHAR(255),
    motivo TEXT,
    imagen BYTEA,
    fecha_hora_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_hora_edicion TIMESTAMP,
    modificado_por VARCHAR(50),
    creado_por VARCHAR(50)
);
-- MODIFICADO POR(LOGIN DEL QUE HACE LA EDICION) LA PERSONA QUE MDOFICA EL REGISTRO 



-- Crear la tabla aapEvidencia para la actualización de los datos de la tabla aapMovilLectura 
CREATE TABLE aappEvidencia (
    id SERIAL PRIMARY KEY,
    cuenta VARCHAR(20),
    medidor VARCHAR(20),
    clave VARCHAR(20),
    abonado VARCHAR(100),
    lectura VARCHAR(10),
    observacion TEXT,
    coordenadasXYZ VARCHAR(50),
    direccion VARCHAR(255),
    motivo TEXT,
    imagen BYTEA,
    fecha_hora_registro TIMESTAMP,
    fecha_hora_edicion TIMESTAMP,
    modificado_por VARCHAR(50),
    procesado_por VARCHAR(50),
    fecha_de_procesamiento TIMESTAMP,
    accion VARCHAR(20),
    CONSTRAINT unique_cuenta_medidor UNIQUE (cuenta, medidor)
);
-- MODIFICADO POR, PROCESADO POR, FECHA DE PROCESAMIENTO, ACCION(Eliminado)

CREATE TABLE IF NOT EXISTS temp_cambios_lectura (
    id SERIAL PRIMARY KEY,
    cuenta VARCHAR(20),
    medidor VARCHAR(20),
    accion VARCHAR(20),
    datos JSONB,
    modificado_por VARCHAR(50),
    fecha_modificacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE parametros_consumo (
    id SERIAL PRIMARY KEY,
    limite_promedio INTEGER NOT NULL,
    rango_unidades NUMERIC NOT NULL,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);