<?php

declare(strict_types=1);

namespace Unum\Server;

/**
 * 👑 Sovereign Bare-Metal HTTP Response Builder
 * 
 * WHY: Constructs standard HTTP/1.1 response frames with zero string copying,
 * automatic Content-Length headers, and HTTP keep-alive support.
 */
final class HttpResponse
{
    private int $statusCode;
    private string $statusText;
    /** @var array<string, string> */
    private array $headers = [];
    private string $body;

    private const STATUS_TEXTS = [
        200 => 'OK',
        201 => 'Created',
        204 => 'No Content',
        400 => 'Bad Request',
        404 => 'Not Found',
        500 => 'Internal Server Error',
    ];

    public function __construct(int $statusCode = 200, string $body = '', array $headers = [])
    {
        $this->statusCode = $statusCode;
        $this->statusText = self::STATUS_TEXTS[$statusCode] ?? 'Unknown';
        $this->headers = $headers;
        $this->body = $body;
    }

    public static function json(mixed $data, int $status = 200): self
    {
        $json = json_encode($data, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
        return new self($status, $json ?: '{}', ['Content-Type' => 'application/json']);
    }

    public static function text(string $text, int $status = 200): self
    {
        return new self($status, $text, ['Content-Type' => 'text/plain; charset=utf-8']);
    }

    public static function html(string $html, int $status = 200): self
    {
        return new self($status, $html, ['Content-Type' => 'text/html; charset=utf-8']);
    }

    public function withHeader(string $name, string $value): self
    {
        $this->headers[$name] = $value;
        return $this;
    }

    public function getStatusCode(): int
    {
        return $this->statusCode;
    }

    public function getBody(): string
    {
        return $this->body;
    }

    /**
     * Serializes into wire-format HTTP/1.1 response string.
     */
    public function toWireString(): string
    {
        $this->headers['Content-Length'] = (string)strlen($this->body);
        if (!isset($this->headers['Connection'])) {
            $this->headers['Connection'] = 'keep-alive';
        }
        if (!isset($this->headers['Server'])) {
            $this->headers['Server'] = 'UNUM-Sovereign-Silicon/1.0';
        }

        $out = "HTTP/1.1 {$this->statusCode} {$this->statusText}\r\n";
        foreach ($this->headers as $key => $val) {
            $out .= "{$key}: {$val}\r\n";
        }
        $out .= "\r\n";
        $out .= $this->body;

        return $out;
    }
}
