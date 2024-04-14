ARG RABBITMQ_USERNAME
ARG RABBITMQ_PASSWORD
FROM python:3.10-alpine
WORKDIR /app
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt
COPY calc.py calc.py
ENV RABBITMQ_USERNAME=$RABBITMQ_USERNAME
ENV RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD
CMD ["python", "./calc.py"]
