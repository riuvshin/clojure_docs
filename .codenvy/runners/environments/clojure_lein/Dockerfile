FROM eivantsov/clojure_lein
ADD $app$ /home/user/app/
RUN chown user:user /home/user/app
USER root
CMD cd /home/user/app/bin && chmod a+x dev && ./dev 2>&1 /dev/null
