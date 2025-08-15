<?php
$configPath = __DIR__ . '/config.php';
if (!file_exists($configPath)) {
  http_response_code(500);
  header('Content-Type: application/json');
  echo json_encode(['error' => 'Missing config.php. Copy config.sample.php to config.php and set credentials.']);
  exit;
}
$config = require $configPath;

$mysqli = new mysqli(
  $config['db']['host'],
  $config['db']['user'],
  $config['db']['pass'],
  $config['db']['name'],
  $config['db']['port'] ?? 3306
);

if ($mysqli->connect_errno) {
  http_response_code(500);
  header('Content-Type: application/json');
  echo json_encode(['error' => 'DB connection failed', 'detail' => $mysqli->connect_error]);
  exit;
}

$mysqli->set_charset('utf8mb4');
