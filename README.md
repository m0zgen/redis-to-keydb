# Simple Redis to KeyDB Migrator

Bash script for [migration](https://docs.keydb.dev/docs/migration) to KeyDB from Redis.

## Steps

Save current Redis data:

```
$ redis-cli>6379: bgsave
$ redis-cli>6379: shutdown
```

* Copy Redis config and backing up own KeyDB configs
* Stop Redis instance
* Run KeyDB instance
