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
  $customer_name = $body['customer_name'] ?? null;
  $amount = isset($body['amount']) ? (float)$body['amount'] : null;
  $is_repayment = $body['is_repayment'] ?? null;
  $note = $body['note'] ?? null;
  if ($id <= 0) send_json(['error' => 'id required'], 400);
  if ($is_repayment !== null) {
    $is_repayment = (int)$is_repayment;
    if ($is_repayment !== 0 && $is_repayment !== 1) send_json(['error' => 'is_repayment must be 0 or 1'], 400);
  }
  $fields = [];
  $types = '';
  $values = [];
  if ($customer_name !== null) { $fields[] = 'customer_name = ?'; $types .= 's'; $values[] = $customer_name; }
  if ($amount !== null) { $fields[] = 'amount = ?'; $types .= 'd'; $values[] = $amount; }
  if ($is_repayment !== null) { $fields[] = 'is_repayment = ?'; $types .= 'i'; $values[] = $is_repayment; }
  if ($note !== null) { $fields[] = 'note = ?'; $types .= 's'; $values[] = $note; }
  if (empty($fields)) send_json(['error' => 'Nothing to update'], 400);
  $sql = 'UPDATE borrowings SET ' . implode(', ', $fields) . ' WHERE id = ?';
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
  $stmt = $mysqli->prepare('DELETE FROM borrowings WHERE id = ?');
  $stmt->bind_param('i', $id);
  if (!$stmt->execute()) send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  send_json(['ok' => true]);
}

if ($method === 'POST') {
  $body = read_json_body();
  $txn_date = $body['txn_date'] ?? null; // YYYY-MM-DD
  $customer_name = $body['customer_name'] ?? null;
  $amount = isset($body['amount']) ? (float)$body['amount'] : null;
  $is_repayment = (int)($body['is_repayment'] ?? 0);
  $note = $body['note'] ?? null;

  if (!$txn_date || !$customer_name || $amount === null) {
    send_json(['error' => 'txn_date, customer_name, amount required'], 400);
  }
  if ($is_repayment !== 0 && $is_repayment !== 1) {
    send_json(['error' => 'is_repayment must be 0 or 1'], 400);
  }

  $stmt = $mysqli->prepare('INSERT INTO borrowings (txn_date, customer_name, amount, is_repayment, note) VALUES (?, ?, ?, ?, ?)');
  $stmt->bind_param('ssdis', $txn_date, $customer_name, $amount, $is_repayment, $note);
  if (!$stmt->execute()) {
    send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  }
  send_json(['ok' => true, 'id' => $mysqli->insert_id]);
}

if ($method === 'PUT') {
  $body = read_json_body();
  $id = isset($body['id']) ? (int)$body['id'] : 0;
  $customer_name = $body['customer_name'] ?? null;
  $amount = isset($body['amount']) ? (float)$body['amount'] : null;
  $is_repayment = $body['is_repayment'] ?? null;
  $note = $body['note'] ?? null;
  if ($id <= 0) send_json(['error' => 'id required'], 400);
  if ($is_repayment !== null) {
    $is_repayment = (int)$is_repayment;
    if ($is_repayment !== 0 && $is_repayment !== 1) send_json(['error' => 'is_repayment must be 0 or 1'], 400);
  }
  $fields = [];
  $types = '';
  $values = [];
  if ($customer_name !== null) { $fields[] = 'customer_name = ?'; $types .= 's'; $values[] = $customer_name; }
  if ($amount !== null) { $fields[] = 'amount = ?'; $types .= 'd'; $values[] = $amount; }
  if ($is_repayment !== null) { $fields[] = 'is_repayment = ?'; $types .= 'i'; $values[] = $is_repayment; }
  if ($note !== null) { $fields[] = 'note = ?'; $types .= 's'; $values[] = $note; }
  if (empty($fields)) send_json(['error' => 'Nothing to update'], 400);
  $sql = 'UPDATE borrowings SET ' . implode(', ', $fields) . ' WHERE id = ?';
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
  $stmt = $mysqli->prepare('DELETE FROM borrowings WHERE id = ?');
  $stmt->bind_param('i', $id);
  if (!$stmt->execute()) send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  send_json(['ok' => true]);
}

if ($method === 'GET') {
  [$start, $end] = get_date_range();
  $stmt = $mysqli->prepare('SELECT id, txn_date, customer_name, amount, is_repayment, note FROM borrowings WHERE txn_date BETWEEN ? AND ? ORDER BY txn_date ASC, id ASC');
  $stmt->bind_param('ss', $start, $end);
  if (!$stmt->execute()) {
    send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  }
  $res = $stmt->get_result();
  $rows = [];
  $borrow_total = 0; $repayment_total = 0;
  while ($r = $res->fetch_assoc()) {
    $rows[] = $r;
    if ((int)$r['is_repayment'] === 1) {
      $repayment_total += (float)$r['amount'];
    } else {
      $borrow_total += (float)$r['amount'];
    }
  }
  if ((isset($_GET['format']) && $_GET['format'] === 'csv')) {
    $filename = sprintf('borrowings_%s_to_%s.csv', $start, $end);
    header('Content-Type: text/csv');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    $out = fopen('php://output', 'w');
    fputcsv($out, ['Date', 'Customer', 'Amount (INR)', 'Type', 'Note']);
    foreach ($rows as $r) {
      fputcsv($out, [$r['txn_date'], $r['customer_name'], $r['amount'], ((int)$r['is_repayment'] === 1 ? 'repayment' : 'borrow'), $r['note']]);
    }
    fputcsv($out, ['TOTALS', '', 'borrow=' . round($borrow_total, 2) . '; repayment=' . round($repayment_total, 2), 'net=' . round($borrow_total - $repayment_total, 2), '']);
    fclose($out);
    exit;
  }
  send_json([
    'range' => ['start' => $start, 'end' => $end],
    'borrow_total' => round($borrow_total, 2),
    'repayment_total' => round($repayment_total, 2),
    'net_outstanding_change' => round($borrow_total - $repayment_total, 2),
    'entries' => $rows
  ]);
}

send_json(['error' => 'Method not allowed'], 405);
