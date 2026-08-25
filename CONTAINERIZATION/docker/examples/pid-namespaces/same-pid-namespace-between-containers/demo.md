```bash
docker run --name=c1 -d ubuntu sh -c 'sleep 1d'
docker exec -it c1 ps aux
# USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
# root           1  2.9  0.0   2880  1792 ?        Ss   14:00   0:00 sh -c sleep 1d
# root           7  0.0  0.0  16104  7552 ?        S    14:00   0:00 sleep 1d
# root           8 40.0  0.0   6752  3840 pts/0    Rs+  14:00   0:00 ps aux

docker run --name=c2 -d ubuntu sh -c 'sleep 999d'
docker exec -it c2 ps aux

ps aux | grep sleep

docker rm c2 --force

docker run --name=c2 --pid=container=c1 -d ubuntu sh -c 'sleep 1d'
docker exec -it c2 ps aux
# USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
# root           1  0.0  0.0   2880  1792 ?        Ss   14:00   0:00 sh -c sleep 1d
# root           7  0.0  0.0  16104  7552 ?        S    14:00   0:00 sleep 1d
# root          14  0.1  0.0   2880  1792 ?        Ss   14:03   0:00 sh -c sleep 1d
# root          20  0.0  0.0  16104  7552 ?        S    14:03   0:00 sleep 1d
# root          27 50.0  0.0   6752  3968 pts/1    Rs+  14:04   0:00 ps aux
```