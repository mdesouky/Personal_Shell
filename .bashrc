#Appearance
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
export PS2="| => "

alias ll='ls -FGlAhp'
eval "$(thefuck --alias)"
# Setting PATH for Python 3.6
# The original version is saved in .bash_profile.pysave
PATH="/Library/Frameworks/Python.framework/Versions/3.6/bin:${PATH}"
export PATH=/Users/melsayed/.chefdk/gem/ruby/2.3.0/bin:~/Library/Python/3.6/bin:$PATH
export PATH

eval "$(chef shell-init bash)"
source ~/.profile

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"

export CLICOLOR=1
if [ -f $(brew --prefix)/etc/bash_completion ]; then
      . $(brew --prefix)/etc/bash_completion
  fi

#This is a function to open up ~/.ssh/config and snap to that specific host you gave to the command(ssh_edit paycorp)
ssh_edit () 
{ 
    if [ ! "$1" ]; then
        vim ~/.ssh/config;
        return;
    fi;
    vim +/^Host\\s\\+$1\\s*$ ~/.ssh/config
}

#This is a function to list that host entries from ~/.ssh/config
ssh_info () 
{ 
    awk "/^Host $@/;/^Host $@/{flag=1;next}/^(Host|#)/{flag=0}flag" ~/.ssh/config | awk '!/^($|[:space:]*#)/'
}

#This is a function to parse hostnames from ~/.ssh/config to allow tab completion
_ssh()
{
    local cur=${COMP_WORDS[COMP_CWORD]}
    local prev=${COMP_WORDS[COMP_CWORD - 1]}
    local hosts=$(grep -E "^Host" ~/.ssh/config | awk {'print $2'})

    case $prev in
        -*)
            COMPREPLY=( $(compgen -f "${cur}") )
            ;;
        *)
            COMPREPLY=( $(compgen -W "$hosts" -- $cur) )
            ;;
    esac

    return 0
}

#These commands bind those function to the respective commands
complete -F _ssh ssh
complete -F _ssh ssh_info
complete -F _ssh ssh_edit

#   sts: Base2 Magic
#   ------------------------------------------
sts() {
    if [ $# -lt 2 ]; then
        echo "usage: sts <profile> <aws_account_id> <region (optional)>"
        return 1
    fi
    local date_time=`date +'%Y%m%d-%H%M%S'`
    local new_profile="[profile ${1}]"
    local sts_token=`aws --profile base2 \
        sts assume-role \
        --role-arn arn:aws:iam::${2}:role/base2Master \
        --role-session-name ${1} \
        --duration-seconds 3600`
    new_profile="[profile ${1}]"
    new_profile="$new_profile\naws_access_key_id=`echo $sts_token | jq -r .Credentials.AccessKeyId`"
    new_profile="$new_profile\naws_secret_access_key=`echo $sts_token | jq -r .Credentials.SecretAccessKey`"
    new_profile="$new_profile\naws_session_token=`echo $sts_token | jq -r .Credentials.SessionToken`"
    if [ $3 ]; then
        new_profile="$new_profile\nregion=$3"
    fi
    mv ~/.aws/config ~/.aws/config.$date_time.bck
    awk "
        BEGIN {found=0}
        /^ *\[(profile +)?${1} *\] *$/ {print \"$new_profile\n\"; banner=1; found=1; next}
        /^ *\[/ {banner=0}
        banner {next}
        {print}
        END {if (! found) {print \"\n$new_profile\"}}
    " ~/.aws/config.$date_time.bck | sed -e :a -e '/^\n*$/{$d;N;};/\n$/ba' > ~/.aws/config
    echo "aws configuration file (~/.aws/config) is updated, previous version is backed up at ${txtpur}~/.aws/config.$date_time.bck${txtrst}"
    echo "showing the diff between previous version (${txtpur}~/.aws/config.$date_time.bck${txtrst}) and new version (~/.aws/confg)"
    echo "===================================================================================="
    git diff ~/.aws/config.$date_time.bck ~/.aws/config
    if [ $? -eq 0 ]; then
        echo "no difference between new version (~/.aws/config) and previous version (${txtpur}~/.aws/config.$date_time.bck${txtrst})"
    fi
    echo "===================================================================================="
    echo "------------------------------------------------------------------------------------"
    local record="$1,$2"
    if [ $3 ]; then
        record="$record,$3"
    fi
    if [ ! -f ~/.aws/sts ]; then
        echo "no existing ~/.aws/sts index file found, creating new ~/.aws/sts index file" && echo "$record" > ~/.aws/sts
    return 0
    fi
    mv ~/.aws/sts ~/.aws/sts.$date_time.bck
    (grep -q -E "^$1(,.+)?$" ~/.aws/sts.$date_time.bck && sed -E "s/^$1(,.+)?$/$record/" ~/.aws/sts.$date_time.bck > ~/.aws/sts) || (cat ~/.aws/sts.$date_time.bck > ~/.aws/sts && echo "$record" >> ~/.aws/sts)
    echo "sts index file (~/.aws/sts is updated, previous version is backed up at ${txtpur}~/.aws/sts.$date_time.bck${txtrst}"
    echo "showing the diff between previous version (${txtpur}~/.aws/sts.$date_time.bck${txtrst}) and new version (~/.sts/confg)"
    echo "===================================================================================="
    git diff ~/.aws/sts.$date_time.bck ~/.aws/sts
    if [ $? -eq 0 ]; then
        echo "no difference between new version (~/.aws/sts) and previous version (${txtpur}~/.aws/sts.$date_time.bck${txtrst})"
    fi
    echo "===================================================================================="
    local bckups=`ls ~/.aws/config.*.bck ~/.aws/sts.*.bck 2>/dev/null | wc -l`
    if [ $bckups -gt 100 ]; then
        echo "$bckups backups detected, you can use sts_clean to clean these if you are sure current ~/.aws/config is correct"
    fi
}
#   sts_clean: Base2 Magic, Cleans Up Backups
#   ------------------------------------------
sts_clean() {
    ls ~/.aws/config.*.bck 1> /dev/null 2>&1 && rm ~/.aws/config.*.bck
    ls ~/.aws/sts.*.bck 1> /dev/null 2>&1 && rm ~/.aws/sts.*.bck
}
#   sts_rollback: Rollback sts Generated ~/.aws/config To A Specific Version
#   ------------------------------------------
sts_rollback() {
    if [ $# -lt 1 ]; then
        echo "usage: sts_rollback <version (date format YYYYmmdd-HHMMSS)>"
        return 1
    fi
    local date_time=`date +'%Y%m%d-%H%M%S'`
    mv ~/.aws/config ~/.aws/config.$date_time.bck 2>/dev/null
    mv ~/.aws/sts ~/.aws/sts.$date_time.bck 2>/dev/null
    mv ~/.aws/config.$1.bck ~/.aws/config 2>/dev/null
    mv ~/.aws/sts.$1.bck ~/.aws/sts 2>/dev/null
}

# Bash completion support for sts.
_sts()
{
    local cur=${COMP_WORDS[COMP_CWORD]}
    local prev=${COMP_WORDS[COMP_CWORD - 1]}
    local file=~/.aws/sts
    local profiles=$(grep -E '^\[' ~/.aws/config | awk '{print $NF}' | sed -n -e 's/^\[*\(.*\)\]$/\1/p')
    case $COMP_CWORD in
        1)
            COMPREPLY=( $(compgen -W "$profiles" -- $cur) )
            ;;
        2)
            local ids=$([[ `grep -E "^$prev( *, *[0-9]+)( *,.*)*$" $file | awk -F',' '{print NF; exit}' 2>/dev/null` > 1 ]] && (grep -E "^$prev( *, *[0-9]+)( *,.*)*$" ~/.aws/sts | cut -f2 -d"," 2>/dev/null))
            COMPREPLY=( $(compgen -W "$ids" -- $cur) )
            ;;
        3)
            local regions=$([[ `grep -E "^${COMP_WORDS[1]}( *, *[0-9]+)( *,.*)*$" $file | awk -F',' '{print NF; exit}' 2>/dev/null` > 2 ]] && (grep -E "^${COMP_WORDS[1]}( *, *[0-9]+)( *,.*)*$" ~/.aws/sts | cut -f3 -d"," 2>/dev/null))
            COMPREPLY=( $(compgen -W "$regions" -- $cur) )
            ;;
        *)
            ;;
    esac
    return 0
}
complete -F _sts sts
# Bash completion support for sts_rollback.
_sts_rollback()
{
    local cur=${COMP_WORDS[COMP_CWORD]}
    local prev=${COMP_WORDS[COMP_CWORD - 1]}
    local versions=`ls ~/.aws/config.*.bck 2>/dev/null | rev | cut -f2 -d '.' | rev`
    case $COMP_CWORD in
        1)
            COMPREPLY=( $(compgen -W "$versions" -- $cur) )
            ;;
    *)
            ;;
    esac
    return 0
}
complete -F _sts_rollback sts_rollback

#------------------------------------------------------------------------------
#aws_snapshots_cleanup is a function
aws_snapshots_cleanup () 
{ 
    if [ $# -lt 1 ]; then
        echo "usage: aws_snapshots_cleanup <profile> <region>";
        return 1;
    fi;
    local profile=$1;
    local aws_region=`awk "/ *\[(profile +)?$profile *] *$/{flag=1;next}/^ *\[/{flag=0}flag" ~/.aws/config | grep -E "^\\s*region" | cut -f2 -d'=' | tr -d ' '`;
    [[ -n "$aws_region" ]] && aws_region=`awk "/^ *\[(profile +)?default *] *$/{flag=1;next}/^ *\[/{flag=0}flag" ~/.aws/config | grep -E "^\\s*region" | cut -f2 -d'=' | tr -d ' '`;
    if [ $2 ]; then
        local region="--region $2";
        aws_region=$2;
    fi;
    local snapshots_in_volume=(`aws --profile $profile $region ec2 describe-volumes --query "Volumes[?SnapshotId!=''].[SnapshotId]" --output text | sort | uniq`);
    local snapshots=(`aws --profile $profile $region ec2 describe-snapshots --owner-ids self --query "Snapshots[].SnapshotId[]" --output text`);
    local snapshots_in_ami=(`aws --profile $profile ec2 $region describe-images --owners self --query "Images[].BlockDeviceMappings[].Ebs[].SnapshotId[]" --output text`);
    rm -rf $profile-snapshot-cleanup.log;
    for snapshot in ${snapshots[@]};
    do
        if [[ ! "${snapshots_in_use[@]}" =~ "$snapshot" ]]; then
            if [[ ! "${snapshots_in_ami[@]}" =~ "$snapshot" ]]; then
                echo "$snapshot,delete" >> $profile-snapshot-cleanup.log;
            else
                echo "$snapshot,keep-ami" >> $profile-snapshot-cleanup.log;
            fi;
        else
            echo "$snapshot,keep-vol" >> $profile-snapshot-cleanup.log;
        fi;
    done;
    echo "logs are availabe at `pwd`/$profile-snapshot-cleanup.log"
}
complete -F _aws_snapshots_cleanup aws_snapshots_cleanup

aws_snapshots_delete () 
{ 
    if [ $# -lt 1 ]; then
        echo "usage: aws_snapshots_delete <cleanup_log> <region>";
        return 1;
    fi;
    local length=(`grep "delete" $1 | awk '!/^($|[:space:]*#)/' | wc -l`);
    local snapshots=(`grep "delete" $1 | cut -f1 -d',' | awk '!/^($|[:space:]*#)/'`);
    local profile=`echo $1 | sed -n 's/^\(.*\)-snapshot-cleanup\.log$/\1/p'`;
    local aws_region=`awk "/^ *\[(profile +)?$profile *] *$/{flag=1;next}/^ *\[/{flag=0}flag" ~/.aws/config | grep -E "^\\s*region" | cut -f2 -d'=' | tr -d ' '`;
    [[ -n "$aws_region" ]] && aws_region=`awk "/^ *\[(profile +)?default *] *$/{flag=1;next}/^ *\[/{flag=0}flag" ~/.aws/config | grep -E "^\\s*region" | cut -f2 -d'=' | tr -d ' '`;
    if [ $2 ]; then
        local region="--region $2";
        aws_region=$2;
    fi;
    count=0;
    s_time=`date +%s`;
    for snapshot in ${snapshots[@]};
    do
        echo "Deleting $profile $snapshot in $aws_region";
        aws --profile $profile $region ec2 delete-snapshot --snapshot-id $snapshot;
        echo "Deleted $profile $snapshot";
        ((count++));
        c_time=`date +%s`;
        diff=$(($c_time - $s_time));
        avg=`echo "$diff / $count" | bc -l`;
        remain=$((length - count));
        f_time=`echo "$c_time + ($avg * $remain)" | bc -l`;
        echo "$remain to go, estimated completion time is `date -r ${f_time%.*} "+%F %H:%M:%S %Z"`";
    done
}
complete -F _aws_snapshots_delete aws_snapshots_delete

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*


cdr2mask ()
{
   # Number of args to shift, 255..255, first non-255 byte, zeroes
   set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
   [ $1 -gt 1 ] && shift $1 || shift
   echo ${1-0}.${2-0}.${3-0}.${4-0}
}
complete -F cdr2mask cdr2mask


# Eternal bash history.
# ---------------------
# Undocumented feature which sets the size to "unlimited".
# http://stackoverflow.com/questions/9457233/unlimited-bash-history
export HISTFILESIZE=
export HISTSIZE=
export HISTTIMEFORMAT="[%F %T] "
# Change the file location because certain bash sessions truncate .bash_history file upon close.
# http://superuser.com/questions/575479/bash-history-truncated-to-500-lines-on-each-login
export HISTFILE=~/.bash_eternal_history
# Force prompt to write history after every command.
# http://superuser.com/questions/20900/bash-history-loss
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
