from pydantic import BaseModel
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