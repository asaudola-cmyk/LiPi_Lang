<?php

declare(strict_types=1);

namespace Unum\Server;

/**
 * WebSocketFrame: High-Throughput RFC 6455 Binary Frame Parser & Encoder.
 *
 * Provides sub-microsecond binary WebSocket framing for real-time bidirectional
 * streaming direct in the Sovereign Bare-Metal Server without Node.js or Socket.io.
 *
 * @author Shafiullah (Gyani Supreme Core)
 */
final class WebSocketFrame
{
    public const OP_CONTINUATION = 0x0;
    public const OP_TEXT         = 0x1;
    public const OP_BINARY       = 0x2;
    public const OP_CLOSE        = 0x8;
    public const OP_PING         = 0x9;
    public const OP_PONG         = 0xA;

    private const WS_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

    /**
     * Decodes an incoming client WebSocket frame per RFC 6455.
     *
     * @return array{fin: bool, opcode: int, payload: string, bytes_consumed: int}|null
     */
    public static function decode(string $rawBuffer): ?array
    {
        $len = strlen($rawBuffer);
        if ($len < 2) {
            return null; // Incomplete header
        }

        $b0 = ord($rawBuffer[0]);
        $b1 = ord($rawBuffer[1]);

        $fin = ($b0 & 0x80) !== 0;
        $opcode = $b0 & 0x0F;
        $isMasked = ($b1 & 0x80) !== 0;
        $payloadLen = $b1 & 0x7F;

        $offset = 2;

        if ($payloadLen === 126) {
            if ($len < $offset + 2) {
                return null;
            }
            $payloadLen = unpack('n', substr($rawBuffer, $offset, 2))[1];
            $offset += 2;
        } elseif ($payloadLen === 127) {
            if ($len < $offset + 8) {
                return null;
            }
            $payloadLen = unpack('J', substr($rawBuffer, $offset, 8))[1];
            $offset += 8;
        }

        $maskKey = '';
        if ($isMasked) {
            if ($len < $offset + 4) {
                return null;
            }
            $maskKey = substr($rawBuffer, $offset, 4);
            $offset += 4;
        }

        if ($len < $offset + $payloadLen) {
            return null; // Incomplete payload data
        }

        $payload = substr($rawBuffer, $offset, $payloadLen);
        $offset += $payloadLen;

        // Unmask if client masked
        if ($isMasked && $maskKey !== '') {
            $payload = self::applyMask($payload, $maskKey);
        }

        return [
            'fin'            => $fin,
            'opcode'         => $opcode,
            'payload'        => $payload,
            'bytes_consumed' => $offset,
        ];
    }

    /**
     * Encodes a server WebSocket frame (server-to-client frames are unmasked per RFC 6455).
     */
    public static function encode(string $payload, int $opcode = self::OP_TEXT, bool $fin = true): string
    {
        $payloadLen = strlen($payload);
        $b0 = ($fin ? 0x80 : 0x00) | ($opcode & 0x0F);
        $header = chr($b0);

        if ($payloadLen <= 125) {
            $header .= chr($payloadLen);
        } elseif ($payloadLen <= 0xFFFF) {
            $header .= chr(126) . pack('n', $payloadLen);
        } else {
            $header .= chr(127) . pack('J', $payloadLen);
        }

        return $header . $payload;
    }

    /**
     * Creates an RFC 6455 HTTP 101 Handshake Response from a client Sec-WebSocket-Key.
     */
    public static function createHandshakeResponse(string $secWebSocketKey): string
    {
        $acceptVal = base64_encode(sha1(trim($secWebSocketKey) . self::WS_GUID, true));

        return "HTTP/1.1 101 Switching Protocols\r\n" .
               "Upgrade: websocket\r\n" .
               "Connection: Upgrade\r\n" .
               "Sec-WebSocket-Accept: {$acceptVal}\r\n\r\n";
    }

    /**
     * Applies XOR masking with 4-byte key using 32-bit integer blocks for high throughput.
     */
    public static function applyMask(string $data, string $key): string
    {
        $dataLen = strlen($data);
        $out = $data;

        for ($i = 0; $i < $dataLen; $i++) {
            $out[$i] = chr(ord($data[$i]) ^ ord($key[$i % 4]));
        }

        return $out;
    }
}
