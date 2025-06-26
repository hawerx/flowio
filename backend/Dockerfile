# Usamos una imagen base de Python oficial
FROM python:3.10-slim

# Establecemos el directorio de trabajo dentro del contenedor
WORKDIR /code

# Copiamos el fichero de requisitos primero para aprovechar el cacheo de Docker
COPY ./requirements.txt /code/requirements.txt

# Instalamos las dependencias de Python
# --no-cache-dir para mantener la imagen ligera
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

# Copiamos el resto del código de la aplicación
COPY ./main.py /code/main.py

# Exponemos el puerto en el que correrá nuestra aplicación FastAPI
# Hugging Face Spaces suele usar el puerto 7860 por defecto
EXPOSE 7860

# El comando para iniciar la aplicación cuando se lance el contenedor
# Usamos --host 0.0.0.0 para que sea accesible desde fuera del contenedor
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]