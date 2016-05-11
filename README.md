# Queue system based on Redis lists

This application is a simple example how we can use Redis + Nginx + Lua

The main goal is answer to question - which type of objects can we show right now?

For example we've got the banners system with a lot of tables which are responsible for timesheet, statistics, information about the object and have to many conditions how to show it.

I want to know which banners I can show on the special web page or mobile application at this moment. I want to get it remotely by HTTP protocol in JSON format just sending a type of object. Some banners can be limited by the number of impressions.

If we use relational database it can be a problem on the applications with hight load, because for reading we have to use to many JOIN consturctions in our SQL and every request we have to connect to DB server and select some data. Also at the same time an administrator want to add new banner and show some statistics to client. That mean we have a lot of write operations. Summary it makes a high load to database server.

Fortunately we can aggregate it by time to queue something like this:
```
{
	"type1_tm1": ["t1h1", "t1h2", "t1h3"],
	"type1_tm2": ["t1h1", "t1h3"],
	"type1_tm3": ["t1h1", "t1h2", "t1h3"],
	"type2_tm1": ["t2h1", "t2h2"],
	"type2_tm2": ["t2h1"],
	"type2_tm3": ["t2h1"],
	"t1h1": {"is_cnt": 1, "cnt": 0, "cnt_max": 3, "name": "Type1 Object1"},
	"t1h2": {"is_cnt": 0, "cnt": 0, "name": "Type1 Object2"},
	"t1h3": {"is_cnt": 0, "cnt": 0, "name": "Type1 Object3"},
	"t2h1": {"is_cnt": 0, "cnt": 0, "name": "Type2 Object1"},
	"t2h2": {"is_cnt": 0, "cnt": 0, "name": "Type2 Object2"}
}
```
Providing that:
* type{i}_tm{j} is an endless queue which created by list in Redis and stores the type of objects which we can show at this moment. type{i} - type of object, tm{j} - label
* t{i}h{k} is a hash in Redis which stores an information about objects. t{i} - type of object, h{k} - some object

Now we have to create some keys in Redis and add them to queue. Let's do that.

Let's add some objects:
```
127.0.0.1:6379> hmset t1h1 is_cnt 1 cnt 0 cnt_max 3 name "Type1 Object1"
OK
127.0.0.1:6379> hmset t1h2 is_cnt 0 cnt 0 name "Type1 Object2"
OK
127.0.0.1:6379> hmset t1h3 is_cnt 0 cnt 0 name "Type1 Object3"
OK
127.0.0.1:6379> hmset t2h1 is_cnt 0 cnt 0 name "Type2 Object1"
OK
127.0.0.1:6379> hmset t2h2 is_cnt 0 cnt 0 name "Type2 Object2"
OK
```
* is_cnt - flag which limits displaying by the number of impressions
* cnt - the current number of impressions
* cnt_max - how many times can we show this object

Let's create the queue which will have been working for 1 hour:

For creating a time label use this algorithm:
```
local interval = 3600
local tm = math.floor(os.time() / interval) * interval
```
Now let's push objects to the queue:
```
127.0.0.1:6379> rpush type1_1462978800 t1h1 t1h2 t1h3
(integer) 3
```

Now we have to add endpoints in Nginx config something like this:
```
location ~ ^/get-object$ {
	content_by_lua '
		local QueueSystem = require "lua-queue-system"
		local queueSystem = QueueSystem.createSystem()
		queueSystem.sendObject()
	';
}
location ~ ^/get-statistics$ {
	content_by_lua '
		local QueueSystem = require "lua-queue-system"
		local queueSystem = QueueSystem.createSystem()
		queueSystem.sendStat()
	';
}
```

Restart server and try:
```
# curl 'http://lua-http/get-object?type=1'
{"cnt":"0","name":"Type1 Object3","status":"OK"}
```

This solution helps to remove the load from our DB server.

Hope it helps in solving your problems.
