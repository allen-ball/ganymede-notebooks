# ----------------------------------------------------------------------------
# Makefile
# ----------------------------------------------------------------------------
export LANG=en_US.UTF-8
export LC_ALL=$(LANG)

export PYTHON?=$(shell which python)

export PIPENV_IGNORED_INSTALLED=1
export PIPENV_VENV_IN_PROJECT=1
export PIPENV_YES=1

ifeq ("$(shell echo $$TERM)","dumb")
export NO_COLOR=1

export PIPENV_HIDE_EMOJIS=1
export PIPENV_NOSPIN=1
endif

PIPENV=pipenv --bare --python=$(PYTHON)
DOTENV=$(PIPENV) run dotenv -f $(DOT_ENV)

PIPFILE=Pipfile
DOT_VENV=$(realpath $(dir $(firstword $(MAKEFILE_LIST))))/.venv
DOT_ENV=$(dir $(DOT_VENV))/.env

all::	$(DOT_VENV)

ENVVARS=
# ----------------------------------------------------------------------------
# JupyterLab
# ----------------------------------------------------------------------------
KERNELS+=
NBEXTENSIONS+=
SERVEREXTENSIONS+=

JUPYTER=$(PIPENV) run jupyter

PACKAGES+=jupyterlab virtualenv
# https://github.com/ipython-contrib/jupyter_contrib_nbextensions/issues/1529
# https://github.com/jfbercher/jupyter_latex_envs/pull/58
PACKAGES+=git+https://github.com/ipython-contrib/jupyter_contrib_nbextensions.git
PACKAGES+=git+https://github.com/jfbercher/jupyter_latex_envs.git
PACKAGES+=nbconvert
# ----------------------------------------------------------------------------
ENVVARS+=JAVA_HOME
ifeq ("$(shell uname -s)","Darwin")
export JAVA_HOME?=$(shell /usr/libexec/java_home -v 11)
endif
ifeq ("$(shell uname -s)","Linux")
export JAVA_HOME?=/usr/lib/jvm/adoptopenjdk-11-hotspot-amd64
endif
# ----------------------------------------------------------------------------
SPARK_VERSION?=3.3.1
HADOOP_VERSION?=3
SPARK_HOME?=$(DOT_VENV)/spark-$(SPARK_VERSION)-bin-hadoop$(HADOOP_VERSION)
# ----------------------------------------------------------------------------
# Ganymede
# ----------------------------------------------------------------------------
KERNELS+=ganymede

GANYMEDE_RELEASE_VERSION?=2.1.1.20221231
GANYMEDE_RELEASE_URL?=https://github.com/allen-ball/ganymede/releases/download/v$(GANYMEDE_RELEASE_VERSION)/ganymede-$(GANYMEDE_RELEASE_VERSION).jar
GANYMEDE_RELEASE_JAR?=$(DOT_VENV)/ganymede-$(GANYMEDE_RELEASE_VERSION).jar
GANYMEDE_RELEASE_SPARK_VERSION?=$(SPARK_VERSION)
GANYMEDE_RELEASE_HADOOP_VERSION?=$(HADOOP_VERSION)
GANYMEDE_RELEASE_SPARK_HOME?=$(DOT_VENV)/spark-$(GANYMEDE_RELEASE_SPARK_VERSION)-bin-hadoop$(GANYMEDE_RELEASE_HADOOP_VERSION)

GANYMEDE_SNAPSHOT_VERSION?=2.2.0-SNAPSHOT
GANYMEDE_SNAPSHOT_JAR?=$(HOME)/.m2/repository/dev/hcf/ganymede/ganymede/$(GANYMEDE_SNAPSHOT_VERSION)/ganymede-$(GANYMEDE_SNAPSHOT_VERSION).jar
GANYMEDE_SNAPSHOT_SPARK_VERSION?=$(SPARK_VERSION)
GANYMEDE_SNAPSHOT_HADOOP_VERSION?=$(HADOOP_VERSION)
GANYMEDE_SNAPSHOT_SPARK_HOME?=$(DOT_VENV)/spark-$(GANYMEDE_SNAPSHOT_SPARK_VERSION)-bin-hadoop$(GANYMEDE_SNAPSHOT_HADOOP_VERSION)

kernel-ganymede: $(GANYMEDE_RELEASE_JAR)
	@$(MAKE) install-ganymede \
		JAVA_HOME=$(shell /usr/libexec/java_home -v 11) \
		KERNEL_JAR=$(GANYMEDE_RELEASE_JAR) \
		INSTALL_ARGS="-i --sys-prefix"
	@$(MAKE) install-ganymede-with-spark \
		JAVA_HOME=$(shell /usr/libexec/java_home -v 11) \
		KERNEL_JAR=$(GANYMEDE_RELEASE_JAR) \
		SPARK_VERSION=$(GANYMEDE_RELEASE_SPARK_VERSION) \
		SPARK_HOME=$(GANYMEDE_RELEASE_SPARK_HOME) \
		INSTALL_ARGS="-i --sys-prefix"
ifeq ("$(GANYMEDE_SNAPSHOT_JAR)","$(wildcard $(GANYMEDE_SNAPSHOT_JAR))")
	@$(MAKE) install-ganymede \
		JAVA_HOME=$(shell /usr/libexec/java_home -v 11) \
		KERNEL_JAR=$(GANYMEDE_SNAPSHOT_JAR) \
		INSTALL_ARGS="-i --sys-prefix --copy-jar=false"
	@$(MAKE) install-ganymede-with-spark \
		JAVA_HOME=$(shell /usr/libexec/java_home -v 11) \
		KERNEL_JAR=$(GANYMEDE_SNAPSHOT_JAR) \
		SPARK_VERSION=$(GANYMEDE_SNAPSHOT_SPARK_VERSION) \
		SPARK_HOME=$(GANYMEDE_SNAPSHOT_SPARK_HOME) \
		INSTALL_ARGS="-i --sys-prefix --copy-jar=false"
	@$(MAKE) install-ganymede \
		JAVA_HOME=$(shell /usr/libexec/java_home -v 17) \
		KERNEL_JAR=$(GANYMEDE_SNAPSHOT_JAR) \
		INSTALL_ARGS="-i --sys-prefix --copy-jar=false"
	@$(MAKE) install-ganymede-with-spark \
		JAVA_HOME=$(shell /usr/libexec/java_home -v 17) \
		KERNEL_JAR=$(GANYMEDE_SNAPSHOT_JAR) \
		SPARK_VERSION=$(GANYMEDE_SNAPSHOT_SPARK_VERSION) \
		SPARK_HOME=$(GANYMEDE_SNAPSHOT_SPARK_HOME) \
		INSTALL_ARGS="-i --sys-prefix --copy-jar=false"
endif

$(GANYMEDE_RELEASE_JAR):
	curl -sL $(GANYMEDE_RELEASE_URL) -o $@

install-ganymede:
	$(PIPENV) run $(JAVA_HOME)/bin/java -jar $(KERNEL_JAR) $(INSTALL_ARGS)

install-ganymede-with-spark: $(SPARK_HOME)
	$(PIPENV) run $(JAVA_HOME)/bin/java -jar $(KERNEL_JAR) \
		$(INSTALL_ARGS) \
		--id-suffix=spark-$(SPARK_VERSION) \
		--display-name-suffix="with Spark $(SPARK_VERSION)" \
		--env=SPARK_HOME=$(SPARK_HOME)

$(PIPFILE) $(DOT_VENV):
	@$(MAKE) $(DOT_ENV)
	$(PIPENV) run pip install $(PACKAGES) $(NBEXTENSIONS)
	@$(MAKE) kernels
	$(JUPYTER) contrib nbextension install --sys-prefix
	@$(MAKE) nbextensions
	$(JUPYTER) serverextension enable jupyterlab --py --sys-prefix
	@$(MAKE) serverextensions
	$(JUPYTER) labextension install @jupyter-widgets/jupyterlab-manager
	$(JUPYTER) labextension list

clean::
	@-$(PIPENV) --rm
	@-rm -rf $(PIPFILE) $(PIPFILE).lock
	@-rm -rf .ipynb_checkpoints

$(DOT_ENV):
	$(PIPENV) install python-dotenv[cli]
	@touch $(DOT_ENV)
	@$(MAKE) envvars

envvars: $(addprefix setenv-, $(ENVVARS))

setenv-%:
	@-$(DOTENV) $(if $(value $*),set $* $($*),unset $*)

clean::
	@-rm -rf $(DOT_ENV)

kernels: $(addprefix kernel-, $(KERNELS))
	$(JUPYTER) kernelspec list

kernel-%:
	@$(MAKE) $@

nbextensions: $(addprefix nbextension-enable-, $(NBEXTENSIONS))
	$(JUPYTER) nbextension enable hide_input/main --sys-prefix
	$(JUPYTER) nbextension list

nbextension-enable-%:
	$(JUPYTER) nbextension enable $* --py --sys-prefix

serverextensions: $(addprefix serverextension-enable-, $(SERVEREXTENSIONS))
	$(JUPYTER) serverextension list

serverextension-enable-%:
	$(JUPYTER) serverextension enable $* --py --sys-prefix
# ----------------------------------------------------------------------------
# Apache Spark
#
# Spark         Hadoop                  Scala
# -----         --------                -----
# 2.4.7              2.7                 2.11
# 2.4.8              2.7                 2.12
# 3.0.x         2.7, 3.2                 2.12
# 3.1.x         2.7, 3.2                 2.12
# 3.2.x         2.7, 3.3 (3.2)           2.12, 2.13
# 3.3.x         2.7, 3.3                 2.12, 2.13
# ----------------------------------------------------------------------------
APACHE_MIRROR?=https://mirrors.sonic.net/apache
APACHE_SPARK_MIRROR?=$(APACHE_MIRROR)/spark

$(DOT_VENV)/spark-%-bin-hadoop2.7: $(DOT_VENV)
	curl -sL $(APACHE_SPARK_MIRROR)/$(subst -bin-hadoop2.7,,$(notdir $@))/$(notdir $@).tgz \
		| tar xzCf $(DOT_VENV) -

$(DOT_VENV)/spark-%-bin-hadoop3: $(DOT_VENV)
	curl -sL $(APACHE_SPARK_MIRROR)/$(subst -bin-hadoop3,,$(notdir $@))/$(notdir $@).tgz \
		| tar xzCf $(DOT_VENV) -

$(DOT_VENV)/spark-%-bin-hadoop3.2: $(DOT_VENV)
	curl -sL $(APACHE_SPARK_MIRROR)/$(subst -bin-hadoop3.2,,$(notdir $@))/$(notdir $@).tgz \
		| tar xzCf $(DOT_VENV) -

$(DOT_VENV)/spark-%-bin-hadoop3-scala2.13: $(DOT_VENV)
	curl -sL $(APACHE_SPARK_MIRROR)/$(subst -bin-hadoop3-scala2.13,,$(notdir $@))/$(notdir $@).tgz \
		| tar xzCf $(DOT_VENV) -
# ----------------------------------------------------------------------------
# Apache Hive
# ----------------------------------------------------------------------------
APACHE_HIVE_MIRROR?=$(APACHE_MIRROR)/hive

$(DOT_VENV)/apache-hive-%-bin: $(DOT_VENV)
	curl -sL $(APACHE_HIVE_MIRROR)/$(subst apache-,,$(subst -bin,,$(notdir $@)))/$(notdir $@).tar.gz \
		| tar xzCf $(DOT_VENV) -
