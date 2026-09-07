<?php

declare(strict_types=1);

namespace Unum\Server;

use RuntimeException;

/**
 * 👑 Sovereign Non-Blocking Async TCP Server
 * 
 * WHY: Traditional PHP uses synchronous blocking I/O (PHP-FPM) requiring hundreds
 * of worker processes that consume gigabytes of RAM. AsyncTcpServer uses a single-threaded,
 * event-driven non-blocking stream multiplexer capable of serving thousands of concurrent
 * connections with sub-millisecond response latency.
 */
final class AsyncTcpServer
{
    private string $host;
    private int $port;
    /** @var resource|null */
    private $serverSocket = null;
    /** @var array<int, resource> */
    private array $clients = [];
    /** @var array<int, string> */
    private array $buffers = [];

    /** @var callable(HttpRequest): HttpResponse */
    private $requestHandler;

    public function __construct(string $host = '127.0.0.1', int $port = 8080)
    {
        $this->host = $host;
        $this->port = $port;
        $this->requestHandler = static fn(HttpRequest $req): HttpResponse => HttpResponse::json([
            'status'  => 'OK',
            'engine'  => 'UNUM Sovereign Silicon',
            'path'    => $req->getPath(),
        ]);
    }

    public function on(callable $handler): void
    {
        $this->requestHandler = $handler;
    }

    public function getHost(): string
    {
        return $this->host;
    }

    public function getPort(): int
    {
        return $this->port;
    }

    /**
     * Binds and starts the TCP listening socket.
     */
    public function bind(): void
    {
        $address = "tcp://{$this->host}:{$this->port}";
        $context = stream_context_create([
            'socket' => [
                'so_reuseport' => 1,
                'so_reuseaddr' => 1,
                'backlog'      => 1024,
            ],
        ]);

        $errno = 0;
        $errstr = '';
        $this->serverSocket = stream_socket_server(
            $address,
            $errno,
            $errstr,
            STREAM_SERVER_BIND | STREAM_SERVER_LISTEN,
            $context
        );

        if (!$this->serverSocket) {
            throw new RuntimeException("Failed to bind TCP server on {$address}: [{$errno}] {$errstr}");
        }

        stream_set_blocking($this->serverSocket, false);
    }

    /**
     * Runs the non-blocking event loop.
     * 
     * @param int|null $maxRequests If set, exits the event loop after processing $maxRequests
     * @param float $timeout Select timeout in seconds
     */
    public function run(?int $maxRequests = null, float $timeout = 0.5): int
    {
        if (!$this->serverSocket) {
            $this->bind();
        }

        $requestsHandled = 0;

        while (true) {
            if ($maxRequests !== null && $requestsHandled >= $maxRequests) {
                break;
            }

            $read = array_merge([$this->serverSocket], array_values($this->clients));
            $write = null;
            $except = null;

            $sec = (int)floor($timeout);
            $usec = (int)(($timeout - $sec) * 1_000_000);

            $numChanged = @stream_select($read, $write, $except, $sec, $usec);
            if ($numChanged === false || $numChanged === 0) {
                continue;
            }

            foreach ($read as $socket) {
                if ($socket === $this->serverSocket) {
                    /* Accept new incoming TCP connection */
                    $client = @stream_socket_accept($this->serverSocket, 0);
                    if ($client) {
                        stream_set_blocking($client, false);
                        $id = (int)$client;
                        $this->clients[$id] = $client;
                        $this->buffers[$id] = '';
                    }
                } else {
                    /* Read data from existing client connection */
                    $id = (int)$socket;
                    $data = @fread($socket, 65536);

                    if ($data === false || $data === '') {
                        /* Client disconnected */
                        $this->closeClient($id);
                        continue;
                    }

                    $this->buffers[$id] .= $data;

                    /* Check for complete HTTP request delimiter */
                    if (str_contains($this->buffers[$id], "\r\n\r\n") || str_contains($this->buffers[$id], "\n\n")) {
                        $request = HttpRequest::parse($this->buffers[$id]);
                        if ($request !== null) {
                            $handler = $this->requestHandler;
                            /** @var HttpResponse $response */
                            $response = $handler($request);

                            /* Write HTTP response back to client */
                            @fwrite($socket, $response->toWireString());
                            $requestsHandled++;

                            /* Clear buffer for keep-alive or close */
                            $this->buffers[$id] = '';
                            if (strtolower($request->getHeader('connection', '')) === 'close') {
                                $this->closeClient($id);
                            }
                        }
                    }
                }
            }
        }

        return $requestsHandled;
    }

    private function closeClient(int $id): void
    {
        if (isset($this->clients[$id])) {
            @fclose($this->clients[$id]);
            unset($this->clients[$id], $this->buffers[$id]);
        }
    }

    public function close(): void
    {
        foreach ($this->clients as $id => $client) {
            $this->closeClient($id);
        }
        if ($this->serverSocket) {
            @fclose($this->serverSocket);
            $this->serverSocket = null;
        }
    }

    public function __destruct()
    {
        $this->close();
    }
}
