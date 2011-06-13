module test;

import rbtree_with_stats;

import std.stdio;
import std.datetime;
import core.memory;
import std.random;
import std.socket;
import std.string;
import std.array;

class User {
	uint userId;
	uint score;
	
	/**
	 * Time where 
	 */
	uint timestamp;
	
	this(uint userId, uint score, uint timestamp) {
		this.userId    = userId;
		this.score     = score;
		this.timestamp = timestamp;
	}
	
	/*
	public void copyFrom(User that) {
		this.userId = that.userId;
		this.score = that.score;
		this.timestamp = that.timestamp;
	}
	*/
	
	static bool compareByUserId(User a, User b) {
		return a.userId < b.userId;
	}
	
	static bool compareByScoreReverse(User a, User b) {
		if (a.score == b.score) {
			if (a.timestamp == b.timestamp) {
				return a.userId < b.userId;
			} else {
				return a.timestamp < b.timestamp;
			}
		} else { 
			return a.score > b.score;
		}
	}
	
	static bool compareByScore(User a, User b) {
		if (a.score == b.score) {
			if (a.timestamp == b.timestamp) {
				return a.userId < b.userId;
			} else {
				return a.timestamp < b.timestamp;
			}
		} else { 
			return a.score < b.score;
		}
	}
	
	public string toString() {
		return std.string.format("User(userId:%d, timestamp:%d, score:%d)", userId, timestamp, score);
	}
}

const bool useStats = true;

void measure(string desc, void delegate() dg) {
	auto start = Clock.currTime;
	dg();
	auto end = Clock.currTime;
	writefln("Time('%s'): %s", desc, end - start);
	writefln("");
}

void measurePerformance(bool useStats)() {
	writefln("---------------------------------------");
	writefln("measurePerformance(useStats=%s)", useStats);
	writefln("---------------------------------------");
	
	//RedBlackTree(T, alias less = "a < b", bool allowDuplicates = false, bool hasStats = false)
	
	auto start = Clock.currTime;
	measure("Total", {
		int itemSize = 1_000_000;
		
		auto items = new RedBlackTree!(User, User.compareByScore, false, useStats)();
		User generate(uint id) {
			return new User(id, id * 100, id);
		}
	
		writefln("NodeSize: %d", (*items._end).sizeof);
		
		//for (int n = itemSize; n >= 11; n--) {
		measure(std.string.format("Insert(%d) items", itemSize), {
			for (int n = 0; n < itemSize; n++) {
				items.insert(generate(n));
			}
		});
		
		items.removeKey(generate(100_000));
		items.removeKey(generate(700_000));

		measure(std.string.format("locateNodeAtPosition"), {
			for (int n = 0; n < 40; n++) {
				int result = items.locateNodeAtPosition(800_000).value.userId;
				if (n == 40 - 1) {
					writefln("%s", result);
				}
			}
		});
		
		measure("IterateUpperBound", {
			foreach (item; items.upperBound(generate(1_000_000 - 100_000))) {
				//writefln("Item: %s", item);
			}
		});
	
		measure("LengthAll", {
			writefln("%d", items.all.length);
		});
		measure("Length(skipx40:800_000)", {
			for (int n = 0; n < 40; n++) {
				int result = items.all.skip(800_000).length;
				//int result = items.all[800_000..items.all.length].length;
				if (n == 40 - 1) {
					writefln("%d", items.all.skip(800_000).front.userId);
					writefln("%d", items.all.skip(800_000).back.userId);
					writefln("%d", result);
				}
			}
		});
		
		measure("Length(skip+limitx40:100_000,600_000)", {
			for (int n = 0; n < 40; n++) {
				//int result = items.all.skip(100_000).limit(600_000).length;
				int result = items.all[100_000 .. 700_000].length;
				if (n == 40 - 1) {
					writefln("%d", items.all.skip(100_000).limit(600_000).front.userId);
					writefln("%d", items.all.skip(100_000).limit(600_000).back.userId);
					writefln("%d", result);
				}
			}
		});
		measure("Length(lesserx40)", {
			for (int n = 0; n < 40; n++) {
				int result = items.countLesser(items._find(generate(1_000_000 - 10)));
				if (n == 40 - 1) writefln("%d", result);
			}
		});
		measure("LengthBigRangex40", {
			for (int n = 0; n < 40; n++) {
				int result = items.upperBound(generate(1_000_000 - 900_000)).length;
				if (n == 40 - 1) writefln("%d", result);
			}
		});
		
		//items._end._left.printTree();
		//writefln("%s", *items._find(5));
		//foreach (item; items) writefln("%d", item);
		static if (useStats) {
			measure("Count all items position one by one (only with stats) O(N*log(N))", {
				for (int n = 0; n < itemSize; n++) {
					if (n == 100_000 || n == 700_000) continue;
		
					scope user = new User(n, n * 100, n);
					
					//writefln("%d", count);
					//writefln("-----------------------------------------------------");
					//writefln("######## Count(%d): %d", n, count);
					/*
					if (n > 500) {
						assert(count == n - 1);
					} else {
						assert(count == n);
					}
					*/
					static if (useStats) {
						int count = items.countLesser(items._find(user));
						
						int v = n;
						if (n > 100_000) v--;
						if (n > 700_000) v--;
						assert(count == v);
					}
				}
			});
		}
	});
}

class UserStats {
	alias RedBlackTree!(User, User.compareByUserId, false, false) UserTreeById;
	alias RedBlackTree!(User, User.compareByScoreReverse, false, true) UserTreeByScore;

	public UserTreeById    users;
	public UserTreeByScore usersByScore;
	
	public this() {
		users        = new UserTreeById();
		usersByScore = new UserTreeByScore();
	}
	
	static void set(TreeType, ElementType)(TreeType tree, ElementType item) {
		if (tree._find(item) is null) {
			tree.insert(item);
		} else {
			tree.removeKey(item);
			tree.insert(item);
		}
	}
	
	public int locateById(int userId) {
		scope node = users._find(new User(userId, 0, 0));
		return usersByScore.getNodePosition(usersByScore._find(node.value));
	}
	
	public void setUser(User newUser) {
		scope oldNode = users._find(newUser);
		if (oldNode !is null) {
			User oldUser = oldNode.value;
			users.removeKey(oldUser);
			usersByScore.removeKey(oldUser);
		}
		users.insert(newUser);
		usersByScore.insert(newUser);
	}
}

void test1() {
	Random gen;
	
	UserStats userStats = new UserStats();
	for (int n = 0; n < 1000; n++) {
		int score;
		score = (n < 20) ? 2980 : uniform(0, 3000, gen);
		userStats.setUser(new User(n, score, 10000 - n * 2));
	}
	userStats.setUser(new User(1000, 99, 400));
	userStats.setUser(new User(1001, 1000, 400));
	userStats.setUser(new User(1000, 20000, 400));
	int k;
	
	writefln("-----------------------------");
	
	k = 0;
	foreach (user; userStats.usersByScore.all()) {
		writefln("%d: %s", k + 1, user);
		k++;
	}
	
	writefln("-----------------------------");
	
	k = 0;
	foreach (user; userStats.usersByScore.all().limit(10)) {
		writefln("%d: %s", k + 1, user);
		k++;
	}

	foreach (indexToSearch; [300, 1001, 1000]) {	
		writefln("-----------------------------");
		
		writefln("Locate user(%d) : %d", indexToSearch, userStats.locateById(indexToSearch) + 1);
		
		writefln("-----------------------------");
		
		int skipCount = userStats.locateById(indexToSearch);
		k = skipCount;
		foreach (user; userStats.usersByScore.all().skip(skipCount).limit(10)) {
			writefln("%d - %s", k + 1, user);
			k++;
		}
	}
	
	writefln("-----------------------------");
}

void test2() {
	GC.disable();
	{
		measurePerformance!(true);
		measurePerformance!(false);
	}
	GC.enable();
	GC.collect();
}

class RankingClient {
	public Socket socket;
	ubyte[] data;
	
	public this(Socket socket) {
		this.socket = socket;
		socket.blocking = false;
	}
	
	void init() {
		//this.socket.send("Hello World!\r\n");
	}
	
	bool receive() {
		scope ubyte[] temp = new ubyte[1024];
		//writefln("%s %s", socket, this);
		int totalReceivedLength = 0;
		while (true) {
			int receivedLength = socket.receive(temp);
			totalReceivedLength += receivedLength;
			if (receivedLength <= 0) {
				break;
			}
			data ~= temp[0..receivedLength];
		}
		handleData();
		return (totalReceivedLength > 0);
	}
	
	void handlePacket(ubyte[] data) {
		switch (data[0]) {
			case 1:
			break;
		}
	}
	
	void handleData() {
		ushort packetSize;
		//writefln("[1]");
		if (data.length >= packetSize.sizeof) {
			packetSize = *cast(typeof(packetSize) *)data.ptr;
			
			int packetTotalLength = packetSize.sizeof + 1 + packetSize;
			
			//writefln("[2] %d, %d", packetSize, data.length);
			if (data.length >= packetTotalLength) {
				//writefln("[3]");
				handlePacket(data[packetSize.sizeof..packetTotalLength].dup);
				data = data[packetTotalLength..$].dup;
			}
		}
		/*
		int index;
		if ((index = std.string.indexOf(cast(string)data, "\n")) != -1) {
			string line = cast(string)data[0..index].dup;
			data = data[index + 1..$].dup;
			writefln("handleData:'%s'", line);
		}
		*/
	}
}

class RankingServer : TcpSocket {
	this() {
		bind(new InternetAddress("0.0.0.0", 9777));
		listen(1024);
		blocking = false;
	}
	
	RankingClient[Socket] clients;
	
	void acceptLoop() {
		Socket socketClient;
		scope SocketSet readSet = new SocketSet();
		scope SocketSet writeSet = new SocketSet();
		scope SocketSet errorSet = new SocketSet();
		while (true) {
			readSet.add(this);
			foreach (socket; clients.keys) {
				readSet.add(socket);
			}
			int count = Socket.select(readSet, writeSet, errorSet);
			
			if (readSet.isSet(this)) {
				socketClient = accept();
				if (socketClient !is null) {
					RankingClient rankingClient = new RankingClient(socketClient);
					clients[socketClient] = rankingClient; 
					rankingClient.init();
					//rankingClient.receive();
				}
			}

			readSockets:;			

			foreach (Socket socket, RankingClient client; clients) {
				if (readSet.isSet(socket)) {
					if (!client.receive()) {
						clients.remove(socket);
						goto readSockets;					
					}
				}
			}
			
			readSet.reset();
			writeSet.reset();
			errorSet.reset();
		}
	}
}

int main(string[] args) {
	RankingServer socketServer = new RankingServer();
	socketServer.acceptLoop();

	//test1();
	//test2();
	
	return 0;
}
