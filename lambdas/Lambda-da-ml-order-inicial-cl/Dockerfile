FROM public.ecr.aws/lambda/python:3.12

# Install system dependencies
RUN yum install -y gcc gcc-c++ make && yum clean all

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy Lambda function code
COPY lambda_function.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD ["lambda_function.handler"]