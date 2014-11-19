FROM codenvy/jdk7

# Install Ruby, Npm, Mongo, Foremam, Less and Entr
RUN sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && \
    echo 'deb http://downloads-distro.mongodb.org/repo/debian-sysvinit dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list && \
    sudo apt-get update && \
    sudo apt-get -y --no-install-recommends install adduser mongodb-org npm ruby entr && \
    sudo npm install -g less && \
    sudo gem install foreman

# Setup Mongo storage
RUN sudo mkdir -p /data/db/
RUN sudo chown `id -u` /data/db

# Install Leiningen
RUN mkdir /home/user/leiningen && \
  	 wget -P /home/user/leiningen -q https://raw.githubusercontent.com/technomancy/leiningen/stable/bin/lein && \
    chmod u+x /home/user/leiningen/lein

# Add Leiningen to path
ENV PATH /home/user/leiningen:$PATH
RUN echo "export PATH=$PATH" >> /home/user/.bashrc
USER root
RUN /home/user/leiningen/lein
USER user

# Create an app dir and add app sources
RUN mkdir /home/user/app
ADD $app$ /home/user/app/


# Configure and expose application port
ENV CODENVY_APP_PORT_5000_HTTP 5000
EXPOSE 5000

# Execute ./dev script that builds Clojure app and runs it on 5000 port
CMD cd /home/user/app/bin && sudo chmod a+x dev && ./dev