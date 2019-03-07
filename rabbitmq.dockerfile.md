
# build container
`docker build -t tempworks/rabbitmq:3.7.10-windowsservercore-1809 -f .\rabbitmq.dockerfile .`

# push to repository
`docker push tempworks/rabbitmq:3.7.10-windowsservercore-1809`

# run container
`docker run -d --name rabbitmq -p 4369:4369 -p 5671:5671 -p 5672:5672 -p 15672:15672 -t tempworks/rabbitmq:3.7.10-windowsservercore-1809`


-----------------

# enable management plugins

https://gist.github.com/yetanotherchris/c954d1e8b688845c2dcdb3b33c94b2d2

`docker exec -i rabbitmq powershell -Command 'rabbitmq-plugins enable rabbitmq_management'`

`docker exec -i rabbitmq powershell -Command 'rabbitmqctl add_user admin-user admin-user'`

`docker exec -i rabbitmq powershell -Command 'rabbitmqctl set_user_tags admin-user administrator'`

`docker exec -i rabbitmq powershell -Command 'rabbitmqctl set_permissions -p / admin-user ".*" ".*" ".*"'`


