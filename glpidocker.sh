## glpidocker.sh Versão 1.0
## Autor Marcos Ferreira da Rocha
## O que ele faz ?
## Informa ao dockerfile qual versão do GL, Senha Root do MariaDB e os comandos padr�es que ser�o executado nos novos containes dessa imagem
## O script  cria também volumes para a prsistência dos dados do container glpi
##
## Uso
##
## sh glpidocker.sh versao-do-glpi prefixo-dosvolumes endereço-ip  -v¹ Senha-do-Banco-de-Dados
##
## OBS: ¹(se for informado o -v o script cria novos volumes,se for omitido ele usará o de meso  nome )
##
## Exemplo :
## bash glpidocker.sh 9.2.2 184 192.168.50.184 -v 12345
##
## $1 Versão do GLPi
## $2 Nome dos Volumes
## $3 IP exclusivo para o container
## $4 -v Informa se cria ou não um novo volume
## $5 Senha do usuário do banco de dados MariaDB
##
## Criando volumes para persistência de dados
## O -v checa se  é necessário criar vos volumes ou usar algum existente

if [ $4 == "-v" ]; then
docker volume create $2glpi
docker volume create $2mariadbconf
docker volume create $2mariadbdados
fi

## Arquivo Dockerfile Gerado em tempo de execuação atrés doEOF

cat << EOF > Dockerfile 
FROM ubuntu:16.04
MAINTAINER Marcos Ferreira da Rocha <marcos.fr.rocha@gmail.com>

ENV GLPI_VERSION $1
                                                      
ENV PATH="/opt/:${PATH}"
            
RUN apt update  && apt  install \
	php7.0 \
	php7.0-xml  \
	php7.0-bcmath \ 
	php7.0-imap \ 
	php-soap \ 
	php7.0-cli \
	php7.0-common \
	php7.0-snmp \
	php7.0-xmlrpc \
	php7.0-gd \
	php7.0-ldap \
	libapache2-mod-php7.0 \
	php7.0-curl \
	php7.0-mbstring \
	php7.0-mysql \
	php-dev \
	php-pear \
	libmariadbd18 \ 
	libmariadbd-dev \ 
	mariadb-server \ 
	apache2  -y

## Utilitários
RUN apt install unzip curl snmp nano wget vim  -y


RUN \
	echo "no" | pecl install apcu_bc-beta  && \
	echo "[apcu]\nextension=apcu.so\nextension=apc.so\n\napc.enabled=1" > /etc/php/7.0/apache2/php.ini  

## Config Apache

RUN \
	touch /etc/apache2/conf-available/glpi.conf && \
        echo "<VirtualHost *:80>\n\tDocumentRoot /var/www/html/glpi\n\n\t<Directory /var/www/html/glpi>\n\t\tAllowOverride All\n\t\tOrder Allow,Deny\n\t\tAllow from all\n\t</Directory>\n\n\tErrorLog /var/log/apache2/error-glpi.log\n\tLogLevel warn\n\tCustomLog /var/log/apache2/access-glpi.log combined\n</VirtualHost>" > /etc/apache2/conf-available/glpi.conf && \
        a2enconf glpi.conf && \
        echo "*/5 * * * * /usr/bin/php /var/www/html/glpi/front/cron.php &>/dev/null" >> /etc/cron

## Definindo a porta de acesso ao serviço
EXPOSE 80

##  Criando script para executar o apache, mariaDB e o bash no boot do container
RUN echo ' \n\
#!/bin/bash \n\
/etc/init.d/mysql start \n\
/etc/init.d/apache2 start \n\
/bin/bash' > /usr/bin/glpi

RUN chmod +x /usr/bin/glpi


## Config MariaDB

RUN \
	/etc/init.d/mysql start && \
	mysql -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '$5';  FLUSH PRIVILEGES;" 



# Baixando e GLPI

ADD  https://github.com/glpi-project/glpi/releases/download/$1/glpi-$1.tgz  ./
RUN	tar -xzf  glpi-$1.tgz -C /var/www/html \
	&& chmod 775 -Rf /var/www/html/glpi  \
	&& chown www-data. -Rf /var/www/html/glpi


## Definindo o scrit para executar no boot do container
CMD /usr/bin/glpi
 
EOF


## Criando uma imagem docker do GLPI

docker build  -t ferreirarocha/$2 .


## Executando um container com persistência de dado.

docker container run -it -v $2glpi:/var/www/html -v $2mariadbdados:/var/lib/mysql -v $2mariadbconf:/etc/mysql/conf.d --rm -p $3:80:80 ferreirarocha/$2:latest


