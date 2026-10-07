```bash
docker build -t python-rest-api .
```
```bash
docker tag python-rest-api mahinraza556/python-rest-api
docker login
docker push mahinraza556/python-rest-api
```
```bash
docker run -p 9001:9001 mahinraza556/python-rest-api
```