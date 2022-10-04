FROM rocker/r-base

COPY . .

# install dependencies
RUN R -e "options(repos = list(CRAN = 'https://cran.ma.imperial.ac.uk/')) ; install.packages('argparser'); install.packages('SKAT'); install.packages('dplyr')"

# define the port number the container should expose
EXPOSE 5000
