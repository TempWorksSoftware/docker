# build container
docker build -t tempworks/redis-server:3.2.100-windowsservercore-1709 -f redis.dockerfile .

# push to docker hub
docker push tempworks/redis-server:3.2.100-windowsservercore-1709


-----------------

# run container
docker run -d --name redis -p 6379:6379 -t tempworks/redis-server:3.2.100-windowsservercore-1709
