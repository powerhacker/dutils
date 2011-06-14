<?php

class PacketType {
	const Ping               = 0;
	const ListItems          = 1;
	const SetUser            = 2;
	const LocateUserPosition = 3;
	const SetUsers           = 4;
	
	static public function toString($v) {
		static $lookup;
		if (!isset($lookup)) {
			$class = new ReflectionClass(__CLASS__);
			$lookup = array_flip($class->getConstants());
		}
		return $lookup[$v];
	}
}

class Packet {
	public $type;
	public $typeString;
	public $data;
	
	public function __construct($type, $data) {
		$this->type = $type;
		$this->typeString = PacketType::toString($type);
		$this->data = $data;

		//echo PacketType::toString($this->type) . "\n";
	}
}

class SocketClient {
	public $f;

	public function __construct() {
	}
	
	public function connect($ip, $port) {
		$this->f = fsockopen($ip, $port);
		if (!$this->f) throw(new Exception("Can't connect to {$ip}:{$port}"));
	}

	public function close() {
		fclose($this->f);
		$this->f = null;
	}
	
	public function sendPacket($type, $data = '') {
		$start = microtime(true);
		{
			fwrite($this->f, pack('v', strlen($data)));
			fwrite($this->f, pack('c', $type));
			fwrite($this->f, $data);
			
			$response = $this->recvPacket();
		}
		$end = microtime(true);
		
		//printf("%.6f\n", $end - $start);
		
		return $response;
	}
	
	public function ping() {
		return $this->sendPacket(PacketType::Ping);
	}
	
	//const MAX_SET_USERS = 4000; // pow(2, 16) / (4 * 4)
	//const MAX_SET_USERS = 4096; // pow(2, 16) / (4 * 4)
	const MAX_SET_USERS = 4095; // pow(2, 16) / (4 * 4)
	protected $setUsers = array();
	
	public function setUser($userId, $scoreIndex, $scoreTimestamp, $scoreValue) {
		$result = $this->sendPacket(
			PacketType::SetUser,
			pack('V*', $userId, $scoreIndex, $scoreTimestamp, $scoreValue)
		);
		//print_r($result);
		return $result;
	}
	
	public function setUsers($infos) {
		assert(count($this->setUsers) <= self::MAX_SET_USERS);
		$data = '';
		foreach ($infos as $info) {
			//$data .= pack('V*', $userId, $scoreIndex, $scoreTimestamp, $scoreValue);
			$data .= pack('V*', $info[0], $info[1], $info[2], $info[3]);
			//if (strlen($data) > )
		}
		$result = $this->sendPacket(PacketType::SetUsers, $data);
	}

	public function setUserBuffer($userId, $scoreIndex, $scoreTimestamp, $scoreValue) {
		$this->setUsers[] = array($userId, $scoreIndex, $scoreTimestamp, $scoreValue);
		if (count($this->setUsers) >= self::MAX_SET_USERS) {
			$this->setUserBufferFlush();
		}
		static $shutdown_callback;
		if (!isset($shutdown_callback)) {
			$shutdown_callback = true;
			register_shutdown_function(array($this, 'setUserBufferFlush'));
		}
	}
	
	public function setUserBufferFlush() {
		if (empty($this->setUsers)) return;

		$start = microtime(true);
		{
			if (true) {
				$this->setUsers($this->setUsers);
			} else {
				foreach ($this->setUsers as $user) {
					call_user_func_array(array($this, 'setUser'), $user);
				}
			}
			$this->setUsers = array();
		}
		$end = microtime(true);
		//printf("%.6f\n", $end - $start);
	}

	public function locateUserPosition($userId, $scoreIndex) {
		$this->setUserBufferFlush();
		
		$result = $this->sendPacket(
			PacketType::LocateUserPosition,
			pack('V*', $userId, $scoreIndex)
		);
		//print_r($result); return $result;
		list(,$position) = unpack('V', $result->data);
		return $position;
	}

	public function listItems($scoreIndex, $offset, $count) {
		$this->setUserBufferFlush();
	
		$result = $this->sendPacket(
			PacketType::ListItems,
			pack('V*', $scoreIndex, $offset, $count)
		);
		//print_r($result); return $result;
		
		$entries = array();
		
		$data = $result->data;

		while (strlen($data)) {
			$entry = array_combine(array('position', 'userId', 'score', 'timestamp'), array_values(unpack('V4', $data)));
			$data = substr($data, 4 * 4);
			$entries[] = $entry;
		}

		return $entries;
	}
	
	public function recvPacket() {
		//echo "[@0:.]";
		list(,$packetSize) = unpack('v', $v = fread($this->f, 2));
		if (strlen($v) < 2) throw(new Exception("Error receiving a packet"));
		//echo "[@1:{$packetSize}]";
		list(,$packetType) = unpack('c', fread($this->f, 1));
		//echo "[@2:{$packetType}]";
		$packetData = ($packetSize > 0) ? fread($this->f, $packetSize) : '';
		//echo "[@3:{$packetData}]";
		
		return new Packet($packetType, $packetData);
	}
}

$socketClient = new SocketClient();
$socketClient->connect('127.0.0.1', 9777);
$time = time();

//for ($n = 0; $n < 100000; $n++) {
for ($n = 0; $n < 1000; $n++) {
//for ($n = 0; $n < 100; $n++) {
//for ($n = 0; $n < 20; $n++) {
	$socketClient->setUserBuffer($n, 0, $time + mt_rand(-50, 4), mt_rand(0, 500));
}

$socketClient->setUserBuffer(1000, 0, $time, 200);
$socketClient->setUserBuffer(1001, 0, $time, 300);
$socketClient->setUserBuffer(1000, 0, $time + 1, 300);
//$socketClient->setUserBufferFlush();

printf("Position(1000):%d\n", $pos_1000 = $socketClient->locateUserPosition(1000, 0));
printf("Position(1001):%d\n", $pos_1001 = $socketClient->locateUserPosition(1001, 0));

print_r($socketClient->listItems(0, $pos_1000, 3));
print_r($socketClient->listItems(0, 0, 3));
//print_r($socketClient->listItems(0, 20, 20));



/*
while (true) {
	//echo "[1]";
	$socketClient->sendPacket(PacketType::Ping);
	//echo "[2]";
	$socketClient->recvPacket();
	//echo "[3]";
	//$socketClient->sendPacket(PacketType::Ping);
	//$socketClient->recvPacket();
}
*/