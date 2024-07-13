from pydantic import BaseModel
from typing import Optional

class LoginCredentials(BaseModel):
    nombre_usuario: str
    contrasena: str

class UsuarioRutaResult(BaseModel):
    nombre_ruta: str
    nombre_usuario: str
    id_usuario: int
    id_ruta: int

class RutaLecturaMovilResult(BaseModel):
    id_usuario: int
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

class Token(BaseModel):
    access_token: str
    token_type: str
    user_id: int


class AsignarRuta(BaseModel):
    ruta_id: int
    usuario_id: int


class LectorRutaDetail(BaseModel):
    id: int
    idusuario: int
    idruta: int
    nombre_usuario: str
    nombre_ruta: str

class ActualizarLectorRuta(BaseModel):
    usuario_id: int
    ruta_id: int