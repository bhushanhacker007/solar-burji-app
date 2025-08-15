<?php
function send_cors_headers(): void {
  header('Access-Control-Allow-Origin: *');
  header('Access-Control-Allow-Headers: Content-Type, X-API-KEY, X-HTTP-Method-Override');
  header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
}

function send_json($data, int $status = 200): void {
  http_response_code($status);
  header('Content-Type: application/json');
  echo json_encode($data);
  exit;
}

function read_json_body(): array {
  $raw = file_get_contents('php://input');
  $parsed = json_decode($raw, true);
  return is_array($parsed) ? $parsed : [];
}

function require_api_key(array $config): void {
  $provided = $_SERVER['HTTP_X_API_KEY'] ?? ($_GET['api_key'] ?? '');
  if (!isset($config['api_key']) || $provided !== $config['api_key']) {
    send_json(['error' => 'Unauthorized'], 401);
  }
}

function get_date_range(): array {
  $start = $_GET['start_date'] ?? null;
  $end = $_GET['end_date'] ?? null;
  $period = $_GET['period'] ?? null; // day|week|month
  $date = $_GET['date'] ?? null; // reference date

  if ($start && $end) {
    return [$start, $end];
  }

  $ref = $date ? new DateTime($date) : new DateTime('today');
  switch ($period) {
    case 'day':
      $s = $ref->format('Y-m-d');
      $e = $ref->format('Y-m-d');
      break;
    case 'week':
      // ISO week: Monday start
      $ref->setTime(0,0,0);
      $dayOfWeek = (int)$ref->format('N');
      $monday = clone $ref; $monday->modify('-' . ($dayOfWeek - 1) . ' days');
      $sunday = clone $monday; $sunday->modify('+6 days');
      $s = $monday->format('Y-m-d');
      $e = $sunday->format('Y-m-d');
      break;
    case 'month':
      $first = new DateTime($ref->format('Y-m-01'));
      $last = (clone $first)->modify('last day of this month');
      $s = $first->format('Y-m-d');
      $e = $last->format('Y-m-d');
      break;
    default:
      // default to today
      $s = (new DateTime('today'))->format('Y-m-d');
      $e = $s;
  }
  return [$s, $e];
}

function effective_method(): string {
  $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
  $override = $_SERVER['HTTP_X_HTTP_METHOD_OVERRIDE'] ?? ($_GET['_method'] ?? null);
  if ($override) {
    $ov = strtoupper($override);
    if (in_array($ov, ['GET','POST','PUT','DELETE','OPTIONS'], true)) {
      return $ov;
    }
  }
  return strtoupper($method);
}
