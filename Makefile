# ----------------------------------------------------------------------------
# Makefile
# ----------------------------------------------------------------------------
export LANG=en_US.UTF-8
export LC_ALL=$(LANG)

export PIPENV_VENV_IN_PROJECT=1
export PIPENV_YES=1

ifeq ("$(shell echo $$TERM)","dumb")
export PIPENV_COLORBLIND=1
export PIPENV_HIDE_EMOJIS=1
export PIPENV_NOSPIN=1
export HOMEBREW_NO_COLOR=1
export HOMEBREW_NO_EMOJI=1
endif

PIPENV=pipenv --bare
DOTENV=$(PIPENV) run dotenv -f $(DOT_ENV)

PIPFILE=Pipfile
DOT_VENV=$(realpath $(dir $(lastword $(MAKEFILE_LIST))))/.venv
DOT_ENV=$(dir $(DOT_VENV))/.env

all::	$(DOT_VENV)

ENVVARS=
# ----------------------------------------------------------------------------
# JupyterLab
# ----------------------------------------------------------------------------
KERNELS=
NBEXTENSIONS=
SERVEREXTENSIONS=

JUPYTER=$(PIPENV) run jupyter

PACKAGES+=jupyterlab virtualenv
PACKAGES+=jupyter_contrib_nbextensions
PACKAGES+=ipysheet jedi numpy pandas pandoc scipy
PACKAGES+=cufflinks matplotlib plotly seaborn
PACKAGES+='nbconvert<6.0'
PACKAGES+=nbopen
# ----------------------------------------------------------------------------
ENVVARS+=JAVA_HOME
PACKAGES+=jep
ifeq ("$(shell uname -s)","Darwin")
export JAVA_HOME?=$(shell /usr/libexec/java_home -v 11)
endif
ifeq ("$(shell uname -s)","Linux")
export JAVA_HOME?=/usr/lib/jvm/adoptopenjdk-11-hotspot-amd64
endif
# ----------------------------------------------------------------------------
SPARK_VERSION?=3.1.2
HADOOP_VERSION?=3.2
SPARK_HOME?=$(DOT_VENV)/spark-$(SPARK_VERSION)-bin-hadoop$(HADOOP_VERSION)
# ----------------------------------------------------------------------------
# ipython
# ----------------------------------------------------------------------------
#KERNELS+=ipython
#ENVVARS+=SPARK_HOME
#PACKAGES+=ipython 'pyspark==$(SPARK_VERSION)' py4j

kernel-ipython: $(SPARK_HOME)
	$(PIPENV) run ipython kernel install-self
# https://stackoverflow.com/questions/42716734/modify-a-key-value-in-a-json-using-jq-in-place
# .venv/share/jupyter/kernels/python3
# $(JUPYTER) kernelspec list --json | jq '.kernelspecs.python3.spec' | cat
#  "env": {
#    "SPARK_HOME": "/Users/ball/Notebooks/.venv/spark-3.0.2-bin-hadoop3.2"
#  }
# ----------------------------------------------------------------------------
# Ganymede
# ----------------------------------------------------------------------------
KERNELS+=ganymede

GANYMEDE_RELEASE_VERSION?=1.1.0.20210614
GANYMEDE_RELEASE_URL?=https://github.com/allen-ball/ganymede/releases/download/v$(GANYMEDE_RELEASE_VERSION)/ganymede-kernel-$(GANYMEDE_RELEASE_VERSION).jar
GANYMEDE_RELEASE_JAR?=$(DOT_VENV)/ganymede-kernel-$(GANYMEDE_RELEASE_VERSION).jar
GANYMEDE_RELEASE_SPARK_VERSION?=3.1.2
GANYMEDE_RELEASE_HADOOP_VERSION?=3.2
GANYMEDE_RELEASE_SPARK_HOME?=$(DOT_VENV)/spark-$(GANYMEDE_RELEASE_SPARK_VERSION)-bin-hadoop$(GANYMEDE_RELEASE_HADOOP_VERSION)

GANYMEDE_SNAPSHOT_VERSION?=1.2.0-SNAPSHOT
GANYMEDE_SNAPSHOT_JAR?=$(HOME)/.m2/repository/ganymede/ganymede-kernel/$(GANYMEDE_SNAPSHOT_VERSION)/ganymede-kernel-$(GANYMEDE_SNAPSHOT_VERSION).jar

PACKAGES+='pyspark==$(SPARK_VERSION)' py4j

kernel-ganymede: $(GANYMEDE_RELEASE_JAR) $(GANYMEDE_SNAPSHOT_JAR) $(GANYMEDE_RELEASE_SPARK_HOME) $(SPARK_HOME)
	$(PIPENV) run \
		$(shell /usr/libexec/java_home -v 11)/bin/java \
			-jar $(GANYMEDE_RELEASE_JAR) --install --sys-prefix
	$(PIPENV) run \
		$(shell /usr/libexec/java_home -v 11)/bin/java \
			-jar $(GANYMEDE_RELEASE_JAR) \
			--install --sys-prefix \
			--id-suffix=spark-$(GANYMEDE_RELEASE_SPARK_VERSION) \
			--display-name-suffix="with Spark $(GANYMEDE_RELEASE_SPARK_VERSION)" \
			--env=SPARK_HOME=$(GANYMEDE_RELEASE_SPARK_HOME)
	$(PIPENV) run \
		$(shell /usr/libexec/java_home -v 11)/bin/java \
			-jar $(GANYMEDE_SNAPSHOT_JAR) \
			--install --sys-prefix --copy-jar=false
	$(PIPENV) run \
		$(shell /usr/libexec/java_home -v 11)/bin/java \
			-jar $(GANYMEDE_SNAPSHOT_JAR) \
			--install --sys-prefix --copy-jar=false \
			--id-suffix=spark-$(SPARK_VERSION) \
			--display-name-suffix="with Spark $(SPARK_VERSION)" \
			--env=SPARK_HOME=$(SPARK_HOME)
	$(PIPENV) run \
		$(shell /usr/libexec/java_home -v 13)/bin/java \
			-jar $(GANYMEDE_SNAPSHOT_JAR) \
			--install --sys-prefix --copy-jar=false
	$(PIPENV) run \
		$(shell /usr/libexec/java_home -v 15)/bin/java \
			-jar $(GANYMEDE_SNAPSHOT_JAR) \
			--install --sys-prefix --copy-jar=false
	$(PIPENV) run \
		$(shell /usr/libexec/java_home -v 16)/bin/java \
			-jar $(GANYMEDE_SNAPSHOT_JAR) \
			--install --sys-prefix --copy-jar=false

$(GANYMEDE_RELEASE_JAR):
	curl -sL $(GANYMEDE_RELEASE_URL) -o $@
# ----------------------------------------------------------------------------
NBEXTENSIONS+=widgetsnbextension
PACKAGES+=ipywidgets
# ----------------------------------------------------------------------------
SERVEREXTENSIONS+=jupyter_spark
NBEXTENSIONS+=jupyter_spark
# ----------------------------------------------------------------------------
$(PIPFILE) $(DOT_VENV):
	@$(MAKE) $(DOT_ENV)
	$(PIPENV) run pip install $(PACKAGES) $(NBEXTENSIONS)
	@$(MAKE) kernels
	$(JUPYTER) contrib nbextension install --sys-prefix
	@$(MAKE) nbextensions
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
# Spark		Hadoop			Scala
# -----		--------		-----
# 2.4.7		     2.7		 2.11
# 2.4.8		     2.7		 2.12
# 3.0.x		2.7, 3.2		 2.12
# 3.1.x		2.7, 3.2		 2.12
# ----------------------------------------------------------------------------
APACHE_SPARK_MIRROR?=https://mirrors.sonic.net/apache/spark

$(DOT_VENV)/spark-%-bin-hadoop2.7: $(DOT_VENV)
	curl -sL $(APACHE_SPARK_MIRROR)/$(subst -bin-hadoop2.7,,$(notdir $@))/$(notdir $@).tgz \
		| tar xzCf $(DOT_VENV) -

$(DOT_VENV)/spark-%-bin-hadoop3.2: $(DOT_VENV)
	curl -sL $(APACHE_SPARK_MIRROR)/$(subst -bin-hadoop3.2,,$(notdir $@))/$(notdir $@).tgz \
		| tar xzCf $(DOT_VENV) -
