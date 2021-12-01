FROM python:3.8
COPY 1-fastapi-ec2/src /src
COPY common /common
RUN pip install -r src/requirements.txt
CMD uvicorn src.main:app --host=0.0.0.0
EXPOSE 8000
