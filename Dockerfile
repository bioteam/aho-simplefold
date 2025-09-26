# © 2025 BioTeam, LLC All rights reserved.

FROM nvidia/cuda:13.0.1-cudnn-devel-ubuntu24.04

LABEL maintainer="AWS HealthOmics SimpleFold Docker"
LABEL description="Docker container for SimpleFold protein structure prediction with CUDA support"
LABEL version="1.0.0"
LABEL repository="https://github.com/bioteam/aho-simplefold"

# main 10/09/2025
ARG COMMIT_SHA="ff4b91daca2ef8cafe83e3e80140bcce6a3136d1"

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

ENV FORCE_CUDA=1
ENV TORCH_CUDA_ARCH_LIST="7.5;8.0;8.6"
ENV PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

# Install Python 3.12
RUN apt-get update && apt-get install -y software-properties-common && \
    add-apt-repository ppa:deadsnakes/ppa && \
    apt-get update && \
    apt-get install -y python3.12 python3.12-dev python3.12-venv python3-pip && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 1 && \
    update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    wget \
    curl \
    cmake \
    libssl-dev \
    redis-server \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Create Python virtual environment
RUN python3 -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

# Install Python build tools in venv
RUN pip install --no-cache-dir --upgrade pip build setuptools wheel

# Clone the SimpleFold repository and checkout the correct commit
RUN git clone https://github.com/apple/ml-simplefold.git /app/ml-simplefold && \
    cd /app/ml-simplefold && \
    git checkout ${COMMIT_SHA}

# Change to the project directory
WORKDIR /app/ml-simplefold

# Install SimpleFold package and dependencies
RUN pip install --no-cache-dir -e .

# Install optional ESM from Facebook Research (for MLX backend)
RUN pip install --no-cache-dir git+https://github.com/facebookresearch/esm.git

# Pre-download ESM models to cache them in the Docker image
RUN python3 -c "import torch; torch.hub.load('facebookresearch/esm:main', 'esm2_t36_3B_UR50D')"

# Create directories for input/output
RUN mkdir -p /app/input /app/output /app/data /app/ml-simplefold/artifacts /app/ml-simplefold/cache

# Download CCD database for Redis (required for mmcif processing)
RUN wget -O /app/ccd.rdb https://boltz1.s3.us-east-2.amazonaws.com/ccd.rdb
RUN wget -O /app/ml-simplefold/artifacts/simplefold_100M.ckpt https://ml-site.cdn-apple.com/models/simplefold/simplefold_100M.ckpt
RUN wget -O /app/ml-simplefold/artifacts/plddt.ckpt https://ml-site.cdn-apple.com/models/simplefold/plddt_module_1.6B.ckpt
# TODO: Why needed if model specified? https://github.com/apple/ml-simplefold/blob/d844b3566259d1fd1a7895da9061986cec7ccaf7/src/simplefold/wrapper.py#L150
RUN wget -O /app/ml-simplefold/artifacts/simplefold_1.6B.ckpt https://ml-site.cdn-apple.com/models/simplefold/simplefold_1.6B.ckpt
RUN wget -O /app/ml-simplefold/cache/ccd.pkl https://huggingface.co/boltz-community/boltz-1/resolve/main/ccd.pkl
RUN wget -O /app/ml-simplefold/cache/boltz1_conf.ckpt https://huggingface.co/boltz-community/boltz-1/resolve/main/boltz1_conf.ckpt

# Copy startup script
COPY scripts/start_redis.sh /app/start_redis.sh
RUN chmod +x /app/start_redis.sh

# Set up volumes for data persistence
VOLUME ["/app/input", "/app/output", "/app/data"]

# Default command - start Redis and then provide shell access
ENTRYPOINT ["/app/start_redis.sh"]

CMD ["/bin/bash"]

# Health check to ensure Redis is running
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD redis-cli -p 7777 ping || exit 1


# Usage instructions as comments:
# 
# Build the image:
# docker build -t simplefold .
#
# Run with volume mounts for input/output (with GPU support):
# docker run --gpus all -it --rm -v $(pwd)/input:/app/input -v $(pwd)/output:/app/output simplefold
#
# Run inference example (with GPU support):
# docker run --gpus all -it --rm -v $(pwd)/input:/app/input -v $(pwd)/output:/app/output simplefold \
#   simplefold --simplefold_model simplefold_100M --num_steps 500 --tau 0.01 \
#   --nsample_per_protein 1 --plddt --fasta_path /app/input/sequences.fasta \
#   --output_dir /app/output --backend torch
#
# Process mmcif files:
# docker run --gpus all -it --rm -v $(pwd)/data:/app/data -v $(pwd)/output:/app/output simplefold \
#   python src/simplefold/process_mmcif.py --data_dir /app/data --out_dir /app/output --use-assembly
