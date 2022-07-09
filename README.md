# Simple Redis to KeyDB Migrator

Bash script for [migration](https://docs.keydb.dev/docs/migration) to KeyDB from Redis.

## Steps

Save current Redis data:

```
$ redis-cli>6379: bgsave
$ redis-cli>6379: shutdown
```

* Copy Redis config and backing up own KeyDB configs
* Change / Update paths form redis to keydb in copied configs
* Stop Redis instance
* Run KeyDB instance on `0.0.0.0 ::`

Note: Please change `bind` parameters in `/etc/keydb/keydb.conf`
