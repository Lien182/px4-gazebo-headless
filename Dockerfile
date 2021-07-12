
FROM ubuntu:18.04


ENV WORKSPACE_DIR /root
ENV FIRMWARE_DIR ${WORKSPACE_DIR}/Firmware
ENV SITL_RTSP_PROXY ${WORKSPACE_DIR}/sitl_rtsp_proxy

ENV DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true
ENV DISPLAY :99
ENV LANG C.UTF-8

RUN apt-get update && apt-get install wget gnupg2 -y
RUN sh -c 'echo "deb http://packages.osrfoundation.org/gazebo/ubuntu-stable bionic main" > /etc/apt/sources.list.d/gazebo-stable.list'
RUN wget https://packages.osrfoundation.org/gazebo.key -O - | apt-key add -


RUN apt-get update && \
    apt-get install -y bc \
                       cmake \
                       curl \
                       git \
                       libeigen3-dev \
                       libopencv-dev \
                       libroscpp-dev \
                       protobuf-compiler \
                       python3-pip \
                       unzip \
                       gazebo9 \
                       libgazebo9-dev \
                       gstreamer1.0-plugins-bad \
                       gstreamer1.0-plugins-base \
                       gstreamer1.0-plugins-good \
                       gstreamer1.0-plugins-ugly \
                       libgstreamer-plugins-base1.0-dev \
                       libgstrtspserver-1.0-dev \
                       xvfb \
                       python3-numpy  \
                       openjdk-11-jdk && \
    apt-get -y autoremove && \
    apt-get clean autoclean && \
    rm -rf /var/lib/apt/lists/{apt,dpkg,cache,log} /tmp/* /var/tmp/*

RUN pip3 install empy \
                 jinja2 \
                 packaging \
                 pyros-genmsg \
                 toml \
                 pyyaml

RUN git clone https://github.com/eProsima/foonathan_memory_vendor.git ${WORKSPACE_DIR}/foonathan_memory_vendor \
    && cd ${WORKSPACE_DIR}/foonathan_memory_vendor \
    && mkdir build \
    && cd build \
    && cmake .. \
    && cmake --build . --target install

RUN git clone --recursive https://github.com/eProsima/Fast-DDS.git -b v2.0.0 ${WORKSPACE_DIR}/FastDDS-2.0.0 \
    && cd ${WORKSPACE_DIR}/FastDDS-2.0.0 \
    && mkdir build && cd build \
    && cmake -DTHIRDPARTY=ON -DSECURITY=ON .. \
    && make -j$(nproc --all) \
    && make install


RUN git clone --recursive https://github.com/eProsima/Fast-DDS-Gen.git -b v1.0.4 ${WORKSPACE_DIR}/Fast-RTPS-Gen \
    && cd ${WORKSPACE_DIR}/Fast-RTPS-Gen \
    && ./gradlew assemble \
    && ./gradlew install

RUN git clone https://github.com/Lien182/PX4-Autopilot.git  ${FIRMWARE_DIR}
RUN git -C ${FIRMWARE_DIR} checkout master
RUN git -C ${FIRMWARE_DIR} submodule update --init --recursive

COPY edit_rcS.bash ${WORKSPACE_DIR}
COPY entrypoint.sh /root/entrypoint.sh
RUN chmod +x /root/entrypoint.sh

#just for debugging
#RUN cd ${FIRMWARE_DIR} &&  make px4_sitl list_vmd_make_targets

RUN ["/bin/bash", "-c", " \
    cd ${FIRMWARE_DIR} && \
    DONT_RUN=1 make px4_sitl_rtps gazebo___simple_obstacle && \
    DONT_RUN=1 make px4_sitl_rtps gazebo___simple_obstacle \
"]

COPY sitl_rtsp_proxy ${SITL_RTSP_PROXY}
RUN cmake -B${SITL_RTSP_PROXY}/build -H${SITL_RTSP_PROXY}
RUN cmake --build ${SITL_RTSP_PROXY}/build

ENTRYPOINT ["/root/entrypoint.sh"]
