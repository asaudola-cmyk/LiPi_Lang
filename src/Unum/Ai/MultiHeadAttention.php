<?php

declare(strict_types=1);

namespace Unum\Ai;

use FFI;
use InvalidArgumentException;
use Unum\HardwareExecutor;
use Unum\Tensor\Tensor2D;

/**
 * 👑 Sovereign Multi-Head Scaled Dot-Product Attention (MHA)
 * 
 * WHY: Multi-Head Attention is the computational heart of all modern LLM Transformers
 * (LLaMA, GPT, Claude, Mistral). In traditional stacks, this requires Python, PyTorch,
 * and massive CUDA drivers. Sovereign MHA executes fused Q*K^T, RoPE rotary positional
 * rotations, and attention-weighted V aggregation directly in CPU silicon via AVX-512 and AVX2.
 */
final class MultiHeadAttention
{
    private int $hiddenDim;
    private int $numHeads;
    private int $headDim;
    private HardwareExecutor $executor;

    private Tensor2D $wq;
    private Tensor2D $wk;
    private Tensor2D $wv;
    private Tensor2D $wo;

    public function __construct(
        int $hiddenDim,
        int $numHeads,
        ?Tensor2D $wq = null,
        ?Tensor2D $wk = null,
        ?Tensor2D $wv = null,
        ?Tensor2D $wo = null,
        ?HardwareExecutor $executor = null
    ) {
        if ($hiddenDim % $numHeads !== 0) {
            throw new InvalidArgumentException("hiddenDim ({$hiddenDim}) must be divisible by numHeads ({$numHeads})");
        }

        $this->hiddenDim = $hiddenDim;
        $this->numHeads = $numHeads;
        $this->headDim = (int)($hiddenDim / $numHeads);
        $this->executor = $executor ?? new HardwareExecutor();

        /* Initialize projection matrices or generate normalized random weights */
        $scale = 1.0 / sqrt((float)$hiddenDim);
        $this->wq = $wq ?? Tensor2D::random($hiddenDim, $hiddenDim, -$scale, $scale, $this->executor);
        $this->wk = $wk ?? Tensor2D::random($hiddenDim, $hiddenDim, -$scale, $scale, $this->executor);
        $this->wv = $wv ?? Tensor2D::random($hiddenDim, $hiddenDim, -$scale, $scale, $this->executor);
        $this->wo = $wo ?? Tensor2D::random($hiddenDim, $hiddenDim, -$scale, $scale, $this->executor);
    }

    public function getHiddenDim(): int
    {
        return $this->hiddenDim;
    }

    public function getNumHeads(): int
    {
        return $this->numHeads;
    }

    public function getHeadDim(): int
    {
        return $this->headDim;
    }

    /**
     * Executes the forward attention pass on an input sequence tensor.
     * 
     * @param Tensor2D $x Input tensor of shape (seq_len, hiddenDim)
     * @param int $posOffset Rotary position offset for autoregressive decoding
     * @return Tensor2D Output tensor of shape (seq_len, hiddenDim)
     */
    public function forward(Tensor2D $x, int $posOffset = 0): Tensor2D
    {
        $seqLen = $x->rows();
        if ($x->cols() !== $this->hiddenDim) {
            throw new InvalidArgumentException("Input tensor width {$x->cols()} does not match hiddenDim {$this->hiddenDim}");
        }

        /* 1. Linear projections: Q = X * Wq, K = X * Wk, V = X * Wv */
        $Q = $x->matmul($this->wq);
        $K = $x->matmul($this->wk);
        $V = $x->matmul($this->wv);

        /* 2. Apply Rotary Position Embedding (RoPE) directly to Q and K */
        $this->executor->tensorRope(
            $Q->getBuffer(),
            $K->getBuffer(),
            $seqLen,
            $this->numHeads,
            $this->headDim,
            $posOffset
        );

        /* 3. Scaled Dot-Product Attention: out = Softmax(Q * K^T / sqrt(head_dim)) * V */
        $attnBuf = $this->executor->newFloatBuffer($seqLen * $this->hiddenDim);
        $this->executor->tensorMha(
            $Q->getBuffer(),
            $K->getBuffer(),
            $V->getBuffer(),
            $attnBuf,
            $seqLen,
            $this->numHeads,
            $this->headDim
        );
        $attnOut = new Tensor2D($seqLen, $this->hiddenDim, $attnBuf, $this->executor);

        /* 4. Final linear projection: Output = attnOut * Wo */
        return $attnOut->matmul($this->wo);
    }
}
