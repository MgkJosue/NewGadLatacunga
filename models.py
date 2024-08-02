from pydantic import BaseModel, validator
from typing import Optional
from datetime import datetime, timedelta

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
    fecha: datetime

    @validator('fecha')
    def validar_fecha(cls, v):
        hoy = datetime.today().date()
        mañana = hoy + timedelta(days=1)
        if v.date() not in [hoy, mañana]:
            raise ValueError("La fecha debe ser la actual o la del próximo día.")
        return v

class LectorRutaDetail(BaseModel):
    login_usuario: str
    nombre_usuario: str
    id_ruta: int
    nombre_ruta: str
    fecha: datetime


class ActualizarLectorRuta(BaseModel):
    new_username: str
    new_id_ruta: int
    fecha: datetime

    @validator('fecha')
    def validar_fecha(cls, v):
        hoy = datetime.today().date()
        mañana = hoy + timedelta(days=1)
        if v.date() not in [hoy, mañana]:
            raise ValueError("La fecha debe ser la actual o la del próximo día.")
        return v


class LecturaRequest(BaseModel):
    nueva_lectura: str
    nueva_observacion: Optional[str] = None
    nuevo_motivo: Optional[str] = None


class WebLecturaRequest(BaseModel):
    cuenta: str
    lectura: str
    observacion: str