FROM r-base:4.1.0

COPY RV_meta.R .
COPY Lib_v3.R .

# install dependencies
RUN R -e "options(repos = list(CRAN = 'https://cran.ma.imperial.ac.uk/')) ; install.packages('argparser'); install.packages('data.table'); install.packages('SKAT'); install.packages('dplyr')"

# define the port number the container should expose
EXPOSE 5000
