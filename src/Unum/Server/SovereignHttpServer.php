<?php

declare(strict_types=1);

namespace Unum\Server;

/**
 * 👑 Sovereign HTTP Web Server Engine
 * 
 * WHY: Replaces Nginx, Apache, Node.js, and PHP-FPM by implementing a sovereign,
 * self-hosted asynchronous HTTP/1.1 micro-framework running directly inside PHP CLI.
 */
final class SovereignHttpServer
{
    private AsyncTcpServer $tcpServer;
    /** @var array<string, array<string, callable(HttpRequest): HttpResponse>> */
    private array $routes = [
        'GET'    => [],
        'POST'   => [],
        'PUT'    => [],
        'DELETE' => [],
    ];

    public function __construct(string $host = '127.0.0.1', int $port = 8080)
    {
        $this->tcpServer = new AsyncTcpServer($host, $port);
        $this->tcpServer->on($this->dispatch(...));
    }

    public function get(string $path, callable $handler): self
    {
        $this->routes['GET'][$path] = $handler;
        return $this;
    }

    public function post(string $path, callable $handler): self
    {
        $this->routes['POST'][$path] = $handler;
        return $this;
    }

    public function route(string $method, string $path, callable $handler): self
    {
        $this->routes[strtoupper($method)][$path] = $handler;
        return $this;
    }

    /**
     * Internal request router & dispatcher.
     */
    public function dispatch(HttpRequest $request): HttpResponse
    {
        $method = $request->getMethod();
        $path = $request->getPath();

        if (isset($this->routes[$method][$path])) {
            $handler = $this->routes[$method][$path];
            return $handler($request);
        }

        /* Built-in health route */
        if ($path === '/_health') {
            return HttpResponse::json([
                'status'  => 'ALIVE',
                'runtime' => 'UNUM Sovereign Bare-Metal Engine',
                'memory'  => memory_get_usage(true),
            ]);
        }

        return HttpResponse::json([
            'error'  => 'Not Found',
            'path'   => $path,
            'method' => $method,
        ], 404);
    }

    /**
     * Starts listening and runs event loop.
     */
    public function listen(?int $maxRequests = null, float $timeout = 0.5): int
    {
        return $this->tcpServer->run($maxRequests, $timeout);
    }

    /**
     * Runs the non-blocking event loop indefinitely.
     */
    public function run(?int $maxRequests = null, float $timeout = 0.5): int
    {
        return $this->listen($maxRequests, $timeout);
    }

    public function close(): void
    {
        $this->tcpServer->close();
    }
}
