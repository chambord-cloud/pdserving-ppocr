FROM python:3.9.20

ENV PPOCR=v2.9.1
ENV DET=ch_PP-OCRv4_det_server_infer
ENV REC=ch_PP-OCRv4_rec_server_infer

RUN sed -i 's#deb.debian.org/debian$#mirrors.tuna.tsinghua.edu.cn/debian#' /etc/apt/sources.list.d/debian.sources 
RUN apt clean
RUN apt update

RUN git clone https://github.com/PaddlePaddle/PaddleOCR.git /PaddleOCR 
RUN cd /PaddleOCR && git checkout tags/$PPOCR
RUN cd /PaddleOCR/deploy/pdserving/

WORKDIR /PaddleOCR/deploy/pdserving/
ADD config.yml /PaddleOCR/deploy/pdserving/

RUN pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple

RUN pip install --upgrade pip
RUN pip3 install paddlepaddle==2.5.1
RUN pip3 install -U numpy==1.26.4

RUN wget http://nz2.archive.ubuntu.com/ubuntu/pool/main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb
RUN dpkg -i libssl1.1_1.1.1f-1ubuntu2_amd64.deb

RUN apt-get update && apt-get install ffmpeg libsm6 libxext6  -y

# 安装serving，用于启动服务
RUN wget https://paddle-serving.bj.bcebos.com/test-dev/whl/paddle_serving_server-0.8.3-py3-none-any.whl
RUN pip3 install paddle_serving_server-0.8.3-py3-none-any.whl
# 如果是cuda10.1环境，可以使用下面的命令安装paddle-serving-server
# wget https://paddle-serving.bj.bcebos.com/test-dev/whl/paddle_serving_server_gpu-0.8.3.post101-py3-none-any.whl
# pip3 install paddle_serving_server_gpu-0.8.3.post101-py3-none-any.whl

# 安装client，用于向服务发送请求
RUN wget https://paddle-serving.bj.bcebos.com/test-dev/whl/paddle_serving_client-0.8.3-cp39-none-any.whl
RUN pip3 install paddle_serving_client-0.8.3-cp39-none-any.whl

# 安装serving-app
RUN wget https://paddle-serving.bj.bcebos.com/test-dev/whl/paddle_serving_app-0.8.3-py3-none-any.whl
RUN pip3 install paddle_serving_app-0.8.3-py3-none-any.whl

# 下载并解压 OCR 文本检测模型
RUN wget https://paddleocr.bj.bcebos.com/PP-OCRv4/chinese/$DET.tar -O $DET.tar && tar -xf $DET.tar
# 下载并解压 OCR 文本识别模型
RUN wget https://paddleocr.bj.bcebos.com/PP-OCRv4/chinese/$REC.tar -O $REC.tar &&  tar -xf $REC.tar

# 转换检测模型
RUN python3 -m paddle_serving_client.convert --dirname ./$DET/ \
        --model_filename inference.pdmodel          \
        --params_filename inference.pdiparams       \
        --serving_server ./ppocr_det_v4_serving/ \
        --serving_client ./ppocr_det_v4_client/

# 转换识别模型
RUN python3 -m paddle_serving_client.convert --dirname ./$REC/ \
        --model_filename inference.pdmodel          \
        --params_filename inference.pdiparams       \
        --serving_server ./ppocr_rec_v4_serving/  \
        --serving_client ./ppocr_rec_v4_client/

EXPOSE 9998
CMD ["/bin/bash","-c","python3 web_service.py --config=config.yml"]
