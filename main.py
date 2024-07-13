from fastapi import FastAPI
from database import database
from routers import auth, usuario, ruta, lectura
from sqlalchemy.exc import SQLAlchemyError
from fastapi.responses import JSONResponse

app = FastAPI()

@app.on_event("startup")
async def startup():
    await database.connect()

@app.on_event("shutdown")
async def shutdown():
    await database.disconnect()

@app.exception_handler(SQLAlchemyError)
async def sqlalchemy_exception_handler(request, exc: SQLAlchemyError):
    error_message = "Error en la base de datos"  
    return JSONResponse(
        status_code=500,
        content={"detail": error_message},
    )

app.include_router(auth.router)
app.include_router(usuario.router)
app.include_router(ruta.router)
app.include_router(lectura.router)