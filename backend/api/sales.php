<?php
require_once __DIR__ . '/../config/db.php';
require_once __DIR__ . '/helpers.php';
send_cors_headers();
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { exit; }
require_api_key($config);

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? null;

// Handle POST with action parameter for update/delete
if ($method === 'POST' && $action === 'update') {
  $body = read_json_body();
  $id = isset($body['id']) ? (int)$body['id'] : 0;
  $amount = isset($body['amount']) ? (float)$body['amount'] : null;
  $payment_method = $body['payment_method'] ?? null;
  $note = $body['note'] ?? null;
  if ($id <= 0) send_json(['error' => 'id required'], 400);
  if ($payment_method && !in_array($payment_method, ['cash','online'], true)) {
    send_json(['error' => 'payment_method must be cash or online'], 400);
  }
  $fields = [];
  $types = '';
  $values = [];
  if ($amount !== null) { $fields[] = 'amount = ?'; $types .= 'd'; $values[] = $amount; }
  if ($payment_method !== null) { $fields[] = 'payment_method = ?'; $types .= 's'; $values[] = $payment_method; }
  if ($note !== null) { $fields[] = 'note = ?'; $types .= 's'; $values[] = $note; }
  if (empty($fields)) send_json(['error' => 'Nothing to update'], 400);
  $sql = 'UPDATE sales SET ' . implode(', ', $fields) . ' WHERE id = ?';
  $types .= 'i';
  $values[] = $id;
  $stmt = $mysqli->prepare($sql);
  $stmt->bind_param($types, ...$values);
  if (!$stmt->execute()) send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  send_json(['ok' => true]);
}

if ($method === 'POST' && $action === 'delete') {
  $id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
  if ($id <= 0) send_json(['error' => 'id required'], 400);
  $stmt = $mysqli->prepare('DELETE FROM sales WHERE id = ?');
  $stmt->bind_param('i', $id);
  if (!$stmt->execute()) send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  send_json(['ok' => true]);
}

if ($method === 'POST') {
  $body = read_json_body();
  $txn_date = $body['txn_date'] ?? null; // YYYY-MM-DD
  $amount = isset($body['amount']) ? (float)$body['amount'] : null;
  $payment_method = $body['payment_method'] ?? null; // cash|online
  $note = $body['note'] ?? null;

  if (!$txn_date || $amount === null || !$payment_method) {
    send_json(['error' => 'txn_date, amount, payment_method required'], 400);
  }
  if (!in_array($payment_method, ['cash','online'], true)) {
    send_json(['error' => 'payment_method must be cash or online'], 400);
  }

  $stmt = $mysqli->prepare('INSERT INTO sales (txn_date, amount, payment_method, note) VALUES (?, ?, ?, ?)');
  $stmt->bind_param('sdss', $txn_date, $amount, $payment_method, $note);
  if (!$stmt->execute()) {
    send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  }
  send_json(['ok' => true, 'id' => $mysqli->insert_id]);
}

if ($method === 'PUT') {
  $body = read_json_body();
  $id = isset($body['id']) ? (int)$body['id'] : 0;
  $amount = isset($body['amount']) ? (float)$body['amount'] : null;
  $payment_method = $body['payment_method'] ?? null;
  $note = $body['note'] ?? null;
  if ($id <= 0) send_json(['error' => 'id required'], 400);
  if ($payment_method && !in_array($payment_method, ['cash','online'], true)) {
    send_json(['error' => 'payment_method must be cash or online'], 400);
  }
  $fields = [];
  $types = '';
  $values = [];
  if ($amount !== null) { $fields[] = 'amount = ?'; $types .= 'd'; $values[] = $amount; }
  if ($payment_method !== null) { $fields[] = 'payment_method = ?'; $types .= 's'; $values[] = $payment_method; }
  if ($note !== null) { $fields[] = 'note = ?'; $types .= 's'; $values[] = $note; }
  if (empty($fields)) send_json(['error' => 'Nothing to update'], 400);
  $sql = 'UPDATE sales SET ' . implode(', ', $fields) . ' WHERE id = ?';
  $types .= 'i';
  $values[] = $id;
  $stmt = $mysqli->prepare($sql);
  $stmt->bind_param($types, ...$values);
  if (!$stmt->execute()) send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  send_json(['ok' => true]);
}

if ($method === 'DELETE') {
  $id = isset($_GET['id']) ? (int)$_GET['id'] : 0;
  if ($id <= 0) send_json(['error' => 'id required'], 400);
  $stmt = $mysqli->prepare('DELETE FROM sales WHERE id = ?');
  $stmt->bind_param('i', $id);
  if (!$stmt->execute()) send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  send_json(['ok' => true]);
}

if ($method === 'GET') {
  [$start, $end] = get_date_range();
  $stmt = $mysqli->prepare('SELECT id, txn_date, amount, payment_method, note FROM sales WHERE txn_date BETWEEN ? AND ? ORDER BY txn_date ASC, id ASC');
  $stmt->bind_param('ss', $start, $end);
  if (!$stmt->execute()) {
    send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  }
  $res = $stmt->get_result();
  $rows = [];
  $total = 0; $cash = 0; $online = 0;
  while ($r = $res->fetch_assoc()) {
    $rows[] = $r;
    $total += (float)$r['amount'];
    if ($r['payment_method'] === 'cash') $cash += (float)$r['amount'];
    if ($r['payment_method'] === 'online') $online += (float)$r['amount'];
  }
  if ((isset($_GET['format']) && $_GET['format'] === 'csv')) {
    $filename = sprintf('sales_%s_to_%s.csv', $start, $end);
    header('Content-Type: text/csv');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    $out = fopen('php://output', 'w');
    fputcsv($out, ['Date', 'Amount (INR)', 'Payment Method', 'Note']);
    foreach ($rows as $r) {
      fputcsv($out, [$r['txn_date'], $r['amount'], $r['payment_method'], $r['note']]);
    }
    fputcsv($out, ['TOTALS', round($total, 2), 'cash=' . round($cash, 2) . '; online=' . round($online, 2), '']);
    fclose($out);
    exit;
  }
  send_json([
    'range' => ['start' => $start, 'end' => $end],
    'total_amount' => round($total, 2),
    'cash_amount' => round($cash, 2),
    'online_amount' => round($online, 2),
    'transactions' => $rows
  ]);
}

send_json(['error' => 'Method not allowed'], 405);
