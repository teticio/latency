FROM python:3.8-slim
COPY 1-fastapi-ec2/src .
COPY common common
RUN pip install -r requirements.txt
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host=0.0.0.0"]
