import databases
import sqlalchemy


#DATABASE_URL = "postgresql://tu_usuario:tu_contraseña@tu_host:tu_puerto/tu_base_datos"
#DATABASE_URL = "postgresql://postgres:admin@localhost/conceptGadLatacunga"
DATABASE_URL = "postgresql://gadlatacunga_user:AYfb6yUuNyWQlvovNzyu8kpJsXrJlKYC@dpg-cq3cahaju9rs739c7jj0-a.oregon-postgres.render.com/gadlatacunga"

database = databases.Database(DATABASE_URL)
metadata = sqlalchemy.MetaData()
engine = sqlalchemy.create_engine(DATABASE_URL)
