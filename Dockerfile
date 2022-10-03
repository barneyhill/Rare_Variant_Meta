FROM r-base:4.2.1

COPY . .

# install dependencies
RUN R -e "install.packages('argparser')"
RUN R -e "install.packages('SKAT')"
RUN R -e "install.packages('data.table')"
RUN R -e "install.packages('dplyr')"

# define the port number the container should expose
EXPOSE 5000
