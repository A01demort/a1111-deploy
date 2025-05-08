FROM nvidia/cuda:12.1.1-cudnn8-runtime-ubuntu20.04

ENV DEBIAN_FRONTEND=noninteractive
ENV PIP_CACHE_DIR=/workspace/.cache/pip

# 필수 시스템 패키지 설치
RUN apt-get update && apt-get install -y \
    git wget curl ffmpeg libgl1 \
    build-essential libssl-dev zlib1g-dev libbz2-dev \
    libreadline-dev libsqlite3-dev libncurses5-dev \
    libncursesw5-dev xz-utils tk-dev libffi-dev \
    liblzma-dev software-properties-common \
    locales sudo tzdata xterm nano \
    nodejs npm && \
    apt-get clean

# 정확한 Python 3.10.6 설치
WORKDIR /tmp
RUN wget https://www.python.org/ftp/python/3.10.6/Python-3.10.6.tgz && \
    tar xzf Python-3.10.6.tgz && cd Python-3.10.6 && \
    ./configure --enable-optimizations && \
    make -j$(nproc) && make altinstall && \
    ln -sf /usr/local/bin/python3.10 /usr/bin/python && \
    ln -sf /usr/local/bin/python3.10 /usr/bin/python3 && \
    ln -sf /usr/local/bin/pip3.10 /usr/bin/pip && \
    ln -sf /usr/local/bin/pip3.10 /usr/local/bin/pip && \
    cd / && rm -rf /tmp/*

# 최신 Node.js 18 재설치
RUN apt-get remove -y nodejs npm && \
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs && \
    node -v && npm -v

# 작업 디렉토리
WORKDIR /workspace
RUN mkdir -p /workspace && chmod -R 777 /workspace && chown -R root:root /workspace

# Python 패키지 설치
RUN pip install --upgrade pip && \
    pip install torch==2.1.1 torchvision==0.16.1 torchaudio==2.1.1 --index-url https://download.pytorch.org/whl/cu121 && \
    pip install xformers==0.0.22.post7 --extra-index-url https://download.pytorch.org/whl/cu121 && \
    pip install pydantic==1.10.13 rich ultralytics opencv-python-headless numpy

# JupyterLab 설치 및 설정
RUN pip install --force-reinstall jupyterlab==3.6.6 jupyter-server==1.23.6 && \
    mkdir -p /root/.jupyter && \
    echo "c.NotebookApp.allow_origin = '*'\n\
c.NotebookApp.ip = '0.0.0.0'\n\
c.NotebookApp.open_browser = False\n\
c.NotebookApp.token = ''\n\
c.NotebookApp.password = ''\n\
c.NotebookApp.terminado_settings = {'shell_command': ['/bin/bash']}" \
> /root/.jupyter/jupyter_notebook_config.py

# WebUI 리포지토리만 빌드에 포함
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git /workspace/stable-diffusion-webui

# ESRGAN 폴더 없으면 생성
RUN mkdir -p /workspace/stable-diffusion-webui/models/ESRGAN

# hugging_down.sh 파일 및 설치 스크립트 복사
# 런타임 설치 스크립트 복사
COPY Hugging_down_a1.sh /workspace/Hugging_down_a1.sh
COPY runpod_start.sh /workspace/runpod_start.sh
RUN chmod +x /workspace/runpod_start.sh

# 포트 오픈
EXPOSE 7860
EXPOSE 8888

# 병렬 실행: Jupyter + WebUI 런타임 설치 및 실행
CMD bash -c "\
jupyter lab --ip=0.0.0.0 --port=8888 --allow-root \
--ServerApp.token='' --ServerApp.password='' & \
/workspace/runpod_start.sh & \
wait"
