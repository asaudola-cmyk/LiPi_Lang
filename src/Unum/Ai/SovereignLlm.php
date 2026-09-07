<?php

declare(strict_types=1);

namespace Unum\Ai;

use FFI;
use InvalidArgumentException;
use RuntimeException;
use Unum\HardwareExecutor;
use Unum\Tensor\Tensor2D;

/**
 * 👑 Sovereign Bare-Metal Large Language Model (LLM) Engine
 * 
 * WHY: Proves that complete autoregressive LLM Transformer inference can be executed
 * directly in native PHP and CPU silicon without Python, PyTorch, CUDA, HuggingFace,
 * or C++ runtime bindings.
 */
final class SovereignLlm
{
    private int $vocabSize;
    private int $hiddenDim;
    private int $numLayers;
    private int $numHeads;
    private int $ffnDim;
    private HardwareExecutor $executor;

    /** @var Tensor2D Token embedding lookup table (vocabSize x hiddenDim) */
    private Tensor2D $tokenEmbeddings;

    /** @var list<TransformerBlock> */
    private array $layers = [];

    /** @var FFI\CData Final RMSNorm gamma weight vector */
    private FFI\CData $finalNormWeight;

    /** @var Tensor2D Language model projection head (hiddenDim x vocabSize) */
    private Tensor2D $lmHead;

    public function __construct(
        int $vocabSize = 256,
        int $hiddenDim = 64,
        int $numLayers = 2,
        int $numHeads = 4,
        ?int $ffnDim = null,
        ?HardwareExecutor $executor = null
    ) {
        $this->vocabSize = $vocabSize;
        $this->hiddenDim = $hiddenDim;
        $this->numLayers = $numLayers;
        $this->numHeads = $numHeads;
        $this->ffnDim = $ffnDim ?? ($hiddenDim * 4);
        $this->executor = $executor ?? new HardwareExecutor();

        /* 1. Initialize Token Embeddings */
        $scale = 1.0 / sqrt((float)$hiddenDim);
        $this->tokenEmbeddings = Tensor2D::random($vocabSize, $hiddenDim, -$scale, $scale, $this->executor);

        /* 2. Initialize Stacked Transformer Blocks */
        for ($l = 0; $l < $numLayers; $l++) {
            $this->layers[] = new TransformerBlock($hiddenDim, $numHeads, $this->ffnDim, $this->executor);
        }

        /* 3. Final RMSNorm weight */
        $this->finalNormWeight = $this->executor->newFloatBuffer($hiddenDim);
        for ($i = 0; $i < $hiddenDim; $i++) {
            $this->finalNormWeight[$i] = 1.0;
        }

        /* 4. Output LM Head */
        $this->lmHead = Tensor2D::random($hiddenDim, $vocabSize, -$scale, $scale, $this->executor);
    }

    /**
     * Executes the forward pass on an array of token IDs, returning output logits.
     * 
     * @param list<int> $tokenIds Sequence of integer token IDs
     * @return Tensor2D Output logits tensor of shape (seq_len, vocabSize)
     */
    public function forward(array $tokenIds): Tensor2D
    {
        $seqLen = count($tokenIds);
        if ($seqLen === 0) {
            throw new InvalidArgumentException("Token sequence cannot be empty.");
        }

        /* 1. Embedding lookup: construct input hidden state (seq_len x hiddenDim) */
        $hiddenBuf = $this->executor->newFloatBuffer($seqLen * $this->hiddenDim);
        for ($i = 0; $i < $seqLen; $i++) {
            $token = $tokenIds[$i] % $this->vocabSize;
            $srcOffset = $token * $this->hiddenDim;
            $dstOffset = $i * $this->hiddenDim;
            for ($d = 0; $d < $this->hiddenDim; $d++) {
                $hiddenBuf[$dstOffset + $d] = $this->tokenEmbeddings->getBuffer()[$srcOffset + $d];
            }
        }
        $h = new Tensor2D($seqLen, $this->hiddenDim, $hiddenBuf, $this->executor);

        /* 2. Forward through all Transformer Layers */
        foreach ($this->layers as $layer) {
            $h = $layer->forward($h, 0);
        }

        /* 3. Final RMSNorm */
        $finalNormBuf = $this->executor->newFloatBuffer($seqLen * $this->hiddenDim);
        for ($r = 0; $r < $seqLen; $r++) {
            $offset = $r * $this->hiddenDim;
            $rowIn = FFI::addr($h->getBuffer()[$offset]);
            $rowOut = FFI::addr($finalNormBuf[$offset]);
            $this->executor->tensorRmsNorm($rowIn, $this->finalNormWeight, $rowOut, $this->hiddenDim);
        }
        $hNorm = new Tensor2D($seqLen, $this->hiddenDim, $finalNormBuf, $this->executor);

        /* 4. Project to vocabulary logits: logits = hNorm * lmHead */
        return $hNorm->matmul($this->lmHead);
    }

    /**
     * Generates new tokens autoregressively from a given prompt token sequence.
     * 
     * @param list<int> $promptTokens Starting sequence of token IDs
     * @param int $maxNewTokens Number of tokens to generate
     * @param float $temperature Sampling temperature (higher = more creative)
     * @param int $topK Top-K sampling cutoff
     * @return list<int> Complete generated token sequence
     */
    public function generate(
        array $promptTokens,
        int $maxNewTokens = 10,
        float $temperature = 0.8,
        int $topK = 20
    ): array {
        $tokens = $promptTokens;

        for ($step = 0; $step < $maxNewTokens; $step++) {
            $logits = $this->forward($tokens);
            $lastRow = $logits->rows() - 1;

            /* Extract logits for the last generated position */
            $rowLogits = [];
            for ($v = 0; $v < $this->vocabSize; $v++) {
                $rowLogits[$v] = $logits->get($lastRow, $v) / max(0.01, $temperature);
            }

            /* Numerically stable Softmax */
            $maxLogit = max($rowLogits);
            $expSum = 0.0;
            $probs = [];
            foreach ($rowLogits as $v => $l) {
                $p = exp($l - $maxLogit);
                $probs[$v] = $p;
                $expSum += $p;
            }
            foreach ($probs as $v => $p) {
                $probs[$v] = $p / $expSum;
            }

            /* Top-K filter */
            arsort($probs);
            $topProbs = array_slice($probs, 0, max(1, min($topK, $this->vocabSize)), true);
            $normFactor = array_sum($topProbs);

            /* Sample next token */
            $rand = ((float)mt_rand() / (float)mt_getrandmax()) * $normFactor;
            $cum = 0.0;
            $nextToken = array_key_first($topProbs);
            foreach ($topProbs as $candToken => $candProb) {
                $cum += $candProb;
                if ($rand <= $cum) {
                    $nextToken = $candToken;
                    break;
                }
            }

            $tokens[] = (int)$nextToken;
        }

        return $tokens;
    }
}
