<?php

declare(strict_types=1);

namespace Unum\Ai;

use FFI;
use InvalidArgumentException;
use Unum\HardwareExecutor;
use Unum\Tensor\Tensor2D;

/**
 * 👑 Sovereign Bare-Metal Transformer Block
 * 
 * WHY: The basic repeating unit of modern Deep Learning LLMs (e.g. LLaMA, GPT-4, Mistral).
 * Combines Pre-Layer RMS Normalization, Multi-Head Self-Attention with RoPE,
 * Residual Addition, and a high-speed GELU Feed-Forward Network (FFN),
 * all executing in CPU silicon with zero Python/PyTorch runtime.
 */
final class TransformerBlock
{
    private int $hiddenDim;
    private int $ffnDim;
    private HardwareExecutor $executor;

    private FFI\CData $norm1Weight;
    private MultiHeadAttention $mha;
    private FFI\CData $norm2Weight;

    private Tensor2D $wGate;
    private Tensor2D $wDown;

    public function __construct(
        int $hiddenDim,
        int $numHeads,
        int $ffnDim,
        ?HardwareExecutor $executor = null
    ) {
        $this->hiddenDim = $hiddenDim;
        $this->ffnDim = $ffnDim;
        $this->executor = $executor ?? new HardwareExecutor();

        /* Initialize RMSNorm 1 & 2 weights (gamma vectors initialized to 1.0) */
        $this->norm1Weight = $this->executor->newFloatBuffer($hiddenDim);
        $this->norm2Weight = $this->executor->newFloatBuffer($hiddenDim);
        for ($i = 0; $i < $hiddenDim; $i++) {
            $this->norm1Weight[$i] = 1.0;
            $this->norm2Weight[$i] = 1.0;
        }

        /* Initialize Multi-Head Self-Attention */
        $this->mha = new MultiHeadAttention($hiddenDim, $numHeads, null, null, null, null, $this->executor);

        /* Initialize Feed-Forward Network (FFN) projections */
        $scale = 1.0 / sqrt((float)$hiddenDim);
        $this->wGate = Tensor2D::random($hiddenDim, $ffnDim, -$scale, $scale, $this->executor);
        $this->wDown = Tensor2D::random($ffnDim, $hiddenDim, -$scale, $scale, $this->executor);
    }

    /**
     * Executes the forward pass through the complete transformer block.
     * 
     * @param Tensor2D $x Input tensor of shape (seq_len, hiddenDim)
     * @param int $posOffset Autoregressive token position offset
     * @return Tensor2D Output tensor of shape (seq_len, hiddenDim)
     */
    public function forward(Tensor2D $x, int $posOffset = 0): Tensor2D
    {
        $seqLen = $x->rows();

        /* 1. Pre-Attention RMSNorm: x_norm = RMSNorm(x, norm1Weight) */
        $norm1Buf = $this->executor->newFloatBuffer($seqLen * $this->hiddenDim);
        for ($r = 0; $r < $seqLen; $r++) {
            $offset = $r * $this->hiddenDim;
            $rowIn = FFI::addr($x->getBuffer()[$offset]);
            $rowOut = FFI::addr($norm1Buf[$offset]);
            $this->executor->tensorRmsNorm($rowIn, $this->norm1Weight, $rowOut, $this->hiddenDim);
        }
        $xNorm1 = new Tensor2D($seqLen, $this->hiddenDim, $norm1Buf, $this->executor);

        /* 2. Multi-Head Attention */
        $attnOut = $this->mha->forward($xNorm1, $posOffset);

        /* 3. First Residual Connection: h = x + attnOut */
        $h = $x->add($attnOut);

        /* 4. Pre-FFN RMSNorm: h_norm = RMSNorm(h, norm2Weight) */
        $norm2Buf = $this->executor->newFloatBuffer($seqLen * $this->hiddenDim);
        for ($r = 0; $r < $seqLen; $r++) {
            $offset = $r * $this->hiddenDim;
            $rowIn = FFI::addr($h->getBuffer()[$offset]);
            $rowOut = FFI::addr($norm2Buf[$offset]);
            $this->executor->tensorRmsNorm($rowIn, $this->norm2Weight, $rowOut, $this->hiddenDim);
        }
        $hNorm2 = new Tensor2D($seqLen, $this->hiddenDim, $norm2Buf, $this->executor);

        /* 5. Feed-Forward Network: ffnOut = GELU(hNorm2 * wGate) * wDown */
        $gateOut = $hNorm2->matmul($this->wGate);
        $gateOut->gelu(true); // In-place vectorized GELU activation
        $ffnOut = $gateOut->matmul($this->wDown);

        /* 6. Second Residual Connection: output = h + ffnOut */
        return $h->add($ffnOut);
    }
}
