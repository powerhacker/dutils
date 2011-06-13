<?php

$f = fsockopen('127.0.0.1', 9777);
fwrite($f, pack('v', 0));
fwrite($f, pack('c', 1));
fclose($f);