[ -f ${GLITE_LOCATION:-/opt/glite}/etc/blah.config ] && . ${GLITE_LOCATION:-/opt/glite}/etc/blah.config

#
# Functions to handle the file mapping tables
#

function bls_fl_add_value ()
{
#
# Usage: bls_fl_add_value container_name local_file remote_file
# inserts into a scalar shell-variable based container a new pair of string values
#
  local container_name
  local local_file_name
  local remote_file_name

  container_name=${1:?"Missing container name argument to bls_add_value"}
  local_file_name=${2:?"Missing local file name argument to bls_add_value"}
  remote_file_name=${3:?"Missing remote file name argument to bls_add_value"}

  local last_argument

  eval "last_argument=\${bls_${container_name}_counter:=0}"
  eval "bls_${container_name}_local_${last_argument}=$local_file_name"
  eval "bls_${container_name}_remote_${last_argument}=$remote_file_name"
  eval "let bls_${container_name}_counter++"
}

function bls_fl_subst ()
{
#
# Usage: bls_fl_subst container_name index template_string
# substitutes the value pair at the index'th position in container_name
# to the @@F_LOCAL and @@F_REMOTE strings in template_string 
# Result is returned in $bls_fl_subst_result.
#
  local container_name
  local container_index
  local subst_template
 
  container_name=${1:?"Missing container name argument to bls_fl_subst"}
  container_index=${2:?"Missing index to bls_fl_subst"}
  subst_template=${3:?"Missing template bls_fl_subst"}

  local f_local
  local f_remote
  local temp_result
  
  eval "f_local=\${bls_${container_name}_local_${container_index}}"
  eval "f_remote=\${bls_${container_name}_remote_${container_index}}"

  bls_fl_subst_result=""

  if [ \( ! -z "$f_local" \) -a \( ! -z "$f_remote" \) ] ; then
      temp_result=${subst_template/@@F_LOCAL/$f_local}
      bls_fl_subst_result=${temp_result/@@F_REMOTE/$f_remote}
  fi
}

function bls_fl_subst_and_accumulate ()
{
#
# Usage: bls_fl_subst_and_accumulate container_name template_string separator
# substitutes all the value pairs in container_name
# to the @@F_LOCAL and @@F_REMOTE strings in template_string, and
# concatenates the results,separating them with the 'separator' string.
# Result is returned in $bls_fl_subst_and_accumulate_result.
#
  local container_name
  local subst_template
  local separator

  container_name=${1:?"Missing container name argument to bls_fl_subst_and_accumulate"}
  subst_template=${2:?"Missing template argument to bls_fl_subst_and_accumulate"}
  separator=${3:?"Missing separator argument to bls_add_value"}

  bls_fl_subst_and_accumulate_result=""

  local last_argument

  eval "last_argument=\${bls_${container_name}_counter:=0}"

  local ind
  local l_sepa

  l_sepa=""
  
  for (( ind=0 ; ind < $last_argument ; ind++ )) ; do
      bls_fl_subst $container_name $ind "$subst_template"
      if [ ! -z "$bls_fl_subst_result" ] ; then
          bls_fl_subst_and_accumulate_result="${bls_fl_subst_and_accumulate_result}${l_sepa}${bls_fl_subst_result}"
          l_sepa=$separator
      fi
  done
}

function bls_fl_subst_and_dump ()
{
#
# Usage: bls_fl_subst_and_dump container_name template_string filename
# substitutes all the value pairs in container_name
# to the @@F_LOCAL and @@F_REMOTE strings in template_string, and
# appends the results as single lines to $filename 
#
  local container_name
  local subst_template
  local filename

  container_name=${1:?"Missing container name argument to bls_fl_subst_and_accumulate"}
  subst_template=${2:?"Missing template argument to bls_fl_subst_and_accumulate"}
  filename=${3:?"Missing filename argument to bls_add_value"}

  local last_argument

  eval "last_argument=\${bls_${container_name}_counter:=0}"

  local ind
  
  for (( ind=0 ; ind < $last_argument ; ind++ )) ; do
      bls_fl_subst $container_name $ind "$subst_template"
      if [ ! -z "$bls_fl_subst_result" ] ; then
          echo $bls_fl_subst_result >> $filename
      fi
  done
}

function bls_fl_clear ()
{
#
# Usage: bls_fl_clear container_name 
# Deletes all the values in contenier container_name.
#
  local container_name

  container_name=${1:?"Missing container name argument to bls_fl_subst_and_accumulate"}

  local last_argument

  eval "last_argument=\${bls_${container_name}_counter:=0}"

  local ind
  
  for (( ind=0 ; ind < $last_argument ; ind++ )) ; do
     eval "unset bls_${container_name}_local_${ind}"
     eval "unset bls_${container_name}_remote_${ind}"
  done

  eval "unset bls_${container_name}_counter"
}

function bls_parse_submit_options ()
{
  usage_string="Usage: $0 -c <command> [-i <stdin>] [-o <stdout>] [-e <stderr>] [-x <x509userproxy>] [-v <environment>] [-s <yes | no>] [-- command_arguments]"

  bls_opt_stgcmd="yes"
  bls_opt_stgproxy="yes"
  
  bls_proxyrenewald="${GLITE_LOCATION:-/opt/glite}/bin/BPRserver"
  
  #default is to stage proxy renewal daemon 
  bls_opt_proxyrenew="yes"
  
  if [ ! -r "$bls_proxyrenewald" ]
  then
      unset bls_opt_proxyrenew
  fi
  
  bls_proxy_dir=~/.blah_jobproxy_dir
  
  bls_opt_workdir=$PWD

  #default values for polling interval and min proxy lifetime
  bls_opt_prnpoll=30
  bls_opt_prnlifetime=0
  
  bls_BLClient="${GLITE_LOCATION:-/opt/glite}/bin/BLClient"
  
  ###############################################################
  # Parse parameters
  ###############################################################
  while getopts "i:o:e:c:s:v:V:dw:q:n:rp:l:x:j:T:I:O:R:C:" arg 
  do
      case "$arg" in
      i) bls_opt_stdin="$OPTARG" ;;
      o) bls_opt_stdout="$OPTARG" ;;
      e) bls_opt_stderr="$OPTARG" ;;
      v) bls_opt_envir="$OPTARG";;
      V) bls_opt_environment="$OPTARG";;
      c) bls_opt_the_command="$OPTARG" ;;
      s) bls_opt_stgcmd="$OPTARG" ;;
      d) bls_opt_debug="yes" ;;
      w) bls_opt_workdir="$OPTARG";;
      q) bls_opt_queue="$OPTARG";;
      n) bls_opt_mpinodes="$OPTARG";;
      r) bls_opt_proxyrenew="yes" ;;
      p) bls_opt_prnpoll="$OPTARG" ;;
      l) bls_opt_prnlifetime="$OPTARG" ;;
      x) bls_opt_proxy_string="$OPTARG" ;;
      j) bls_opt_creamjobid="$OPTARG" ;;
      T) bls_opt_temp_dir="$OPTARG" ;;
      I) bls_opt_inputflstring="$OPTARG" ;;
      O) bls_opt_outputflstring="$OPTARG" ;;
      R) bls_opt_outputflstringremap="$OPTARG" ;;
      C) bls_opt_req_file="$OPTARG";;
      -) break ;;
      ?) echo $usage_string
         exit 1 ;;
      esac
  done

# Command is mandatory
  if [ "x$bls_opt_the_command" == "x" ]
  then
      echo $usage_string
      exit 1
  fi
  shift `expr $OPTIND - 1`
  bls_arguments=$*
}

function bls_setup_all_files ()
{

  curdir=`pwd`
  if [ -z "$bls_opt_temp_dir"  ] ; then
      bls_opt_temp_dir="$curdir"
  else
      if [ ! -e $bls_opt_temp_dir ] ; then
          mkdir -p $bls_opt_temp_dir
      fi
      if [ ! -d $bls_opt_temp_dir -o ! -w $bls_opt_temp_dir ] ; then
          echo "1ERROR: unable to create or write to $bls_opt_temp_dir"
          exit 0
      fi
  fi
  
  
  # Get a suitable name for temp file
  if [ "x$bls_opt_debug" != "xyes" ]
  then
      if [ ! -z "$bls_opt_creamjobid"  ] ; then
          bls_tmp_name="cream_${bls_opt_creamjobid}"
          bls_tmp_file="$bls_opt_temp_dir/$bls_tmp_name"
      else
          rand=$RANDOM$RANDOM$RANDOM$RANDOM
          bls_tmp_name=bl_${rand:0:12}
          bls_tmp_file="$bls_opt_temp_dir/$bls_tmp_name"
          `touch $bls_tmp_file;chmod 600 $bls_tmp_file`
      fi
      if [ $? -ne 0 ]; then
          echo Error
          exit 1
      fi
  else
      # Just print to /dev/tty if in debug
      bls_tmp_file="/dev/tty"
  fi
  
  # Create unique extension for filenames
  uni_uid=`id -u`
  uni_pid=$$
  uni_time=`date +%s`
  uni_ext=$uni_uid.$uni_pid.$uni_time
  
  # Put executable into inputsandbox
  
  if [ "x$bls_opt_stgcmd" == "xyes" ] ; then
      bls_fl_add_value inputsand "$bls_opt_the_command" "`basename $bls_opt_the_command`"
      bls_to_be_moved="$bls_to_be_moved `basename $bls_opt_the_command`"
  fi
  
  # Put BPRserver into sandbox
  if [ "x$bls_opt_proxyrenew" == "xyes" ] ; then
      if [ -r "$bls_proxyrenewald" ] ; then
          remote_BPRserver=`basename $bls_proxyrenewald`.$uni_ext
          bls_fl_add_value inputsand "$bls_proxyrenewald" "${blahpd_inputsandbox}${remote_BPRserver}"
          bls_to_be_moved="$bls_to_be_moved $remote_BPRserver"
      else
          unset bls_opt_proxyrenew
      fi
  fi
  
  # Setup proxy transfer
  bls_need_to_reset_proxy=no
  bls_proxy_remote_file=
  if [ "x$bls_opt_stgproxy" == "xyes" ] ; then
      bls_proxy_local_file=${bls_opt_workdir}"/"`basename "$bls_opt_proxy_string"`;
      [ -r "$bls_proxy_local_file" -a -f "$bls_proxy_local_file" ] || bls_proxy_local_file=$bls_opt_proxy_string
      [ -r "$bls_proxy_local_file" -a -f "$bls_proxy_local_file" ] || bls_proxy_local_file=/tmp/x509up_u`id -u`
      if [ -r "$bls_proxy_local_file" -a -f "$bls_proxy_local_file" ] ; then
          bls_proxy_remote_file=${bls_tmp_name}.proxy
          bls_fl_add_value inputsand "$bls_proxy_local_file" "${blahpd_inputsandbox}${bls_proxy_remote_file}"
          bls_to_be_moved="$bls_to_be_moved ${bls_proxy_remote_file}"
          bls_need_to_reset_proxy=yes
      fi
  fi
  
  local stdin_unique

  # Setup stdout & stderr
  if [ ! -z "$bls_opt_stdin" ] ; then
      if [ -f "$bls_opt_stdin" ] ; then
          stdin_unique=`basename $bls_opt_stdin`.$uni_ext
          bls_fl_add_value inputsand "$bls_opt_stdin" "${blahpd_inputsandbox}${stdin_unique}"
          bls_to_be_moved="$bls_to_be_moved $bls_opt_stdin_unique"
          bls_arguments="$bls_arguments <\"$bls_opt_stdin_unique\""
      else
          bls_arguments="$bls_arguments <$bls_opt_stdin"
      fi
  fi
  if [ ! -z "$bls_opt_stdout" ] ; then
      if [ "${bls_opt_stdout:0:1}" != "/" ] ; then bls_opt_stdout=${bls_opt_workdir}/${bls_opt_stdout} ; fi
      bls_arguments="$bls_arguments >`basename $bls_opt_stdout`"
      bls_fl_add_value outputsand "$bls_opt_stdout" "${blahpd_outputsandbox}home_${bls_tmp_name}/`basename $bls_opt_stdout`"
  fi
  if [ ! -z "$bls_opt_stderr" ] ; then
      if [ "${bls_opt_stderr:0:1}" != "/" ] ; then bls_opt_stderr=${bls_opt_workdir}/${bls_opt_stderr} ; fi
      if [ "$bls_opt_stderr" == "$bls_opt_stdout" ]; then
          bls_arguments="$bls_arguments 2>&1"
      else
          bls_arguments="$bls_arguments 2>`basename $bls_opt_stderr`"
          bls_fl_add_value outputsand "$bls_opt_stderr" "${blahpd_outputsandbox}home_${bls_tmp_name}/`basename $bls_opt_stderr`"
      fi
  fi

#Add to inputsand files to transfer to execution node
#absolute paths
  local xfile

  if [ ! -z "$bls_opt_inputflstring" ] ; then
      exec 4<> "$bls_opt_inputflstring"
      while read xfile <&4 ; do
          if [ ! -z $xfile  ] ; then
               bls_fl_add_value inputsand "$xfile" "./`basename ${xfile}`"
          fi
      done
      exec 4<&-
      rm -f $bls_opt_inputflstring
  fi

  xfile=
  local xfileremap

#Add files to transfer from execution node
  if [ ! -z "$bls_opt_outputflstring" ] ; then
      exec 5<> "$bls_opt_outputflstring"
      if [ ! -z "$bls_opt_outputflstringremap" ] ; then
          exec 6<> "$bls_opt_outputflstringremap"
      fi
      while read xfile <&5 ; do
          if [ ! -z $xfile  ] ; then
              if [ ! -z "$bls_opt_outputflstringremap" ] ; then
                  read xfileremap <&6
              fi

              if [ ! -z $xfileremap ] ; then
                  if [ "${xfileremap:0:1}" != "/" ] ; then
                      bls_fl_add_value outputsand "$xfile" "${bls_opt_workdir}/${xfileremap}"
                  else
                      bls_fl_add_value outputsand "$xfile" "${xfileremap}"
                  fi
              else
                  bls_fl_add_value outputsand "$xfile" "${bls_opt_workdir}/${xfile}"
              fi
          fi
      done
      exec 5<&-
      exec 6<&-
      rm -f $bls_opt_outputflstring
      if [ ! -z "$bls_opt_outputflstringremap" ] ; then
          rm -f $bls_opt_outputflstringremap
      fi
  fi
} 

function bls_add_job_wrapper ()
{
  # Set the required environment variables (escape values with double quotes)
  if [ "x$bls_opt_environment" != "x" ] ; then
          echo "" >> $bls_tmp_file
          echo "# Setting the environment:" >> $bls_tmp_file
  	eval "env_array=($bls_opt_environment)"
          for  env_var in "${env_array[@]}"; do
                   echo export \"$env_var\" >> $bls_tmp_file
          done
  else
          if [ "x$bls_opt_envir" != "x" ] ; then
                  echo "" >> $bls_tmp_file
                  echo "# Setting the environment:" >> $bls_tmp_file
                  echo "`echo ';'$bls_opt_envir | sed -e 's/;[^=]*;/;/g' -e 's/;[^=]*$//g' | sed -e 's/;\([^=]*\)=\([^;]*\)/;export \1=\"\2\"/g' | awk 'BEGIN { RS = ";" } ; { print $0 }'`" >> $bls_tmp_file
          fi
  fi
  
  # Set the temporary home (including cd'ing into it)
  echo "mkdir ~/home_$bls_tmp_name">>$bls_tmp_file
  [ -z "$bls_to_be_moved" ] || echo "mv $bls_to_be_moved ~/home_$bls_tmp_name &>/dev/null">>$bls_tmp_file
  echo "export HOME=~/home_$bls_tmp_name">>$bls_tmp_file
  echo "cd">>$bls_tmp_file
  
  # Set the path to the user proxy
  if [ "x$bls_need_to_reset_proxy" == "xyes" ] ; then
      echo "# Resetting proxy to local position" >> $bls_tmp_file
      echo "export X509_USER_PROXY=\`pwd\`/${bls_proxy_remote_file}" >> $bls_tmp_file
  fi
  
  # Add the command (with full path if not staged)
  echo "" >> $bls_tmp_file
  echo "# Command to execute:" >> $bls_tmp_file
  if [ "x$bls_opt_stgcmd" == "xyes" ] 
  then
      bls_opt_the_command="./`basename $bls_opt_the_command`"
      echo "if [ ! -x $bls_opt_the_command ]; then chmod u+x $bls_opt_the_command; fi" >> $bls_tmp_file
  fi
  echo "$bls_opt_the_command $bls_arguments &" >> $bls_tmp_file
  
  echo "job_pid=\$!" >> $bls_tmp_file
  
  if [ ! -z $bls_opt_proxyrenew ]
  then
      echo "" >> $bls_tmp_file
      echo "# Start the proxy renewal server" >> $bls_tmp_file
      echo "if [ ! -x $remote_BPRserver ]; then chmod u+x $remote_BPRserver; fi" >> $bls_tmp_file
      echo "\`pwd\`/$remote_BPRserver \$job_pid $bls_opt_prnpoll $bls_opt_prnlifetime \${PBS_JOBID} &" >> $bls_tmp_file
      echo "server_pid=\$!" >> $bls_tmp_file
  fi
  
  echo "" >> $bls_tmp_file
  echo "# Wait for the user job to finish" >> $bls_tmp_file
  echo "wait \$job_pid" >> $bls_tmp_file
  echo "user_retcode=\$?" >> $bls_tmp_file
  
  if [ ! -z $bls_opt_proxyrenew ]
  then
      echo "# Kill the watchdog when done" >> $bls_tmp_file
      echo "sleep 1" >> $bls_tmp_file
      echo "kill \$server_pid 2> /dev/null" >> $bls_tmp_file
  fi
  
  if [ ! -z "$bls_to_be_moved" ] ; then
      echo ""  >> $bls_tmp_file
      echo "# Remove the staged files" >> $bls_tmp_file
      echo "rm $bls_to_be_moved" >> $bls_tmp_file
  fi
  
  # We cannot remove the output files, as they have to be transferred back to the CE
  # echo "cd .." >> $bls_tmp_file
  # echo "rm -rf \$HOME" >> $bls_tmp_file
  
  echo "" >> $bls_tmp_file
  
  echo "exit \$user_retcode" >> $bls_tmp_file

  # Exit if it was just a test
  if [ "x$debug" == "xyes" ]
  then
      exit 255
  fi

  if [ "x$bls_opt_workdir" != "x" ]; then
      cd $bls_opt_workdir
  fi

  if [ $? -ne 0 ]; then
      echo "Failed to CD to Initial Working Directory." >&2
      echo Error # for the sake of waiting fgets in blahpd
      rm -f $bls_tmp_file
      exit 1
  fi
}

function bls_wrap_up_submit ()
{
  bls_fl_clear inputsand
  bls_fl_clear outputsand

  # Clean temporary files
  cd $bls_opt_temp_dir
  # DEBUG: cp $bls_tmp_file /tmp
  rm -f $bls_tmp_file
  
  # Create a softlink to proxy file for proxy renewal
  if [ -r "$bls_proxy_local_file" -a -f "$bls_proxy_local_file" ] ; then
      [ -d "$bls_proxy_dir" ] || mkdir $bls_proxy_dir
      ln -s $bls_proxy_local_file $bls_proxy_dir/$jobID.proxy
  fi
}