```
docker build -t mssql-linux:1.0 -f /Database/Dockerfile .
docker tag mssql-linux:1.0 ffatih/mssql-linux:1.0
docker push ffatih/mssql-linux:1.0

docker build -t applicants.api:1.0 -f Services/Applicants.Api/Dockerfile .
docker tag applicants.api:1.0 ffatih/applicants.api:1.0
docker push ffatih/applicants.api:1.0

docker build -t identity.api:1.0 -f Services/Identity.Api/Dockerfile .
docker tag identity.api:1.0 ffatih/identity.api:1.0
docker push ffatih/identity.api:1.0

docker build -t jobs.api:1.0 -f Services/Jobs.Api/Dockerfile .
docker tag jobs.api:1.0 ffatih/jobs.api:1.0
docker push ffatih/jobs.api:1.0

docker build -t web:1.0 -f Web/Dockerfile .
docker tag web:1.0 ffatih/web:1.0
docker push ffatih/web:1.0*
```
