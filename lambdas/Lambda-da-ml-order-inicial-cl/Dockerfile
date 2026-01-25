FROM public.ecr.aws/lambda/python:3.12

COPY requirements.txt .
RUN pip install --no-cache-dir --prefer-binary -r requirements.txt

COPY src/ ${LAMBDA_TASK_ROOT}

CMD ["lambda_function.lambda_handler"]
