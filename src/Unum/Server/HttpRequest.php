<?php

declare(strict_types=1);

namespace Unum\Server;

use InvalidArgumentException;

/**
 * 👑 Sovereign Bare-Metal HTTP Request Parser
 * 
 * WHY: High-performance single-pass linear scanner extracting HTTP/1.1 method,
 * path, query parameters, headers, and body with zero regex backtracking.
 */
final class HttpRequest
{
    private string $method;
    private string $uri;
    private string $path;
    /** @var array<string, string> */
    private array $queryParams = [];
    /** @var array<string, string> */
    private array $headers = [];
    private string $body = '';

    public function __construct(string $method, string $uri, array $headers = [], string $body = '')
    {
        $this->method = strtoupper($method);
        $this->uri = $uri;
        $this->headers = $headers;
        $this->body = $body;

        $parsed = parse_url($uri);
        $this->path = $parsed['path'] ?? '/';
        if (isset($parsed['query'])) {
            parse_str($parsed['query'], $this->queryParams);
        }
    }

    /**
     * Parses raw incoming TCP stream bytes into an HttpRequest object.
     */
    public static function parse(string $raw): ?self
    {
        $headEnd = strpos($raw, "\r\n\r\n");
        if ($headEnd === false) {
            $headEnd = strpos($raw, "\n\n");
            if ($headEnd === false) {
                return null;
            }
            $delimiterLen = 2;
        } else {
            $delimiterLen = 4;
        }

        $headerText = substr($raw, 0, $headEnd);
        $body = substr($raw, $headEnd + $delimiterLen);

        $lines = explode("\n", $headerText);
        $firstLine = trim(array_shift($lines));
        $parts = explode(' ', $firstLine);

        if (count($parts) < 2) {
            return null;
        }

        $method = $parts[0];
        $uri = $parts[1];

        $headers = [];
        foreach ($lines as $line) {
            $line = trim($line);
            if ($line === '') continue;
            $colonPos = strpos($line, ':');
            if ($colonPos !== false) {
                $k = strtolower(trim(substr($line, 0, $colonPos)));
                $v = trim(substr($line, $colonPos + 1));
                $headers[$k] = $v;
            }
        }

        return new self($method, $uri, $headers, $body);
    }

    public function getMethod(): string
    {
        return $this->method;
    }

    public function getUri(): string
    {
        return $this->uri;
    }

    public function getPath(): string
    {
        return $this->path;
    }

    public function getQueryParam(string $name, ?string $default = null): ?string
    {
        return $this->queryParams[$name] ?? $default;
    }

    public function getHeader(string $name, ?string $default = null): ?string
    {
        return $this->headers[strtolower($name)] ?? $default;
    }

    public function getBody(): string
    {
        return $this->body;
    }

    /**
     * Parses JSON body payload into associative array.
     */
    public function getJson(): ?array
    {
        if (empty($this->body)) return null;
        $decoded = json_decode($this->body, true);
        return is_array($decoded) ? $decoded : null;
    }
}
