```dockerfile
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
```
```bash
docker build -t small-docker-base-image . -f -<<EOF
FROM python:3.14-alpine

WORKDIR /app

# Copy the requirements file into the container
# COPY requirements.txt .

# Install any needed packages specified in requirements.txt
# RUN pip install --no-cache-dir -r requirements.txt

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
EOF

kind load docker-image small-docker-base-image --name my-cluster
```
```bash
kubectl apply -f -<<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod-1
spec:
  containers:
    - name: app
      image: small-docker-base-image
      imagePullPolicy: Never
EOF

kubectl delete pod secure-pod-1
```
```bash
kubectl get po secure-pod-1
kubectl exec -it secure-pod-1 --  bash #not available
kubectl exec -it secure-pod-1 --  sh #available
kubectl exec -it secure-pod-1 --  which curl #not available
kubectl exec -it secure-pod-1 --  which wget #available
```