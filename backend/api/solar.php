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
  $reading_date = $body['reading_date'] ?? null; // key
  if (!$reading_date) send_json(['error' => 'reading_date required (YYYY-MM-DD)'], 400);
  $import_kwh = isset($body['import_kwh']) ? (float)$body['import_kwh'] : null;
  $export_kwh = isset($body['export_kwh']) ? (float)$body['export_kwh'] : null;
  $generation_kwh = isset($body['generation_kwh']) ? (float)$body['generation_kwh'] : null;
  $notes = array_key_exists('notes', $body) ? $body['notes'] : null; // allow null
  $fields = [];
  $types = '';
  $values = [];
  if ($import_kwh !== null) { $fields[] = 'import_kwh = ?'; $types .= 'd'; $values[] = $import_kwh; }
  if ($export_kwh !== null) { $fields[] = 'export_kwh = ?'; $types .= 'd'; $values[] = $export_kwh; }
  if ($generation_kwh !== null) { $fields[] = 'generation_kwh = ?'; $types .= 'd'; $values[] = $generation_kwh; }
  if ($notes !== null) { $fields[] = 'notes = ?'; $types .= 's'; $values[] = $notes; }
  if (empty($fields)) send_json(['error' => 'Nothing to update'], 400);
  $sql = 'UPDATE solar_daily SET ' . implode(', ', $fields) . ' WHERE reading_date = ?';
  $types .= 's';
  $values[] = $reading_date;
  $stmt = $mysqli->prepare($sql);
  $stmt->bind_param($types, ...$values);
  if (!$stmt->execute()) send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  send_json(['ok' => true]);
}

if ($method === 'POST' && $action === 'delete') {
  $reading_date = $_GET['reading_date'] ?? null;
  if (!$reading_date) send_json(['error' => 'reading_date required'], 400);
  $stmt = $mysqli->prepare('DELETE FROM solar_daily WHERE reading_date = ?');
  $stmt->bind_param('s', $reading_date);
  if (!$stmt->execute()) send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  send_json(['ok' => true]);
}

if ($method === 'POST') {
  $body = read_json_body();
  $reading_date = $body['reading_date'] ?? null; // YYYY-MM-DD
  $import_kwh = (float)($body['import_kwh'] ?? 0);
  $export_kwh = (float)($body['export_kwh'] ?? 0);
  $generation_kwh = (float)($body['generation_kwh'] ?? 0);
  $notes = $body['notes'] ?? null;

  if (!$reading_date) {
    send_json(['error' => 'reading_date required (YYYY-MM-DD)'], 400);
  }

  $stmt = $mysqli->prepare('INSERT INTO solar_daily (reading_date, import_kwh, export_kwh, generation_kwh, notes) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE import_kwh = VALUES(import_kwh), export_kwh = VALUES(export_kwh), generation_kwh = VALUES(generation_kwh), notes = VALUES(notes)');
  $stmt->bind_param('sddds', $reading_date, $import_kwh, $export_kwh, $generation_kwh, $notes);
  if (!$stmt->execute()) {
    send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  }
  send_json(['ok' => true]);
}

if ($method === 'PUT') {
  $body = read_json_body();
  $reading_date = $body['reading_date'] ?? null; // key
  if (!$reading_date) send_json(['error' => 'reading_date required (YYYY-MM-DD)'], 400);
  $import_kwh = isset($body['import_kwh']) ? (float)$body['import_kwh'] : null;
  $export_kwh = isset($body['export_kwh']) ? (float)$body['export_kwh'] : null;
  $generation_kwh = isset($body['generation_kwh']) ? (float)$body['generation_kwh'] : null;
  $notes = array_key_exists('notes', $body) ? $body['notes'] : null; // allow null
  $fields = [];
  $types = '';
  $values = [];
  if ($import_kwh !== null) { $fields[] = 'import_kwh = ?'; $types .= 'd'; $values[] = $import_kwh; }
  if ($export_kwh !== null) { $fields[] = 'export_kwh = ?'; $types .= 'd'; $values[] = $export_kwh; }
  if ($generation_kwh !== null) { $fields[] = 'generation_kwh = ?'; $types .= 'd'; $values[] = $generation_kwh; }
  if ($notes !== null) { $fields[] = 'notes = ?'; $types .= 's'; $values[] = $notes; }
  if (empty($fields)) send_json(['error' => 'Nothing to update'], 400);
  $sql = 'UPDATE solar_daily SET ' . implode(', ', $fields) . ' WHERE reading_date = ?';
  $types .= 's';
  $values[] = $reading_date;
  $stmt = $mysqli->prepare($sql);
  $stmt->bind_param($types, ...$values);
  if (!$stmt->execute()) send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  send_json(['ok' => true]);
}

if ($method === 'DELETE') {
  $reading_date = $_GET['reading_date'] ?? null;
  if (!$reading_date) send_json(['error' => 'reading_date required'], 400);
  $stmt = $mysqli->prepare('DELETE FROM solar_daily WHERE reading_date = ?');
  $stmt->bind_param('s', $reading_date);
  if (!$stmt->execute()) send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  send_json(['ok' => true]);
}

if ($method === 'GET') {
  // GET /api/solar.php?period=day|week|month&date=YYYY-MM-DD or start_date&end_date
  [$start, $end] = get_date_range();
  $stmt = $mysqli->prepare('SELECT reading_date, import_kwh, export_kwh, generation_kwh, notes FROM solar_daily WHERE reading_date BETWEEN ? AND ? ORDER BY reading_date ASC');
  $stmt->bind_param('ss', $start, $end);
  if (!$stmt->execute()) {
    send_json(['error' => 'DB error', 'detail' => $stmt->error], 500);
  }
  $res = $stmt->get_result();
  $rows = [];
  $tot_import = 0; $tot_export = 0; $tot_gen = 0;
  while ($r = $res->fetch_assoc()) {
    $rows[] = $r;
    $tot_import += (float)$r['import_kwh'];
    $tot_export += (float)$r['export_kwh'];
    $tot_gen += (float)$r['generation_kwh'];
  }
  if ((isset($_GET['format']) && $_GET['format'] === 'csv')) {
    $filename = sprintf('solar_%s_to_%s.csv', $start, $end);
    header('Content-Type: text/csv');
    header('Content-Disposition: attachment; filename="' . $filename . '"');
    $out = fopen('php://output', 'w');
    fputcsv($out, ['Date', 'Import (kWh)', 'Export (kWh)', 'Generation (kWh)', 'Notes']);
    foreach ($rows as $r) {
      fputcsv($out, [$r['reading_date'], $r['import_kwh'], $r['export_kwh'], $r['generation_kwh'], $r['notes']]);
    }
    fputcsv($out, ['TOTALS', round($tot_import, 3), round($tot_export, 3), round($tot_gen, 3), '']);
    fclose($out);
    exit;
  }
  send_json([
    'range' => ['start' => $start, 'end' => $end],
    'total_import_kwh' => round($tot_import, 3),
    'total_export_kwh' => round($tot_export, 3),
    'total_generation_kwh' => round($tot_gen, 3),
    'days' => $rows
  ]);
}

send_json(['error' => 'Method not allowed'], 405);
