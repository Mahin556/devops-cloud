FROM python:3.14-alpine

WORKDIR /app

# Copy the requirements file into the container
COPY requirements.txt .

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copy the current directory contents into the container at /app
COPY app.py .

# Expose port 5000, which Flask runs on by default
EXPOSE 5000

#Run as non-root user
RUN addgroup worker && adduser -D -u 1000 -G worker worker
RUN chown -R worker:worker /app
USER worker

#Run the Flask application
CMD ["python", "app.py"]