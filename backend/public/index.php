<?php
header('Content-Type: application/json');
echo json_encode([
  'name' => 'Solar & Burji API',
  'status' => 'ok',
  'endpoints' => [
    '/backend/api/solar.php',
    '/backend/api/sales.php',
    '/backend/api/borrowings.php'
  ]
]);
