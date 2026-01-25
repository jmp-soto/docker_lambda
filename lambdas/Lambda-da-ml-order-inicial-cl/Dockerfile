FROM public.ecr.aws/lambda/python:3.12

# Amazon Linux 2023 usa microdnf, NO yum
# Instalar dependencias del sistema
RUN microdnf install -y gcc gcc-c++ make && microdnf clean all

# Copiar requirements.txt desde src/
COPY src/requirements.txt .

# Instalar dependencias de Python
RUN pip install --no-cache-dir -r requirements.txt

# Copiar código Lambda desde src/
COPY src/lambda_function.py ${LAMBDA_TASK_ROOT}

# Establecer el handler
CMD ["lambda_function.handler"]