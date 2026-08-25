# Acoustic Echo Cancellation Using NLMS Adaptive Filtering and Modulation-Domain Suppression

A MATLAB-based hybrid acoustic echo cancellation framework combining **Room Impulse Response (RIR) simulation, NLMS adaptive filtering, and modulation-domain speech enhancement** for suppressing acoustic echo and background noise.

## Overview

Acoustic echo is a major challenge in hands-free communication systems such as video conferencing, smart speakers, and voice communication devices. Loudspeaker output can propagate through the acoustic environment, reflect from room surfaces, and reach the microphone as a delayed echo.

This project develops a two-stage signal-processing framework. The first stage uses **Normalized Least Mean Square (NLMS) adaptive filtering** to estimate and suppress the dominant acoustic echo. The second stage applies **modulation-domain speech enhancement** to further reduce residual echo and background noise while preserving the desired speech components.

## Objectives

- Generate realistic Room Impulse Responses (RIRs) using the Image Source Method.
- Simulate acoustic echo under different room reverberation conditions.
- Implement NLMS adaptive filtering for acoustic echo cancellation.
- Suppress residual echo and background noise using modulation-domain processing.
- Evaluate the framework under different background noise conditions and input SNR levels.
- Assess performance using objective speech quality and intelligibility metrics.

## Methodology

<img width="1536" height="1024" alt="Architecture Diagram" src="https://github.com/user-attachments/assets/ed5c1aa7-4b1d-4845-8615-0feab8b40669" />

The proposed framework consists of two main stages:

### 1. Acoustic Echo Cancellation

The far-end speech is propagated through a simulated acoustic environment using the generated Room Impulse Response (RIR). The resulting acoustic echo is combined with near-end speech and background noise to form the microphone signal. The dominant acoustic echo is then estimated and suppressed using NLMS adaptive filtering.

### 2. Modulation-Domain Speech Enhancement

The residual signal from the NLMS stage is processed using STFT-based modulation-domain speech enhancement. **Noise PSD estimation, a-priori SNR estimation, Wiener gain computation, gain smoothing, and ISTFT reconstruction** are used to reduce residual echo and background noise while preserving important speech components.

## Experimental Configuration

<img width="577" height="407" alt="image" src="https://github.com/user-attachments/assets/1f37f2fb-135d-4ccb-b82e-2eef69378137" />

## Performance Evaluation

The proposed framework is evaluated using the following objective metrics:

- **ERLE** – Echo Return Loss Enhancement
- **SNRout** – Output Signal-to-Noise Ratio
- **SI-SDR** – Scale-Invariant Signal-to-Distortion Ratio
- **STOI** – Short-Time Objective Intelligibility

These metrics are used to assess acoustic echo suppression, speech quality, signal distortion, and speech intelligibility.

## Results

The framework was evaluated under three room environments, six background noise conditions, and input SNR levels ranging from −10 dB to 20 dB.

The results demonstrate effective suppression of the dominant acoustic echo using NLMS adaptive filtering, followed by further reduction of residual echo and background noise through modulation-domain processing.

The objective evaluation shows improvements in speech quality and intelligibility across the evaluated acoustic conditions.

## Applications

- Hands-free communication systems
- Video conferencing
- Smart speakers
- Voice communication systems
- Teleconferencing
- Speech-enabled devices

## Research Publication

This project work has been published as a research paper:

**Paper Title:**  
*Acoustic Echo Cancellation Using NLMS Adaptive Filtering and Modulation-Domain Suppression*

**Journal:** IJRASET  
**Volume:** Volume 14, Issue VII  
**Publication:** July 2026

## Future Work

Future work will focus on:

- Double-talk detection
- Adaptive residual echo suppression
- Evaluation using measured Room Impulse Responses
- Real-time implementation
- Validation in practical hands-free communication environments
