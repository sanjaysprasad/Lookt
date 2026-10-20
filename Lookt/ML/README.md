# MobileFaceNet Neural Face Embedding Model

This directory contains the compiled CoreML model (`FaceEmbedding.mlmodelc`) used for real-time facial recognition in Lookt.

## Architecture
- **Model**: MobileFaceNet (ArcFace)
- **Input**: `[1, 3, 112, 112]` RGB image normalized to `[-1.0, 1.0]`
- **Output**: `[1, 512]` 512-dimensional facial identity embedding vector (L2-normalized)
- **Hardware Acceleration**: Apple Neural Engine (ANE) via `MLModelConfiguration.computeUnits = .all`
- **Inference Latency**: ~3-4ms on Apple Silicon (M1–M4)

## Attribution & Credits
- **Architecture & Training**: MobileFaceNet by Sheng Chen, Yang Liu, Xiang Gao, and Zhen Han (ArcFace loss / InsightFace).
- **CoreML Model Bundle**: Sourced from [FaceGate-Mac](https://github.com/dweep-desai/FaceGate-Mac) by Dweep Desai (licensed under the MIT License).
