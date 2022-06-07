#!/bin/bash

# Simple k8s-specific bash shell.
#
# The tmpfile copy of kubeconfig is dedicated to just this shell. This prevents the context from
# getting clobbered when running multiple terminals. The drawback is that creating new contexts
# won't be preserved when in this terminal.

# Create a temp version of the main kube-config
kubeconfig=$(mktemp /tmp/kubeconfig.XXXXXX)
cat ${HOME}/.kube/config > ${kubeconfig}
export KUBECONFIG="${kubeconfig}"

# Create Bash rc file
rcfile=$(mktemp /tmp/bash-rcfile-k8s.XXXXXX)
cat << "EOF" > ${rcfile}
source /etc/bash_completion
source <(kubectl completion bash)

# kubectl=k shortcut
alias k=kubectl

## namespace change shortcut
n () {
  kubectl config set-context $(kubectl config current-context) --namespace=$1 >/dev/null 2>&1
  export K8S_NAMESPACE=$1
}

## n completion script
_n_completions()
{
  WORDS=$(kubectl get ns -o name | sed 's,namespace/,,')
  COMPREPLY=($(compgen -W "${WORDS}" -- "${COMP_WORDS[1]}"))
}

## bash completions
complete -F _n_completions n
complete -o default -F __start_kubectl k

# prompt
export PS1="\[\e[01;32m\]\$(kubectl config view --minify --output 'jsonpath={.contexts[0].context.user}')@\[\e[01;31m\](\$(kubectl config view --minify --output 'jsonpath={.contexts[0].context.cluster}')) \[\e[01;33m\][\$(kubectl config view --minify --output 'jsonpath={.contexts[0].context.namespace}')]\[\e[01;34m\] \w\[\e[m\]\n$ "
EOF

# Generate a list of the available contexts
options=($(kubectl config get-contexts | awk '{print $2}' | grep -v -e NAME -e dummy))
echo "Choose a k8s context"
select opt in "${options[@]}"
do
	kubectl config use-context ${opt}
	break
done

# Fire up a brand new shell
bash --rcfile <(cat ${HOME}/.bashrc; cat ${rcfile})

# Clean up
rm ${kubeconfig}
rm ${rcfile}
