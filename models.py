from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class LoginCredentials(BaseModel):
    nombre_usuario: str
    contrasena: str

class UsuarioRutaResult(BaseModel):
    nombre_ruta: str
    login: str
    id_ruta: int

class RutaLecturaMovilResult(BaseModel):
    id_ruta: int
    numcuenta: str
    no_medidor: str
    clave: str
    ruta: str
    direccion: str
    abonado: str

class Lectura(BaseModel):
    numcuenta: str
    no_medidor: str
    clave: str
    lectura: Optional[str] = None
    observacion: str
    coordenadas: str
    motivo: Optional[str] = None
    imagen_ruta: Optional[str] = None
    fecha_actualizacion: Optional[datetime] = None 

class Token(BaseModel):
    access_token: str
    token_type: str
    username: str 


class Ruta(BaseModel):
    ruta_id: int
    username: str

class LectorRutaDetail(BaseModel):
    login_usuario: str
    nombre_usuario: str
    id_ruta: int
    nombre_ruta: str


class ActualizarLectorRuta(BaseModel):
    new_username: str
    new_id_ruta: int


class DatosConsumoRequest(BaseModel):
    fecha_consulta: Optional[str] = Field(None, description="Fecha de consulta en formato 'YYYY-MM-DD'. Por defecto, se utiliza la fecha actual.")
    limite_registros: Optional[int] = Field(None, description="Número máximo de registros a devolver. Por defecto, no hay límite.")
    rango_unidades: Optional[float] = Field(2, description="Rango de unidades para calcular los límites superior e inferior del consumo promedio. Por defecto, se utiliza 2.")