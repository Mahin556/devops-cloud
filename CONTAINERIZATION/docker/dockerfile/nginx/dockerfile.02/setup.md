```bash
docker build -t nginx-health .

docker run -d --name health-nginx -p 80:80 nginx-health

docker exec health-nginx ps aux
```

## Check health status
```bash
docker ps

docker inspect health-nginx | grep -A 5 Health
```

## Simulate failure (stop nginx inside container)
```bash
docker exec health-nginx nginx -s stop
# Wait and check status again
```