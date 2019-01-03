# ![logo](docs/logo.png) PerlQube

## Install

With _docker_ :

```bash
docker pull registry.gitlab.com/geoffrey-grebert/perlqube:master
docker run -t --rm registry.gitlab.com/geoffrey-grebert/perlqube:master perlqube --version
```

Locally on _Linux_ :

```bash
sudo curl -L "https://gitlab.com/api/v4/projects/10037096/jobs/artifacts/master/raw/perlqube?job=build" -o /usr/local/bin/perlqube
chmod +x /usr/local/bin/perlqube
perlqube --version
```

## Usage

```bash
perlqube --help
```

## Demo

* [JSON output](https://gitlab.com/geoffrey-grebert/perlqube/-/jobs/artifacts/master/file/perlqube.json?job=critic)
* [HTML output](https://gitlab.com/geoffrey-grebert/perlqube/-/jobs/artifacts/master/file/report/index.html?job=critic)
