# $Id: repository.properties $

fgsrepository.repositoryName	= FgsRepos

#fgsrepository.fedoraSoap	   	= https://localhost:8080/fedora/services
fgsrepository.fedoraSoap	   	= http://localhost:8080/fedora/services
fgsrepository.fedoraUser		= {{getv "/fedora/admin/user"}}
fgsrepository.fedoraPass		= {{getv "/fedora/admin/pass"}}
fgsrepository.fedoraObjectDir	= /usr/local/fedora/data/objectStore
fgsrepository.fedoraVersion		= 3.6

fgsrepository.trustStorePath	= TRUSTSTOREPATH
fgsrepository.trustStorePass	= TRUSTSTOREPASS

fgsrepository.defaultGetRepositoryInfoResultXslt = copyXml
