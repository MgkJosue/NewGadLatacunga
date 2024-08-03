import databases
import sqlalchemy


#DATABASE_URL = "postgresql://tu_usuario:tu_contraseña@tu_host:tu_puerto/tu_base_datos"
DATABASE_URL = "postgresql://gadlatacunga_o8sn_user:pAluIuU68P2WcAwQHhf7QTfoMZTGipbb@dpg-cqn6qjdds78s73997jf0-a.oregon-postgres.render.com/gadlatacunga_o8sn"
#DATABASE_URL = "postgresql://postgres:admin@localhost/newConceptGadLatacunga"


database = databases.Database(DATABASE_URL)
metadata = sqlalchemy.MetaData()
engine = sqlalchemy.create_engine(DATABASE_URL)
