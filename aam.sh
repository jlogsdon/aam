# AAM is a utility for managing multiple AWS account credentials. It handles loading a default set of credentials, ensures
# the litany of variables used by the tools are set and provides a mechanism for quickly switching between accounts.

# readlink-esque function that works on Darwin
real_path () {
  local cur=`pwd`
  [ -d $1 ] && DIR=$1
  [ -f $1 ] && DIR=`dirname $1`
  cd $DIR && echo `pwd` && cd $cur
}

export AAM_SCRIPT=$(real_path $0)/$(basename $0)
[ -z $AAM_STORE ] && export AAM_STORE=$HOME/.aam
[ -d $AAM_STORE ] || mkdir -p $AAM_STORE
[ -z $AAM_DEFAULT_FILE ] && export AAM_DEFAULT_FILE=${AAM_STORE}/.default

[ -z $EC2_HOME ]              && export EC2_HOME="/usr/share/ec2-api-tools"
[ -z $AWS_AUTO_SCALING_HOME ] && export AWS_AUTO_SCALING_HOME="/usr/share/as-api-tools"
[ -z $AWS_CLOUDWATCH_HOME ]   && export AWS_CLOUDWATCH_HOME="/usr/share/cloudwatch-api-tools"
[ -z $AAM_DEFAULT_EC2_CREDS ] && export AAM_DEFAULT_EC2_CREDS="$HOME/.ec2.creds"

if [ -z $AAM_DEFAULT ]; then
  if [ -f $AAM_DEFAULT_FILE ]; then
    export AAM_DEFAULT=`cat ${AAM_DEFAULT_FILE}`
  fi
fi

aam() {
  if [ ! -z $1 ]; then
    cmd=$1
    shift
  else
    cmd='help'
  fi
  case $cmd in
    "help" )
      echo
      echo "AWS Account Manager"
      echo
      echo "Usage:"
      echo "  aam help                      Show this message"
      echo "  aam create <account>          Create a new AWS account"
      echo "  aam use <account>             Use the named AWS account"
      echo "  aam do <account> <command...> Run a command under the given account"
      echo "  aam default <account>         Set the default account"
      echo "  aam list                      Show all available accounts"
      echo
      ;;
    "create" )
      local account
      local store

      if [ $# -lt 1 ]; then
        echo "Usage: aam create <account>"
        return 1
      fi

      account=$1
      store=${AAM_STORE}/${account}
      shift

      if [ -f $store ]; then
        echo "AWS account named ${account} already exists!"
        return 1
      fi

      cat > $store <<EOC
export AWS_ACCESS_KEY=
export AWS_SECRET_KEY=
EOC

      echo "AWS account ${account} created! Edit ${store}, switch with aam use ${account}"
      ;;
    "use" )
      local account
      local store

      if [ $# -lt 1 ]; then
        echo "Usage: aam use <account>"
        return 1
      fi

      account=$1
      shift

      if [ $account = 'default' ]; then
        if [ -z $AAM_DEFAULT ]; then
          echo "No default account has been configured. Set one with aam default <account>."
          return 1
        fi
        account=$AAM_DEFAULT
      fi

      store=${AAM_STORE}/${account}
      if [ ! -f $store ]; then
        echo "No account named ${account}"
        return 1
      fi

      export AAM_ACCOUNT=$account

      # Unset variables that may be set by the config
      [ -z $AWS_CREDENTIAL_FILE ]   || unset $AWS_CREDENTIAL_FILE

      source $store

      [ -z $AWS_CREDENTIAL_FILE ] && export AWS_CREDENTIAL_FILE=$AAM_DEFAULT_EC2_CREDS
      export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
      export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY

      cat > $AWS_CREDENTIAL_FILE <<EOC
AWSAccessKeyId=$AWS_ACCESS_KEY
AWSSecretKey=$AWS_SECRET_KEY
EOC

      echo "Switched to account ${account}"
      ;;
    "do" )
      local account

      if [ $# -lt 1 ]; then
        echo "Usage: aam do <account> <command...>"
        return 1
      fi

      account=$1
      store=${AAM_STORE}/${account}
      shift
      command=$*

      if [ ! -f $store ]; then
        echo "No account named ${account}"
        return 1
      fi

      $SHELL -l -c "source ${AAM_SCRIPT}; aam use ${account}; ${command}"
      ;;
    "default" )
      local account

      if [ $# -lt 1 ]; then
        echo "Usage: aam default <account>"
        return 1
      fi

      account=$1
      store=${AAM_STORE}/${account}
      shift

      if [ ! -f $store ]; then
        echo "No account named ${account}"
        return 1
      fi

      echo $account > $AAM_DEFAULT_FILE
      echo "Default account set to ${account}"
      ;;
    "list" )
      echo
      echo "Available accounts"
      for account in `ls $AAM_STORE`; do
        local ind=''
        if [ "$account" = "$AAM_ACCOUNT" ]; then
          ind='='
          [ "$account" = "$AAM_DEFAULT" ] && ind+='*' || ind+='>'
        else
          ind=' '
          [ "$account" = "$AAM_DEFAULT" ] && ind+='*' || ind+=' '
        fi

        echo "${ind} ${account}"
      done
      echo
      echo '# => - current'
      echo '# =* - current & default'
      echo '#  * - default'
      ;;
  esac
}

if [ -z $AAM_ACCOUNT ]; then
  aam use default > /dev/null
fi

