FROM python:3.9-slim

ENV INSTANCE_NAME="DEV"

COPY requirements.txt .
RUN pip install -r requirements.txt

WORKDIR /app
EXPOSE 5000

CMD python chatsecure/models.py && python main.py
